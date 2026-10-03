package com.abhiflex.finnai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Listens for the phone events a flow can start from: charger in or out, the
 * battery falling, headphones, Wi-Fi, airplane mode, unlocking.
 *
 * Android does not deliver most of these to a manifest receiver, so something
 * has to be running to hear them. That something is this foreground service,
 * with its one quiet notification, and it exists only while at least one
 * enabled flow needs it (see [sync]). It holds no Flutter engine; when an event
 * matches, [FlowDispatcher] decides what to run and where.
 */
class FlowTriggerService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private var startedAt = 0L
    private var lastBattery = -1
    private var batteryReceiver: BroadcastReceiver? = null
    private var systemReceiver: BroadcastReceiver? = null
    private var audioCallback: AudioDeviceCallback? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    companion object {
        /** True while the service is alive; read by [FlowDispatcher]. */
        @Volatile
        var running = false
            private set

        private const val CHANNEL_ID = "finn_flow_service"
        private const val NOTIFICATION_ID = 4103

        /** Callbacks fire once for what is already true when they register; ignore those. */
        private const val SETTLE_MS = 1500L

        /** Starts or stops the service to match what the synced flows need. */
        fun sync(context: Context) {
            val app = context.applicationContext
            val wanted = FlowTriggerStore.events(app).isNotEmpty() ||
                FlowTriggerStore.alarms(app).any { it.auto }
            val allowed = FlowScheduler.notificationsAllowed(app)
            if (wanted && allowed) {
                try {
                    ContextCompat.startForegroundService(app, Intent(app, FlowTriggerService::class.java))
                } catch (_: Exception) {
                    // Started from a place Android does not allow (a background
                    // alarm). The flows still run when the app is opened.
                }
            } else if (running) {
                app.stopService(Intent(app, FlowTriggerService::class.java))
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startedAt = System.currentTimeMillis()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        running = true
        listen(FlowTriggerStore.events(this))
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        stopListening()
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Flows in the background", NotificationManager.IMPORTANCE_MIN).apply {
                    description = "Shown while FinnAI is listening for your Flows."
                    setShowBadge(false)
                },
            )
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(getString(R.string.finn_flow_service_title))
            .setContentText(getString(R.string.finn_flow_service_text))
            .setContentIntent(open)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun listen(events: List<FlowTriggerSpec>) {
        stopListening()
        val kinds = events.map { it.kind }.toSet()

        val systemFilter = IntentFilter()
        if ("chargerConnected" in kinds) systemFilter.addAction(Intent.ACTION_POWER_CONNECTED)
        if ("chargerDisconnected" in kinds) systemFilter.addAction(Intent.ACTION_POWER_DISCONNECTED)
        if ("airplaneOn" in kinds || "airplaneOff" in kinds) {
            systemFilter.addAction(Intent.ACTION_AIRPLANE_MODE_CHANGED)
        }
        if ("screenUnlocked" in kinds) systemFilter.addAction(Intent.ACTION_USER_PRESENT)
        if (systemFilter.countActions() > 0) {
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) = onSystem(intent)
            }
            ContextCompat.registerReceiver(this, receiver, systemFilter, ContextCompat.RECEIVER_NOT_EXPORTED)
            systemReceiver = receiver
        }

        if ("batteryLow" in kinds) {
            lastBattery = -1
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) = onBattery(intent)
            }
            // The battery broadcast is sticky: registering delivers the current
            // level at once, which seeds `lastBattery` without firing.
            ContextCompat.registerReceiver(
                this,
                receiver,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
            batteryReceiver = receiver
        }

        if ("headsetConnected" in kinds || "headsetDisconnected" in kinds) {
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val callback = object : AudioDeviceCallback() {
                override fun onAudioDevicesAdded(devices: Array<out AudioDeviceInfo>) {
                    if (settling()) return
                    if (devices.any { FlowEnvironmentBridge.isHeadsetType(it.type) }) {
                        FlowDispatcher.dispatchEvent(this@FlowTriggerService, "headsetConnected")
                    }
                }

                override fun onAudioDevicesRemoved(devices: Array<out AudioDeviceInfo>) {
                    if (settling()) return
                    if (devices.any { FlowEnvironmentBridge.isHeadsetType(it.type) }) {
                        FlowDispatcher.dispatchEvent(this@FlowTriggerService, "headsetDisconnected")
                    }
                }
            }
            audio.registerAudioDeviceCallback(callback, main)
            audioCallback = callback
        }

        if ("wifiConnected" in kinds || "wifiDisconnected" in kinds) {
            val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    if (!settling()) FlowDispatcher.dispatchEvent(this@FlowTriggerService, "wifiConnected")
                }

                override fun onLost(network: Network) {
                    if (!settling()) FlowDispatcher.dispatchEvent(this@FlowTriggerService, "wifiDisconnected")
                }
            }
            manager.registerNetworkCallback(
                NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build(),
                callback,
                main,
            )
            networkCallback = callback
        }
    }

    private fun settling() = System.currentTimeMillis() - startedAt < SETTLE_MS

    private fun onSystem(intent: Intent) {
        when (intent.action) {
            Intent.ACTION_POWER_CONNECTED -> FlowDispatcher.dispatchEvent(this, "chargerConnected")
            Intent.ACTION_POWER_DISCONNECTED -> FlowDispatcher.dispatchEvent(this, "chargerDisconnected")
            Intent.ACTION_USER_PRESENT -> FlowDispatcher.dispatchEvent(this, "screenUnlocked")
            Intent.ACTION_AIRPLANE_MODE_CHANGED -> FlowDispatcher.dispatchEvent(
                this,
                if (intent.getBooleanExtra("state", false)) "airplaneOn" else "airplaneOff",
            )
        }
    }

    /**
     * Fires a battery-low flow once as the level falls *through* its threshold
     * while not charging, never on every battery change below it.
     */
    private fun onBattery(intent: Intent) {
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
        if (level < 0 || scale <= 0) return
        val percent = level * 100 / scale
        val previous = lastBattery
        lastBattery = percent
        if (previous < 0 || percent >= previous) return
        val charging = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) != 0
        if (charging) return
        for (spec in FlowTriggerStore.events(this)) {
            if (spec.kind == "batteryLow" && previous > spec.level && percent <= spec.level) {
                FlowDispatcher.dispatch(this, spec, "event:batteryLow")
            }
        }
    }

    private fun stopListening() {
        systemReceiver?.let { runCatching { unregisterReceiver(it) } }
        batteryReceiver?.let { runCatching { unregisterReceiver(it) } }
        systemReceiver = null
        batteryReceiver = null
        audioCallback?.let {
            runCatching { (getSystemService(Context.AUDIO_SERVICE) as AudioManager).unregisterAudioDeviceCallback(it) }
        }
        audioCallback = null
        networkCallback?.let {
            runCatching { (getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager).unregisterNetworkCallback(it) }
        }
        networkCallback = null
    }
}
