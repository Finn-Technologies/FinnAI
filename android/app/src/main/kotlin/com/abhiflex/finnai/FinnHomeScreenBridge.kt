package com.abhiflex.finnai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * `finn_ai/home_screen`: pinning creations to the launcher and sharing files.
 *
 * `requestPinAppWidget` and `requestPinShortcut` both require API 26, which is
 * the app's floor, so neither needs a version branch beyond the runtime support
 * check. Every method reports failure rather than throwing, because a user
 * declining a pin is a normal outcome, not an error.
 */
object FinnHomeScreenBridge {
    private const val CHANNEL = "finn_ai/home_screen"

    fun register(engine: FlutterEngine, activity: android.app.Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(true)
                    "stagePendingWidget" -> result.success(stageWidget(activity, call.arguments))
                    "requestPinWidget" -> result.success(requestPinWidget(activity))
                    "requestPinShortcut" -> result.success(requestPinShortcut(activity, call.arguments))
                    "refreshWidgets" -> {
                        FinnHomeWidgetProvider.refreshAll(activity)
                        result.success(true)
                    }
                    "shareFile" -> result.success(shareFile(activity, call.arguments))
                    else -> result.notImplemented()
                }
            }
    }

    private fun stageWidget(context: Context, arguments: Any?): Boolean {
        val args = arguments as? Map<*, *> ?: return false
        val specPath = args["specPath"] as? String
        val label = args["label"] as? String ?: ""
        if (specPath.isNullOrBlank()) return false
        FinnHomeWidgetStore.stagePending(context, specPath, label)
        return true
    }

    private fun requestPinWidget(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = AppWidgetManager.getInstance(context)
        if (!manager.isRequestPinAppWidgetSupported) return false
        val provider = ComponentName(context, FinnHomeWidgetProvider::class.java)
        val extras: android.os.Bundle? = null
        val successCallback: PendingIntent? = null
        return manager.requestPinAppWidget(provider, extras, successCallback)
    }

    private fun requestPinShortcut(context: Context, arguments: Any?): Boolean {
        val args = arguments as? Map<*, *> ?: return false
        val shortcutId = args["shortcutId"] as? String
        val creationId = args["creationId"] as? String
        val label = args["label"] as? String ?: "Finn AI"
        if (shortcutId.isNullOrBlank() || creationId.isNullOrBlank()) return false

        val manager = context.getSystemService(ShortcutManager::class.java) ?: return false
        if (!manager.isRequestPinShortcutSupported) return false

        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            putExtra(EXTRA_CREATION_ID, creationId)
        }
        val shortcut = ShortcutInfo.Builder(context, shortcutId)
            .setShortLabel(label)
            .setLongLabel(label)
            .setIcon(Icon.createWithResource(context, R.mipmap.ic_launcher))
            .setIntent(intent)
            .build()
        val callback = PendingIntent.getBroadcast(
            context,
            shortcutId.hashCode(),
            Intent(context, FinnHomeWidgetProvider::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return manager.requestPinShortcut(shortcut, callback.intentSender)
    }

    private fun shareFile(context: Context, arguments: Any?): Boolean {
        val args = arguments as? Map<*, *> ?: return false
        val path = args["path"] as? String
        val mimeType = args["mimeType"] as? String ?: "application/octet-stream"
        val label = args["label"] as? String
        if (path.isNullOrBlank()) return false

        val file = File(path)
        if (!file.exists()) return false

        return try {
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file,
            )
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                if (!label.isNullOrBlank()) putExtra(Intent.EXTRA_SUBJECT, label)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(send, label).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(chooser)
            true
        } catch (_: Exception) {
            false
        }
    }

    /** Extra a pinned creation shortcut carries into the app. */
    const val EXTRA_CREATION_ID = "finn_creation_id"
}
