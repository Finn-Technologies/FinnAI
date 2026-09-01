package com.abhiflex.finnai

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.nio.channels.FileChannel
import java.nio.file.StandardOpenOption
import android.util.Log
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread

/** Keeps a large model transfer alive after Flutter's process/activity is closed. */
class ModelDownloadService : Service() {
    companion object {
        private const val TAG = "ModelDownloadService"
        const val ACTION_START = "com.abhiflex.finnai.START_MODEL_DOWNLOAD"
        const val EXTRA_URL = "url"
        const val EXTRA_TARGET = "target"
        const val EXTRA_EXPECTED_BYTES = "expectedBytes"
        const val EXTRA_LABEL = "label"
        private const val CHANNEL_ID = "model_downloads"
        private const val NOTIFICATION_ID = 4102
        private const val PREFS = "model_download_status"
        // Download buffer budget: 16 segments × 512 KiB per-segment
        // read buffer = 8 MiB peak while downloading the 695 MiB model
        // + 854 MiB mmproj. No android:largeHeap is used; native model
        // weights are mmap'd (useMmap:true, useMlock:false) so only
        // touched pages are resident.
        private const val SEGMENT_COUNT = 16
        private const val REPORT_INTERVAL_MS = 400L
        // `channel.force(true)` is a synchronous fsync on the socket-read
        // thread, so persisting too often stalls the transfer on slow flash.
        // 4s balances crash-resume safety (worst case: a redownload) against
        // keeping the pipe full.
        private const val PERSIST_INTERVAL_MS = 4000L
        private const val SPEED_SAMPLE_INTERVAL_MS = 1000L
        private const val BUFFER_SIZE = 512 * 1024 // per-segment I/O buffer; see budget above

        /**
         * Process-local liveness flag. SharedPreferences persist `active=true`
         * even after the app process is killed (for example when the user
         * swipes the app away mid-download), so the method-channel `start`
         * guard must consult this flag instead of the persisted value. A fresh
         * process resets it to false, allowing a stale partial to resume.
         */
        val isRunning = AtomicBoolean(false)

        /**
         * Monotonic counter bumped on every status write. Dart compares
         * successive reads to tell a live transfer apart from one whose thread
         * died or is wedged without updating the persisted flags (the persisted
         * `active`/`progress` values alone can look healthy long after the
         * transfer has stopped).
         */
        val heartbeat = AtomicLong(0)

        fun status(context: Context): Map<String, Any> {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return mapOf(
                // The persisted flag outlives the thread that set it (a killed
                // process or an uncaught Error leaves `active=true` behind), so
                // only report active while this process really has a transfer
                // running. Dart uses this to detect and restart a dead service.
                "active" to (isRunning.get() && prefs.getBoolean("active", false)),
                "complete" to prefs.getBoolean("complete", false),
                "failed" to prefs.getBoolean("failed", false),
                "cancelled" to prefs.getBoolean("cancelled", false),
                "progress" to prefs.getFloat("progress", 0f).toDouble(),
                "speedBps" to prefs.getLong("speedBps", 0L).toDouble(),
                "remainingBytes" to prefs.getLong("remainingBytes", 0L),
                "target" to (prefs.getString("target", "") ?: ""),
                "error" to (prefs.getString("error", "") ?: ""),
                "heartbeat" to heartbeat.get(),
            )
        }

        fun cancel(context: Context, target: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("cancelled", true)
                .putString("cancelTarget", target)
                .apply()
            context.stopService(Intent(context, ModelDownloadService::class.java))
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_START) return START_NOT_STICKY
        val url = intent.getStringExtra(EXTRA_URL) ?: return START_NOT_STICKY
        val target = intent.getStringExtra(EXTRA_TARGET) ?: return START_NOT_STICKY
        if (!isRunning.compareAndSet(false, true)) {
            // A transfer is already running in this process. Ignore the
            // duplicate start; the caller's polling loop observes the existing
            // download instead of opening a second writer on the same file.
            return START_REDELIVER_INTENT
        }
        val expectedBytes = intent.getLongExtra(EXTRA_EXPECTED_BYTES, 0L)
        val label = intent.getStringExtra(EXTRA_LABEL) ?: "AI model"
        createChannel()
        updateStatus(active = true, complete = false, failed = false, cancelled = false, progress = 0f, target = target)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification("Downloading $label", 0, false),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification("Downloading $label", 0, false))
        }
        thread(name = "FinnModelDownload") {
            try {
                download(url, File("$target.part"), target, expectedBytes, label)
                updateStatus(active = false, complete = true, failed = false, cancelled = false, progress = 1f, target = target)
                notificationManager().notify(NOTIFICATION_ID, notification("$label downloaded", 100, true))
            } catch (error: Throwable) {
                // `Throwable` (not `Exception`) so an Error like OOM is recorded
                // as a failure instead of silently leaving stale progress behind.
                val cancelled = wasCancelled(target)
                Log.w(TAG, "Model download stopped", error)
                updateStatus(active = false, complete = false, failed = !cancelled, cancelled = cancelled, progress = 0f, target = target, error = error.message ?: error.javaClass.simpleName)
                notificationManager().notify(NOTIFICATION_ID, notification("Model download paused", 0, true))
            } finally {
                isRunning.set(false)
                stopForeground(STOP_FOREGROUND_DETACH)
                stopSelf(startId)
            }
        }
        return START_REDELIVER_INTENT
    }

    private fun resolveFinalUrl(urlString: String): String {
        var currentUrl = urlString
        var redirects = 0
        while (redirects < 6) {
            try {
                val conn = (URL(currentUrl).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 15_000
                    readTimeout = 15_000
                    instanceFollowRedirects = false
                    setRequestProperty("User-Agent", "FinnAI/1.0 (Android)")
                    setRequestProperty("Accept-Encoding", "identity")
                    requestMethod = "HEAD"
                    connect()
                }
                val code = conn.responseCode
                val location = conn.getHeaderField("Location")
                conn.disconnect()
                if (code in listOf(HttpURLConnection.HTTP_MOVED_PERM, HttpURLConnection.HTTP_MOVED_TEMP, HttpURLConnection.HTTP_SEE_OTHER, 307, 308) && location != null) {
                    currentUrl = if (location.startsWith("http://") || location.startsWith("https://")) {
                        location
                    } else {
                        URL(URL(currentUrl), location).toString()
                    }
                    redirects++
                } else {
                    break
                }
            } catch (_: Exception) {
                break
            }
        }
        return currentUrl
    }

    private fun download(url: String, partial: File, target: String, expectedBytes: Long, label: String) {
        val resolvedUrl = resolveFinalUrl(url)
        partial.parentFile?.mkdirs()
        var existing = if (partial.exists()) partial.length() else 0L
        if (existing > expectedBytes) {
            partial.delete()
            existing = 0L
            clearRangeProgress(target)
        }

        var ranged = false
        var total = if (expectedBytes > 0) expectedBytes else 0L
        val probe = openConnection(resolvedUrl, 0L, 0L)
        try {
            ranged = probe.responseCode == HttpURLConnection.HTTP_PARTIAL
            if (total <= 0) {
                val contentRange = probe.getHeaderField("Content-Range")
                if (contentRange != null) {
                    val slash = contentRange.lastIndexOf('/')
                    if (slash >= 0) total = contentRange.substring(slash + 1).toLongOrNull() ?: 0L
                }
                if (total <= 0) total = probe.contentLengthLong
            }
        } catch (_: Exception) {
            // The probe is opportunistic; the transfer below reports real failures.
        } finally {
            probe.disconnect()
        }

        if (!ranged || total <= 0) {
            // Segmented resume state only makes sense for range-capable hosts.
            // A stale sparse partial can't be trusted without byte ranges.
            if (existing > 0) {
                partial.delete()
                existing = 0L
                clearRangeProgress(target)
            }
            downloadSingleStream(resolvedUrl, partial, existing, total, expectedBytes, label, target)
        } else {
            downloadSegmented(resolvedUrl, partial, existing, total, expectedBytes, label, target)
        }
    }

    /** Fallback for endpoints without byte-range support. */
    private fun downloadSingleStream(
        url: String,
        partial: File,
        existing: Long,
        total: Long,
        expectedBytes: Long,
        label: String,
        target: String,
    ) {
        // A single connection can drop mid-transfer for a transient reason
        // (radio handoff, proxy hiccup). Without byte-range support there is
        // no way to resume, but retrying from zero beats failing the whole
        // download over one blip.
        var attempt = 0
        while (true) {
            try {
                downloadSingleStreamOnce(url, partial, existing, total, expectedBytes, label, target)
                return
            } catch (error: Exception) {
                if (wasCancelled(target)) throw error
                if (attempt >= 2) throw error
                attempt++
                Thread.sleep(600L * attempt)
            }
        }
    }

    private fun downloadSingleStreamOnce(
        url: String,
        partial: File,
        existing: Long,
        total: Long,
        expectedBytes: Long,
        label: String,
        target: String,
    ) {
        var current = existing
        var connection = openConnection(url, if (current > 0) current else 0L, -1L)
        if (current > 0 && connection.responseCode == HttpURLConnection.HTTP_OK) {
            partial.delete()
            current = 0L
            connection.disconnect()
            connection = openConnection(url, 0L, -1L)
        }
        if (connection.responseCode !in 200..299) throw IllegalStateException("HTTP ${connection.responseCode}")
        val contentLength = connection.contentLengthLong
        val effectiveTotal = when {
            total > 0 -> total
            contentLength > 0 -> current + contentLength
            else -> expectedBytes
        }
        connection.inputStream.use { input ->
            FileOutputStream(partial, current > 0).use { output ->
                val buffer = ByteArray(BUFFER_SIZE)
                var received = current
                var lastReportAt = 0L
                var lastSampleAt = System.currentTimeMillis()
                var lastSampleBytes = received
                var smoothedSpeedBps = 0L
                while (true) {
                    if (wasCancelled(target)) throw IllegalStateException("Download paused")
                    val read = input.read(buffer)
                    if (read < 0) break
                    output.write(buffer, 0, read)
                    received += read
                    val now = System.currentTimeMillis()
                    // Sample the speed over a fixed 1s window and blend it with
                    // the previous estimate so the label is stable instead of
                    // bouncing with every read() burst.
                    if (now - lastSampleAt >= SPEED_SAMPLE_INTERVAL_MS) {
                        val elapsedMs = maxOf(1L, now - lastSampleAt)
                        val instant = ((received - lastSampleBytes) * 1000L) / elapsedMs
                        smoothedSpeedBps = if (smoothedSpeedBps <= 0L) {
                            instant
                        } else {
                            (smoothedSpeedBps * 7L + instant * 3L) / 10L
                        }
                        lastSampleAt = now
                        lastSampleBytes = received
                    }
                    if (now - lastReportAt >= REPORT_INTERVAL_MS) {
                        lastReportAt = now
                        val progress = if (effectiveTotal > 0) (received.toDouble() / effectiveTotal).coerceIn(0.0, 1.0) else 0.0
                        val remainingBytes = maxOf(0L, effectiveTotal - received)
                        reportProgress(label, progress, smoothedSpeedBps, remainingBytes, target)
                    }
                }
                output.fd.sync()
            }
        }
        connection.disconnect()
        if (expectedBytes > 0 && partial.length() != expectedBytes) throw IllegalStateException("Downloaded file size did not match")
    }

    /**
     * Splits the transfer into [SEGMENT_COUNT] byte ranges fetched in parallel.
     * This saturates slow/high-latency links far better than a single stream,
     * writing each range to a disjoint file offset so no segment blocks another.
     * Per-range completion is persisted so an interrupted transfer resumes the
     * exact ranges that were already fetched.
     */
    private fun downloadSegmented(
        url: String,
        partial: File,
        existing: Long,
        total: Long,
        expectedBytes: Long,
        label: String,
        target: String,
    ) {
        val chunkSize = (total + SEGMENT_COUNT - 1) / SEGMENT_COUNT
        val startOffsets = LongArray(SEGMENT_COUNT) { it * chunkSize }
        val endOffsets = LongArray(SEGMENT_COUNT) { minOf((it + 1) * chunkSize - 1, total - 1) }
        val rangeLengths = LongArray(SEGMENT_COUNT) { endOffsets[it] - startOffsets[it] + 1 }

        val persisted = loadRangeProgress(target, rangeLengths)
        val receivedByRange = if (persisted != null && existing > 0) {
            persisted
        } else {
            val fresh = LongArray(SEGMENT_COUNT)
            // Without persisted segmented state, only a contiguous single-stream
            // prefix can be resumed safely.
            if (persisted == null && existing > 0 && existing <= total) {
                var covered = 0L
                for (i in 0 until SEGMENT_COUNT) {
                    if (covered + rangeLengths[i] <= existing) {
                        fresh[i] = rangeLengths[i]
                        covered += rangeLengths[i]
                    } else {
                        fresh[i] = maxOf(0L, existing - covered)
                        break
                    }
                }
            }
            fresh
        }
        saveRangeProgress(target, receivedByRange)

        val channel = FileChannel.open(
            partial.toPath(),
            StandardOpenOption.CREATE,
            StandardOpenOption.READ,
            StandardOpenOption.WRITE,
        )
        val received = AtomicLong(receivedByRange.sum())
        val failure = AtomicReference<Exception?>(null)
        val reportLock = Any()
        var lastSampleAt = System.currentTimeMillis()
        var lastSampleBytes = received.get()
        var lastSaveAt = 0L
        var lastReportAt = 0L
        var smoothedSpeedBps = 0L

        fun noteProgress(now: Long) {
            synchronized(reportLock) {
                val receivedNow = received.get()
                // The segments report at staggered offsets, so an
                // instantaneous sample covers only a few tens of milliseconds
                // and makes the speed label bounce wildly. Use a fixed 1s
                // window and blend each sample into a stable estimate.
                if (now - lastSampleAt >= SPEED_SAMPLE_INTERVAL_MS) {
                    val elapsedMs = maxOf(1L, now - lastSampleAt)
                    val instant = ((receivedNow - lastSampleBytes) * 1000L) / elapsedMs
                    smoothedSpeedBps = if (smoothedSpeedBps <= 0L) {
                        instant
                    } else {
                        (smoothedSpeedBps * 7L + instant * 3L) / 10L
                    }
                    lastSampleAt = now
                    lastSampleBytes = receivedNow
                }
                if (now - lastReportAt >= REPORT_INTERVAL_MS) {
                    lastReportAt = now
                    val progress = (receivedNow.toDouble() / total).coerceIn(0.0, 1.0)
                    val remainingBytes = maxOf(0L, total - receivedNow)
                    reportProgress(label, progress, smoothedSpeedBps, remainingBytes, target)
                }
                if (now - lastSaveAt >= PERSIST_INTERVAL_MS) {
                    lastSaveAt = now
                    // Make the bytes durable before recording them as
                    // resumable; otherwise a crash/reboot leaves progress that
                    // points past holes of data that never reached disk, and
                    // the final SHA-256 then fails on resume.
                    channel.force(true)
                    saveRangeProgress(target, receivedByRange)
                }
            }
        }

        fun fetchRange(index: Int) {
            if (receivedByRange[index] >= rangeLengths[index]) return
            var attempt = 0
            while (true) {
                try {
                    val position = startOffsets[index] + receivedByRange[index]
                    val connection = openConnection(url, position, endOffsets[index])
                    try {
                        if (connection.responseCode != HttpURLConnection.HTTP_PARTIAL) {
                            throw IllegalStateException("Range $index failed (HTTP ${connection.responseCode})")
                        }
                        connection.inputStream.use { input ->
                            val buffer = ByteArray(BUFFER_SIZE)
                            var rangeReportAt = 0L
                            while (true) {
                                if (wasCancelled(target)) throw IllegalStateException("Download paused")
                                val read = input.read(buffer)
                                if (read < 0) break
                                val bytes = ByteBuffer.wrap(buffer, 0, read)
                                val base = startOffsets[index] + receivedByRange[index]
                                while (bytes.hasRemaining()) {
                                    channel.write(bytes, base + bytes.position())
                                }
                                receivedByRange[index] += read.toLong()
                                received.addAndGet(read.toLong())
                                val now = System.currentTimeMillis()
                                if (now - rangeReportAt >= REPORT_INTERVAL_MS) {
                                    rangeReportAt = now
                                    noteProgress(now)
                                }
                            }
                        }
                    } finally {
                        connection.disconnect()
                    }
                    if (receivedByRange[index] < rangeLengths[index]) {
                        throw IllegalStateException("Range $index truncated (${receivedByRange[index]}/${rangeLengths[index]})")
                    }
                    return
                } catch (error: Exception) {
                    if (wasCancelled(target)) {
                        failure.set(IllegalStateException("Download paused"))
                        return
                    }
                    // Retry a flaky range several times with backoff so a
                    // transient drop never kills the whole transfer; the
                    // Dart-side supervisor additionally restarts the service
                    // (resuming persisted ranges) for anything that escapes.
                    if (attempt >= 4) {
                        failure.set(error)
                        return
                    }
                    attempt++
                    Thread.sleep(500L * attempt)
                }
            }
        }

        val threads = (0 until SEGMENT_COUNT)
            .filter { receivedByRange[it] < rangeLengths[it] }
            .map { index -> thread(name = "FinnModelSegment$index") { fetchRange(index) } }
        threads.forEach { it.join() }
        // Flush before clearing the resume state so a completed transfer can
        // never be promoted from bytes that only live in the page cache.
        channel.force(true)
        channel.close()

        failure.get()?.let { throw it }
        if (expectedBytes > 0 && partial.length() != expectedBytes) {
            throw IllegalStateException("Downloaded file size did not match")
        }
        clearRangeProgress(target)
    }

    private fun openConnection(url: String, rangeStart: Long, rangeEnd: Long): HttpURLConnection {
        var currentUrl = url
        var redirects = 0
        while (true) {
            val connection = (URL(currentUrl).openConnection() as HttpURLConnection).apply {
                connectTimeout = 20_000
                readTimeout = 30_000
                instanceFollowRedirects = false
                setRequestProperty("User-Agent", "FinnAI/1.0 (Android)")
                setRequestProperty("Accept-Encoding", "identity")
                setRequestProperty("Connection", "keep-alive")
                val range = if (rangeEnd >= 0) "bytes=$rangeStart-$rangeEnd" else "bytes=$rangeStart-"
                setRequestProperty("Range", range)
                connect()
            }
            val code = connection.responseCode
            if (code in listOf(HttpURLConnection.HTTP_MOVED_PERM, HttpURLConnection.HTTP_MOVED_TEMP, HttpURLConnection.HTTP_SEE_OTHER, 307, 308)) {
                val location = connection.getHeaderField("Location")
                connection.disconnect()
                if (location != null && redirects < 6) {
                    currentUrl = if (location.startsWith("http://") || location.startsWith("https://")) {
                        location
                    } else {
                        URL(URL(currentUrl), location).toString()
                    }
                    redirects++
                    continue
                }
            }
            return connection
        }
    }

    private fun reportProgress(label: String, progress: Double, speedBps: Long, remainingBytes: Long, target: String) {
        updateStatus(
            active = true,
            complete = false,
            failed = false,
            cancelled = false,
            progress = progress.toFloat(),
            speedBps = speedBps,
            remainingBytes = remainingBytes,
            target = target,
        )
        notificationManager().notify(
            NOTIFICATION_ID,
            notification(downloadingText(label, speedBps, remainingBytes), (progress * 100).toInt(), false),
        )
    }

    private fun formatSpeed(speedBps: Long): String {
        if (speedBps <= 0) return ""
        val kbPerSec = speedBps / 1024.0
        return if (kbPerSec < 1024.0) {
            String.format(Locale.US, "%.0f KB/s", kbPerSec)
        } else {
            String.format(Locale.US, "%.1f MB/s", kbPerSec / 1024.0)
        }
    }

    private fun formatEta(remainingBytes: Long, speedBps: Long): String {
        if (speedBps <= 0 || remainingBytes <= 0) return ""
        val seconds = remainingBytes / speedBps
        return when {
            seconds < 1 -> "~1s left"
            seconds < 60 -> "~${seconds}s left"
            seconds < 3600 -> "~${seconds / 60}m ${seconds % 60}s left"
            else -> "~${seconds / 3600}h ${(seconds % 3600) / 60}m left"
        }
    }

    private fun downloadingText(label: String, speedBps: Long, remainingBytes: Long): String {
        val parts = mutableListOf("Downloading $label")
        formatSpeed(speedBps).takeIf { it.isNotEmpty() }?.let { parts.add(it) }
        formatEta(remainingBytes, speedBps).takeIf { it.isNotEmpty() }?.let { parts.add(it) }
        return parts.joinToString(" · ")
    }

    private fun rangeProgressKey(target: String) = "rangeProgress_$target"

    private fun loadRangeProgress(target: String, rangeLengths: LongArray): LongArray? {
        val encoded = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(rangeProgressKey(target), null) ?: return null
        val parts = encoded.split(",")
        if (parts.size != rangeLengths.size) return null
        val loaded = LongArray(rangeLengths.size)
        for (i in parts.indices) {
            val value = parts[i].toLongOrNull() ?: return null
            if (value < 0 || value > rangeLengths[i]) return null
            loaded[i] = value
        }
        return loaded
    }

    private fun saveRangeProgress(target: String, receivedByRange: LongArray) {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(rangeProgressKey(target), receivedByRange.joinToString(","))
            .apply()
    }

    private fun clearRangeProgress(target: String) {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove(rangeProgressKey(target))
            .apply()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager().createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Model downloads", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    private fun notification(text: String, progress: Int, done: Boolean) = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(com.abhiflex.finnai.R.drawable.ic_notification)
        .setContentTitle("Finn AI")
        .setContentText(text)
        .setOnlyAlertOnce(true)
        .setOngoing(!done)
        .setProgress(100, progress, false)
        .setContentIntent(PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        .build()

    private fun notificationManager() = getSystemService(NotificationManager::class.java)

    private fun wasCancelled(target: String): Boolean {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return prefs.getBoolean("cancelled", false) &&
            prefs.getString("cancelTarget", "") == target
    }

    private fun updateStatus(
        active: Boolean,
        complete: Boolean,
        failed: Boolean,
        cancelled: Boolean = false,
        progress: Float,
        speedBps: Long = 0L,
        remainingBytes: Long = 0L,
        target: String,
        error: String = "",
    ) {
        heartbeat.incrementAndGet()
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("active", active)
            .putBoolean("complete", complete)
            .putBoolean("failed", failed)
            .putBoolean("cancelled", cancelled)
            .putFloat("progress", progress)
            .putLong("speedBps", speedBps)
            .putLong("remainingBytes", remainingBytes)
            .putString("target", target)
            .putString("error", error)
            .apply()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
