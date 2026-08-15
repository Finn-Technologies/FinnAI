package com.abhiflex.finnai

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/** Keeps a large model transfer alive after Flutter's process/activity is closed. */
class ModelDownloadService : Service() {
    companion object {
        const val ACTION_START = "com.abhiflex.finnai.START_MODEL_DOWNLOAD"
        const val EXTRA_URL = "url"
        const val EXTRA_TARGET = "target"
        const val EXTRA_EXPECTED_BYTES = "expectedBytes"
        const val EXTRA_LABEL = "label"
        private const val CHANNEL_ID = "model_downloads"
        private const val NOTIFICATION_ID = 4102
        private const val PREFS = "model_download_status"

        fun status(context: Context): Map<String, Any> {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return mapOf(
                "active" to prefs.getBoolean("active", false),
                "complete" to prefs.getBoolean("complete", false),
                "failed" to prefs.getBoolean("failed", false),
                "cancelled" to prefs.getBoolean("cancelled", false),
                "progress" to prefs.getFloat("progress", 0f).toDouble(),
                "speedBps" to prefs.getLong("speedBps", 0L).toDouble(),
                "remainingBytes" to prefs.getLong("remainingBytes", 0L),
                "target" to (prefs.getString("target", "") ?: ""),
                "error" to (prefs.getString("error", "") ?: ""),
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
        val expectedBytes = intent.getLongExtra(EXTRA_EXPECTED_BYTES, 0L)
        val label = intent.getStringExtra(EXTRA_LABEL) ?: "AI model"
        createChannel()
        updateStatus(active = true, complete = false, failed = false, cancelled = false, progress = 0f, target = target)
        startForeground(NOTIFICATION_ID, notification("Downloading $label", 0, false))
        thread(name = "FinnModelDownload") {
            try {
                download(url, File("$target.part"), target, expectedBytes, label)
                updateStatus(active = false, complete = true, failed = false, cancelled = false, progress = 1f, target = target)
                notificationManager().notify(NOTIFICATION_ID, notification("$label downloaded", 100, true))
            } catch (error: Exception) {
                val cancelled = wasCancelled(target)
                updateStatus(active = false, complete = false, failed = !cancelled, cancelled = cancelled, progress = 0f, target = target, error = error.message ?: "Download failed")
                notificationManager().notify(NOTIFICATION_ID, notification("Model download paused", 0, true))
            } finally {
                stopForeground(STOP_FOREGROUND_DETACH)
                stopSelf(startId)
            }
        }
        return START_REDELIVER_INTENT
    }

    private fun download(url: String, partial: File, target: String, expectedBytes: Long, label: String) {
        partial.parentFile?.mkdirs()
        var existing = if (partial.exists()) partial.length() else 0L
        var connection = openConnection(url, existing)
        if (existing > 0 && connection.responseCode == HttpURLConnection.HTTP_OK) {
            partial.delete()
            existing = 0L
            connection.disconnect()
            connection = openConnection(url, 0)
        }
        if (connection.responseCode !in 200..299) throw IllegalStateException("HTTP ${connection.responseCode}")
        val contentLength = connection.contentLengthLong
        val total = if (contentLength > 0) existing + contentLength else expectedBytes
        connection.inputStream.use { input ->
            FileOutputStream(partial, existing > 0).use { output ->
                val buffer = ByteArray(256 * 1024)
                var received = existing
                var lastUpdate = 0L
                var lastSampleAt = System.currentTimeMillis()
                var lastSampleBytes = existing
                while (true) {
                    if (wasCancelled(target)) throw IllegalStateException("Download paused")
                    val read = input.read(buffer)
                    if (read < 0) break
                    output.write(buffer, 0, read)
                    received += read
                    val now = System.currentTimeMillis()
                    if (now - lastUpdate >= 400) {
                        lastUpdate = now
                        val progress = if (total > 0) (received.toDouble() / total).coerceIn(0.0, 1.0) else 0.0
                        val elapsedMs = (now - lastSampleAt).coerceAtLeast(1L)
                        val speedBps = ((received - lastSampleBytes) * 1000L) / elapsedMs
                        lastSampleAt = now
                        lastSampleBytes = received
                        val remainingBytes = (total - received).coerceAtLeast(0L)
                        updateStatus(active = true, complete = false, failed = false, cancelled = false, progress = progress.toFloat(), speedBps = speedBps, remainingBytes = remainingBytes, target = partial.path.removeSuffix(".part"))
                        notificationManager().notify(NOTIFICATION_ID, notification("Downloading $label", (progress * 100).toInt(), false))
                    }
                }
                output.fd.sync()
            }
        }
        connection.disconnect()
        if (expectedBytes > 0 && partial.length() != expectedBytes) throw IllegalStateException("Downloaded file size did not match")
    }

    private fun openConnection(url: String, existing: Long): HttpURLConnection =
        (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 20_000
            readTimeout = 30_000
            instanceFollowRedirects = true
            setRequestProperty("Accept-Encoding", "identity")
            if (existing > 0) setRequestProperty("Range", "bytes=$existing-")
            connect()
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
