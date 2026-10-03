package com.abhiflex.finnai

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Runs a flow with no screen: a second Flutter engine, started when a flow
 * fires while the app is closed and thrown away shortly after.
 *
 * The engine runs `flowBackgroundMain` (lib/flow_background.dart), which loads
 * the flows and runs the one named, with the same runner the app uses. Runs are
 * queued and executed one at a time: the language model, if a flow asks for
 * it, must not be loaded twice. Only [FlowTriggerService] may start this, so
 * the process is a foreground one while a long run is in progress.
 */
object FlowBackgroundRunner {
    private const val BACKGROUND_CHANNEL = "finn_ai/flow_background"
    private const val ENTRYPOINT_LIBRARY = "package:finn_ai/flow_background.dart"
    private const val ENTRYPOINT = "flowBackgroundMain"

    /** How long the engine stays up with nothing to do, in case another flow follows. */
    private const val IDLE_MS = 45_000L

    /** A run that has not answered by now is given up on. */
    private const val RUN_TIMEOUT_MS = 5 * 60_000L

    private val main = Handler(Looper.getMainLooper())
    private val queue = ArrayDeque<Pair<String, String>>()
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    private var busy = false
    private var waitingForReady = false

    private val idle = Runnable { shutdown() }

    fun enqueue(context: Context, flowId: String, source: String) {
        val app = context.applicationContext
        main.post {
            queue.addLast(flowId to source)
            main.removeCallbacks(idle)
            pump(app)
        }
    }

    private fun pump(app: Context) {
        if (busy) return
        val next = queue.removeFirstOrNull()
        if (next == null) {
            main.postDelayed(idle, IDLE_MS)
            return
        }
        busy = true
        val current = ensureEngine(app)
        if (!ready) {
            // The engine is still starting; run when Dart says it is ready.
            queue.addFirst(next)
            busy = false
            waitingForReady = true
            return
        }
        var finished = false
        val timeout = Runnable {
            if (finished) return@Runnable
            finished = true
            busy = false
            shutdown()
        }
        main.postDelayed(timeout, RUN_TIMEOUT_MS)
        fun done() {
            if (finished) return
            finished = true
            main.removeCallbacks(timeout)
            busy = false
            pump(app)
        }
        current.invokeMethod(
            "run",
            mapOf("flowId" to next.first, "source" to next.second),
            object : MethodChannel.Result {
                override fun success(result: Any?) = done()
                override fun error(code: String, message: String?, details: Any?) = done()
                override fun notImplemented() = done()
            },
        )
    }

    private fun ensureEngine(app: Context): MethodChannel {
        channel?.let { return it }
        // The constructor registers every plugin; registering them again would
        // only log a warning per plugin.
        val created = FlutterEngine(app)
        FinnDeviceActionsBridge.register(created, app)
        FlowEnvironmentBridge.register(created, app)
        FlowChannels.register(created, app)
        val bridge = MethodChannel(created.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL)
        bridge.setMethodCallHandler { call, result ->
            if (call.method == "ready") {
                ready = true
                result.success(null)
                if (waitingForReady) {
                    waitingForReady = false
                    main.post { pump(app) }
                }
            } else {
                result.notImplemented()
            }
        }
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationComplete(app, null)
        created.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT_LIBRARY, ENTRYPOINT),
        )
        engine = created
        channel = bridge
        return bridge
    }

    private fun shutdown() {
        main.removeCallbacks(idle)
        channel?.setMethodCallHandler(null)
        engine?.destroy()
        engine = null
        channel = null
        ready = false
        busy = false
        waitingForReady = false
    }
}
