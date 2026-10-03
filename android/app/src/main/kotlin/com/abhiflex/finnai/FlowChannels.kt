package com.abhiflex.finnai

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `finn_ai/flow_schedule`: what Dart can ask of the platform about Flows.
 *
 * Registered by the app's own engine and by the headless engine a background
 * run uses, so a flow can post its notification the same way in both. Asking
 * for the notification permission needs an activity, so only the app's engine
 * supplies [requestNotifications].
 */
object FlowChannels {
    const val CHANNEL = "finn_ai/flow_schedule"

    fun register(
        engine: FlutterEngine,
        context: Context,
        requestNotifications: ((MethodChannel.Result) -> Unit)? = null,
        takePendingFlow: (() -> String?)? = null,
    ) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "notificationsAllowed" -> result.success(FlowScheduler.notificationsAllowed(context))
                    "requestNotifications" -> {
                        if (FlowScheduler.notificationsAllowed(context)) result.success(true)
                        else if (requestNotifications == null) result.success(false)
                        else requestNotifications(result)
                    }
                    "sync" -> {
                        val args = call.arguments as? Map<*, *>
                        fun specs(key: String) = (args?.get(key) as? List<*>)
                            ?.mapNotNull { (it as? Map<*, *>)?.let(FlowTriggerSpec::fromMap) }
                            ?: emptyList()
                        FlowScheduler.sync(context, specs("alarms"), specs("events"))
                        result.success(null)
                    }
                    "cancelAll" -> {
                        FlowScheduler.cancelAll(context)
                        result.success(null)
                    }
                    "notify" -> {
                        val args = call.arguments as? Map<*, *>
                        FlowScheduler.notifyDue(
                            context,
                            (args?.get("flowId") as? String) ?: "flow",
                            (args?.get("title") as? String) ?: "Flow",
                            (args?.get("body") as? String) ?: "",
                        )
                        result.success(null)
                    }
                    "takePendingFlow" -> result.success(takePendingFlow?.invoke())
                    else -> result.notImplemented()
                }
            }
    }
}
