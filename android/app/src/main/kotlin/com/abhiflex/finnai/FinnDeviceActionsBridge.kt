package com.abhiflex.finnai

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.AlarmClock
import android.provider.MediaStore
import android.provider.Settings
import android.view.KeyEvent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Device actions: alarms, timers, media transport, and the system settings
 * screens Finn can open.
 *
 * Every branch resolves its intent before starting it and reports an explicit
 * outcome, because a swallowed [ActivityNotFoundException] would read to the
 * user as Finn silently doing nothing.
 */
object FinnDeviceActionsBridge {
    private const val CHANNEL = "finn_ai/device_actions"

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "perform") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                if (name.isNullOrBlank()) {
                    result.error("args", "Missing action name", null)
                    return@setMethodCallHandler
                }
                @Suppress("UNCHECKED_CAST")
                val arguments = (call.argument<Any>("arguments") as? Map<String, Any?>)
                    ?: emptyMap()
                result.success(perform(activity, name, arguments))
            }
    }

    private fun perform(
        activity: Activity,
        name: String,
        arguments: Map<String, Any?>,
    ): Map<String, Any?> = try {
        when (name) {
            "set_alarm" -> setAlarm(activity, arguments)
            "set_timer" -> setTimer(activity, arguments)
            "show_alarms" -> start(activity, Intent(AlarmClock.ACTION_SHOW_ALARMS))
            "torch" -> torch(activity, arguments)
            "media" -> media(activity, arguments)
            "volume" -> volume(activity, arguments)
            "open_settings" -> openSettings(activity, arguments)
            "open_app" -> openApp(activity, arguments)
            "dial" -> start(
                activity,
                Intent(Intent.ACTION_DIAL, Uri.parse("tel:${requireText(arguments, "number")}")),
            )
            "compose_sms" -> composeSms(activity, arguments)
            "compose_email" -> composeEmail(activity, arguments)
            "take_photo" -> start(activity, Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA))
            "open_url" -> start(
                activity,
                Intent(Intent.ACTION_VIEW, Uri.parse(webUri(requireText(arguments, "url")))),
            )
            "navigate" -> start(
                activity,
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("geo:0,0?q=${Uri.encode(requireText(arguments, "query"))}"),
                ),
            )
            "share" -> {
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, requireText(arguments, "text"))
                }
                start(activity, Intent.createChooser(send, null))
            }
            else -> mapOf("outcome" to "unavailable", "error" to "Unknown action: $name")
        }
    } catch (e: IllegalArgumentException) {
        mapOf("outcome" to "failed", "error" to (e.message ?: "Invalid arguments"))
    } catch (e: Exception) {
        mapOf("outcome" to "failed", "error" to (e.message ?: e::class.java.simpleName))
    }

    private fun setAlarm(activity: Activity, arguments: Map<String, Any?>): Map<String, Any?> {
        val hour = intArgument(arguments, "hour") ?: throw IllegalArgumentException("Missing hour")
        val minute = intArgument(arguments, "minute") ?: 0
        if (hour !in 0..23) throw IllegalArgumentException("Hour out of range")
        if (minute !in 0..59) throw IllegalArgumentException("Minute out of range")
        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(AlarmClock.EXTRA_HOUR, hour)
            putExtra(AlarmClock.EXTRA_MINUTES, minute)
            putExtra(AlarmClock.EXTRA_SKIP_UI, true)
            textArgument(arguments, "label")?.let { putExtra(AlarmClock.EXTRA_MESSAGE, it) }
        }
        return start(
            activity,
            intent,
            detail = timeLabel(hour, minute),
            outcome = "performed",
        )
    }

    private fun setTimer(activity: Activity, arguments: Map<String, Any?>): Map<String, Any?> {
        val seconds = intArgument(arguments, "seconds")
            ?: throw IllegalArgumentException("Missing seconds")
        if (seconds <= 0) throw IllegalArgumentException("Duration must be positive")
        val intent = Intent(AlarmClock.ACTION_SET_TIMER).apply {
            putExtra(AlarmClock.EXTRA_LENGTH, seconds)
            putExtra(AlarmClock.EXTRA_SKIP_UI, true)
            textArgument(arguments, "label")?.let { putExtra(AlarmClock.EXTRA_MESSAGE, it) }
        }
        return start(
            activity,
            intent,
            detail = durationLabel(seconds),
            outcome = "performed",
        )
    }

    private fun torch(activity: Activity, arguments: Map<String, Any?>): Map<String, Any?> {
        // No default: assuming "on" when the flag is absent turned a malformed
        // call into a lit torch.
        val on = boolArgument(arguments, "on")
            ?: throw IllegalArgumentException("Missing on")
        val manager = activity.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
            ?: return mapOf("outcome" to "unavailable", "error" to "No camera service")
        val cameraId = manager.cameraIdList.firstOrNull { id ->
            val characteristics = manager.getCameraCharacteristics(id)
            characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        } ?: return mapOf("outcome" to "unavailable", "error" to "This device has no flash")
        manager.setTorchMode(cameraId, on)
        return mapOf("outcome" to "performed")
    }

    private fun media(activity: Activity, arguments: Map<String, Any?>): Map<String, Any?> {
        val keyCode = when (textArgument(arguments, "action")) {
            "play" -> KeyEvent.KEYCODE_MEDIA_PLAY
            "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
            "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
            "previous" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            else -> throw IllegalArgumentException("Unknown media action")
        }
        val manager = audioManager(activity)
        manager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        manager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
        return mapOf("outcome" to "performed")
    }

    private fun volume(activity: Activity, arguments: Map<String, Any?>): Map<String, Any?> {
        val manager = audioManager(activity)
        val stream = AudioManager.STREAM_MUSIC
        val direction = when (textArgument(arguments, "direction")) {
            "up" -> AudioManager.ADJUST_RAISE
            "down" -> AudioManager.ADJUST_LOWER
            "mute" -> AudioManager.ADJUST_MUTE
            else -> throw IllegalArgumentException("Unknown volume direction")
        }
        manager.adjustStreamVolume(stream, direction, AudioManager.FLAG_SHOW_UI)
        return mapOf("outcome" to "performed")
    }

    private fun openSettings(activity: Activity, arguments: Map<String, Any?>): Map<String, Any?> {
        val screen = textArgument(arguments, "screen")
            ?: throw IllegalArgumentException("Missing screen")
        // Wi-Fi first tries the quick-settings panel, which is one tap from the
        // toggle; older releases and some OEM launchers only have the full page.
        if (screen == "wifi" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val panel = Intent(Settings.Panel.ACTION_WIFI)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (panel.resolveActivity(activity.packageManager) != null) {
                activity.startActivity(panel)
                return mapOf("outcome" to "opened", "detail" to screen)
            }
        }
        val action = SETTINGS_SCREENS[screen]
            ?: return mapOf("outcome" to "unavailable", "error" to "Unknown screen: $screen")
        return start(activity, Intent(action), detail = screen)
    }

    private fun openApp(activity: Activity, arguments: Map<String, Any?>): Map<String, Any?> {
        val query = textArgument(arguments, "name")
            ?: throw IllegalArgumentException("Missing app name")
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val candidates = activity.packageManager
            .queryIntentActivities(launcher, 0)
            .mapNotNull { it.activityInfo?.applicationInfo }
            .distinctBy { it.packageName }
        val needle = query.lowercase().trim()
        val match = candidates.firstOrNull {
            it.loadLabel(activity.packageManager).toString().lowercase() == needle
        } ?: candidates.firstOrNull {
            it.loadLabel(activity.packageManager).toString().lowercase().contains(needle)
        } ?: candidates.firstOrNull {
            it.packageName.lowercase().contains(needle)
        } ?: return mapOf("outcome" to "unavailable", "error" to "No app matching \"$query\"")
        val launch = activity.packageManager.getLaunchIntentForPackage(match.packageName)
            ?: return mapOf("outcome" to "unavailable", "error" to "App is not launchable")
        activity.startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return mapOf(
            "outcome" to "opened",
            "detail" to match.loadLabel(activity.packageManager).toString(),
        )
    }

    private fun composeSms(activity: Activity, arguments: Map<String, Any?>): Map<String, Any?> {
        val to = textArgument(arguments, "to")
        val body = textArgument(arguments, "body")
        val uri = if (to.isNullOrBlank()) Uri.parse("smsto:") else Uri.parse("smsto:$to")
        val intent = Intent(Intent.ACTION_SENDTO, uri)
        body?.let { intent.putExtra("sms_body", it) }
        return start(activity, intent, detail = to.orEmpty())
    }

    private fun composeEmail(activity: Activity, arguments: Map<String, Any?>): Map<String, Any?> {
        val intent = Intent(Intent.ACTION_SENDTO)
        val to = textArgument(arguments, "to")
        intent.data = Uri.parse(if (to.isNullOrBlank()) "mailto:" else "mailto:$to")
        textArgument(arguments, "subject")?.let { intent.putExtra(Intent.EXTRA_SUBJECT, it) }
        textArgument(arguments, "body")?.let { intent.putExtra(Intent.EXTRA_TEXT, it) }
        return start(activity, intent, detail = to.orEmpty())
    }

    private fun start(
        activity: Activity,
        intent: Intent,
        detail: String = "",
        outcome: String = "opened",
    ): Map<String, Any?> {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            activity.startActivity(intent)
            mapOf("outcome" to outcome, "detail" to detail)
        } catch (_: ActivityNotFoundException) {
            mapOf(
                "outcome" to "unavailable",
                "detail" to detail,
                "error" to "No app on this device handles that",
            )
        }
    }

    private fun audioManager(activity: Activity): AudioManager =
        activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun intArgument(arguments: Map<String, Any?>, key: String): Int? = when (
        val value = arguments[key]
    ) {
        is Int -> value
        is Number -> value.toInt()
        is String -> value.toIntOrNull()
        else -> null
    }

    private fun textArgument(arguments: Map<String, Any?>, key: String): String? =
        arguments[key]?.toString()?.takeIf { it.isNotBlank() }

    private fun boolArgument(arguments: Map<String, Any?>, key: String): Boolean? =
        when (val value = arguments[key]) {
            is Boolean -> value
            is String -> when (value.trim().lowercase()) {
                "true", "on", "yes", "1" -> true
                "false", "off", "no", "0" -> false
                else -> null
            }
            else -> null
        }

    /// ACTION_VIEW with a scheme-less host ("example.com") resolves to nothing
    /// and surfaces as an unhelpful "no app handles that".
    private fun webUri(url: String): String =
        if (url.contains("://")) url else "https://${url.trim()}"

    private fun requireText(arguments: Map<String, Any?>, key: String): String =
        textArgument(arguments, key) ?: throw IllegalArgumentException("Missing $key")

    private fun timeLabel(hour: Int, minute: Int): String =
        String.format("%02d:%02d", hour, minute)

    private fun durationLabel(seconds: Int): String {
        val minutes = seconds / 60
        return if (minutes > 0) "$minutes min" else "$seconds s"
    }

    private val SETTINGS_SCREENS: Map<String, String> = mapOf(
        "system" to Settings.ACTION_SETTINGS,
        "wifi" to Settings.ACTION_WIFI_SETTINGS,
        "bluetooth" to Settings.ACTION_BLUETOOTH_SETTINGS,
        "airplane" to Settings.ACTION_AIRPLANE_MODE_SETTINGS,
        "hotspot" to Settings.ACTION_WIRELESS_SETTINGS,
        "mobile_data" to Settings.ACTION_WIRELESS_SETTINGS,
        "battery_saver" to Settings.ACTION_BATTERY_SAVER_SETTINGS,
        "battery_usage" to Intent.ACTION_POWER_USAGE_SUMMARY,
        "dnd" to Settings.ACTION_SOUND_SETTINGS,
        "display" to Settings.ACTION_DISPLAY_SETTINGS,
        "sound" to Settings.ACTION_SOUND_SETTINGS,
        "location" to Settings.ACTION_LOCATION_SOURCE_SETTINGS,
        "storage" to Settings.ACTION_INTERNAL_STORAGE_SETTINGS,
        "date_time" to Settings.ACTION_DATE_SETTINGS,
        "keyboard" to Settings.ACTION_INPUT_METHOD_SETTINGS,
        "language" to Settings.ACTION_LOCALE_SETTINGS,
        "accessibility" to Settings.ACTION_ACCESSIBILITY_SETTINGS,
        "applications" to Settings.ACTION_APPLICATION_SETTINGS,
        "nfc" to Settings.ACTION_NFC_SETTINGS,
        "cast" to Settings.ACTION_CAST_SETTINGS,
        "vpn" to Settings.ACTION_VPN_SETTINGS,
        "developer" to Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS,
        "home" to Settings.ACTION_HOME_SETTINGS,
    )
}
