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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "finn_ai/model_download",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val args = call.arguments as? Map<*, *> ?: run { result.error("args", "Missing download arguments", null); return@setMethodCallHandler }
                    val requestedTarget = args["target"] as? String ?: run { result.error("args", "Missing download target", null); return@setMethodCallHandler }
                    val current = ModelDownloadService.status(this)
                    if (current["active"] == true && current["target"] == requestedTarget) {
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
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(null)
                }
                "status" -> result.success(ModelDownloadService.status(this))
                else -> result.notImplemented()
            }
        }

    }
}
