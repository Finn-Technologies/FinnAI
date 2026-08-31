package com.abhiflex.finnai

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager
import android.os.StatFs
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    @Suppress("DEPRECATION")
    override fun getFlutterShellArgs(): FlutterShellArgs {
        val args = super.getFlutterShellArgs()
        val memory = ActivityManager.MemoryInfo()
        (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(memory)
        // Devices in the 7-8 GB RAM class (e.g. the Xiaomi 12T used in
        // on-device benchmarks) pair a midrange Adreno with a Vulkan driver
        // that hangs Impeller's cold-cache shader compilation and silently
        // fails llama.cpp compute shaders. Falling back to the GLES renderer
        // avoids both failure modes; the app is UI-light so the older path
        // is not a perceptible regression.
        val prefersCompatibilityRenderer =
            Build.VERSION.SDK_INT <= Build.VERSION_CODES.S_V2 ||
                memory.totalMem < 7_000_000_000L
        if (prefersCompatibilityRenderer) {
            args.remove(FlutterShellArgs.ARG_ENABLE_IMPELLER)
            args.add(FlutterShellArgs.ARG_DISABLE_IMPELLER)
        }
        return args
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "finn_ai/device_profile",
        ).setMethodCallHandler { call, result ->
            if (call.method != "getDeviceProfile") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memory = ActivityManager.MemoryInfo()
            manager.getMemoryInfo(memory)
            val totalMemory = if (Build.VERSION.SDK_INT >= 34 && memory.advertisedMem > 0) {
                memory.advertisedMem
            } else {
                memory.totalMem
            }
            val storage = StatFs(filesDir.absolutePath)
            result.success(
                mapOf(
                    "totalRamBytes" to totalMemory,
                    "availableRamBytes" to memory.availMem,
                    "availableStorageBytes" to storage.availableBytes,
                    "lowMemory" to memory.lowMemory,
                    "socManufacturer" to if (Build.VERSION.SDK_INT >= 31) Build.SOC_MANUFACTURER else "",
                    "socModel" to if (Build.VERSION.SDK_INT >= 31) Build.SOC_MODEL else "",
                    "hardware" to Build.HARDWARE,
                    "board" to Build.BOARD,
                    "cores" to Runtime.getRuntime().availableProcessors(),
                    "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
                    "sdk" to Build.VERSION.SDK_INT,
                    // llama.cpp's dynamic CPU backends must be discovered
                    // from the extracted APK native-library directory.
                    "nativeLibraryDir" to applicationInfo.nativeLibraryDir,
                ),
            )
        }

        // Compile-time benchmark harness overrides (FINN_BENCHMARK builds
        // only). Lets one benchmark APK run every scenario/config sweep via
        // `adb shell am start --es/-ei` extras instead of one rebuild per
        // scenario. Production builds never call this channel.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "finn_ai/benchmark",
        ).setMethodCallHandler { call, result ->
            if (call.method != "getOverrides") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val intent = intent ?: run { result.success(mapOf<String, Any?>()); return@setMethodCallHandler }
            fun stringExtra(name: String): String? = intent.getStringExtra(name)?.takeIf { it.isNotEmpty() }
            // Safe for both `--es NAME true` and `--ez NAME true` invocations;
            // getBooleanExtra / getStringExtra throw ClassCastException when
            // the extra was passed with the other type.
            fun boolExtra(name: String): Boolean =
                when (val v = intent.extras?.get(name)) {
                    is String -> v.isNotEmpty()
                    is Boolean -> v
                    else -> false
                }
            val intExtra = intent.getIntExtra("FINN_BENCH_RUNS", -1)
            result.success(
                mapOf(
                    "scenario" to stringExtra("FINN_BENCH_SCENARIO"),
                    "runs" to (if (intExtra > 0) intExtra else null),
                    "prompt" to stringExtra("FINN_BENCH_PROMPT"),
                    "prewarm" to stringExtra("FINN_BENCH_PREWARM"),
                    "noSearch" to boolExtra("FINN_BENCH_NO_SEARCH"),
                    "noPrefixCache" to boolExtra("FINN_BENCH_NO_PREFIX"),
                    "threads" to (if (intent.hasExtra("FINN_BENCH_THREADS")) intent.getIntExtra("FINN_BENCH_THREADS", -1).takeIf { it > 0 } else null),
                    "batchThreads" to (if (intent.hasExtra("FINN_BENCH_BATCH_THREADS")) intent.getIntExtra("FINN_BENCH_BATCH_THREADS", -1).takeIf { it > 0 } else null),
                    "batch" to (if (intent.hasExtra("FINN_BENCH_BATCH")) intent.getIntExtra("FINN_BENCH_BATCH", -1).takeIf { it > 0 } else null),
                    "ubatch" to (if (intent.hasExtra("FINN_BENCH_UBATCH")) intent.getIntExtra("FINN_BENCH_UBATCH", -1).takeIf { it > 0 } else null),
                    "nrs" to (if (intent.hasExtra("FINN_BENCH_NRS")) intent.getIntExtra("FINN_BENCH_NRS", -1).takeIf { it >= 0 } else null),
                    "noSha" to boolExtra("FINN_BENCH_NO_SHA"),
                    "cpu" to boolExtra("FINN_BENCH_CPU"),
                    "f16Kv" to boolExtra("FINN_BENCH_F16_KV"),
                    "flashOff" to boolExtra("FINN_BENCH_FLASH_OFF"),
                ),
            )
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "finn_ai/model_download",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val args = call.arguments as? Map<*, *> ?: run { result.error("args", "Missing download arguments", null); return@setMethodCallHandler }
                    val requestedTarget = args["target"] as? String ?: run { result.error("args", "Missing download target", null); return@setMethodCallHandler }
                    val current = ModelDownloadService.status(this)
                    val alreadyRunning = ModelDownloadService.isRunning.get()
                    if (alreadyRunning && current["target"] == requestedTarget) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val serviceIntent = Intent(this, ModelDownloadService::class.java).apply {
                        action = ModelDownloadService.ACTION_START
                        putExtra(ModelDownloadService.EXTRA_URL, args["url"] as? String)
                        putExtra(ModelDownloadService.EXTRA_TARGET, requestedTarget)
                        putExtra(ModelDownloadService.EXTRA_EXPECTED_BYTES, (args["expectedBytes"] as? Number)?.toLong() ?: 0L)
                        putExtra(ModelDownloadService.EXTRA_LABEL, args["label"] as? String)
                    }
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4102)
                    }
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("service_start_failed", e.message, null)
                    }
                }
                "status" -> result.success(ModelDownloadService.status(this))
                "cancel" -> {
                    val args = call.arguments as? Map<*, *>
                    val target = args?.get("target") as? String
                    if (target.isNullOrBlank()) {
                        result.error("args", "Missing download target", null)
                    } else {
                        ModelDownloadService.cancel(this, target)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

    }
}
