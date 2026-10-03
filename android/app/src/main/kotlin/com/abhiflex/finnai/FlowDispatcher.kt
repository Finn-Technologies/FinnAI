package com.abhiflex.finnai

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Decides what happens when a flow's trigger fires.
 *
 * * A flow that may not run by itself (it changes the phone and has no standing
 *   grant) only tells the user it is due; tapping runs it with the app open.
 * * Otherwise the run happens where Dart already is: in the app's own engine if
 *   the app is open, else in a short-lived headless engine the listener service
 *   starts. Without the service nothing can keep the process alive for a long
 *   run, so the flow asks to be tapped rather than failing quietly.
 */
object FlowDispatcher {
    private const val TAG = "FINN_FLOW_NATIVE"
    private const val TAPPABLE = "Tap to run"

    fun dispatch(context: Context, spec: FlowTriggerSpec, source: String) {
        val app = context.applicationContext
        Log.i(TAG, "dispatch ${spec.flowId} source=$source auto=${spec.auto}")
        if (!spec.auto) {
            FlowScheduler.notifyDue(app, spec.flowId, spec.name, TAPPABLE)
            return
        }
        val handled = FlowUiBridge.send(spec.flowId, source) {
            Log.i(TAG, "app engine had no listener; running in the background")
            // The app's engine is up but nothing is listening (onboarding, or
            // the shell closed): run it in the background instead.
            runInBackground(app, spec, source)
        }
        Log.i(TAG, if (handled) "sent to the app's engine" else "no app engine")
        if (!handled) runInBackground(app, spec, source)
    }

    fun dispatchEvent(context: Context, kind: String) {
        for (spec in FlowTriggerStore.events(context)) {
            if (spec.kind == kind) dispatch(context, spec, "event:$kind")
        }
    }

    private fun runInBackground(app: Context, spec: FlowTriggerSpec, source: String) {
        if (FlowTriggerService.running) {
            Log.i(TAG, "background run of ${spec.flowId}")
            FlowBackgroundRunner.enqueue(app, spec.flowId, source)
        } else {
            FlowScheduler.notifyDue(app, spec.flowId, spec.name, TAPPABLE)
        }
    }
}

/** The app's own Flutter engine, while the activity has one. */
object FlowUiBridge {
    @Volatile
    var engine: FlutterEngine? = null

    private val main = Handler(Looper.getMainLooper())

    /**
     * Tells the app's Dart side a flow fired. Returns false when there is no
     * engine; [onUnhandled] is called later if the engine has nobody listening.
     */
    fun send(flowId: String, source: String, onUnhandled: () -> Unit): Boolean {
        val current = engine ?: return false
        main.post {
            try {
                MethodChannel(current.dartExecutor.binaryMessenger, FlowChannels.CHANNEL)
                    .invokeMethod(
                        "onFlowTrigger",
                        mapOf("flowId" to flowId, "source" to source),
                        object : MethodChannel.Result {
                            override fun success(result: Any?) {}
                            override fun error(code: String, message: String?, details: Any?) = onUnhandled()
                            override fun notImplemented() = onUnhandled()
                        },
                    )
            } catch (_: Exception) {
                onUnhandled()
            }
        }
        return true
    }
}
