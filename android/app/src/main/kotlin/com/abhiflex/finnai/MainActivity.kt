package com.abhiflex.finnai

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.os.StatFs
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
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            val thermalStatus =
                if (Build.VERSION.SDK_INT >= 29) power.currentThermalStatus else null
            val thermalHeadroom =
                if (Build.VERSION.SDK_INT >= 30) {
                    val value = power.getThermalHeadroom(0)
                    if (value.isFinite()) value else null
                } else {
                    null
                }
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
                    "thermalStatus" to thermalStatus,
                    "thermalHeadroom" to thermalHeadroom,
                ),
            )
        }

    }
}
