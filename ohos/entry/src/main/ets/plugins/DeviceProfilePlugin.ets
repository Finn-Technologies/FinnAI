/*
 * `finn_ai/device_profile` for OpenHarmony — the HarmonyOS half of the same
 * channel the Kotlin MainActivity answers on Android.
 *
 * Without it `DeviceProfiler.read()` gets an empty native map on OHOS, so:
 *   - availableStorageBytes is null, and the pre-download storage guard cannot
 *     run;
 *   - supportedAbis is empty, and `DeviceProfile.supported` cannot tell a
 *     32-bit device from an arm64 one;
 *   - the SoC string is empty, so the processor is classified from core count
 *     alone and every device looks like "entry".
 *
 * RAM is deliberately not read here: Dart already reads /proc/meminfo on OHOS
 * (`Platform.isLinux` is true), and doing it in one place avoids two answers
 * disagreeing.
 */

import { BinaryMessenger, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { deviceInfo } from '@kit.BasicServicesKit';
import statfs from '@ohos.file.statvfs';

const CHANNEL = 'finn_ai/device_profile';

export class DeviceProfilePlugin {
  static register(messenger: BinaryMessenger): void {
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method !== 'getDeviceProfile') {
          result.notImplemented();
          return;
        }
        try {
          result.success({
            cores: DeviceProfilePlugin.cores(),
            socManufacturer: 'HarmonyOS',
            socModel: `${deviceInfo.productModel} (${deviceInfo.osFullName})`,
            hardware: deviceInfo.deviceType,
            board: '',
            // HarmonyOS exposes a device *performance* class rather than a
            // low-memory flag; the two lowest classes are what Android calls a
            // low-memory device for inference purposes.
            lowMemory: DeviceProfilePlugin.isLowMemory(),
            supportedAbis: deviceInfo.abiList.split(','),
            availableStorageBytes: DeviceProfilePlugin.availableStorageBytes(),
            // Where the packaged .so files live inside the sandbox; llama.cpp
            // is dlopen'ed from here.
            nativeLibraryDir: '/data/storage/el1/bundle/libs/arm64',
          });
        } catch (error) {
          const biz = error as BusinessError;
          result.error('device_profile_failed', `${biz.code}: ${biz.message}`, null);
        }
      },
    });
  }

  private static cores(): number {
    // deviceInfo has no core count; /proc/cpuinfo is the only source, and Dart
    // already reads Platform.numberOfProcessors as its own fallback, so report
    // nothing here rather than an invented number.
    return 0;
  }

  /** HarmonyOS exposes low-memory devices through the OS-level memory hint. */
  private static isLowMemory(): boolean {
    const level = deviceInfo.performanceClass;
    return level === deviceInfo.PerformanceClassLevel.CLASS_LEVEL_LOW;
  }

  /**
   * Bytes free on the volume holding the app sandbox. `statfs` is the only
   * HarmonyOS API that answers this; `fs.stat` cannot (it reports inode size).
   * Returns null when the sandbox mount does not support statfs, which
   * disables the pre-download storage guard rather than guessing.
   */
  private static availableStorageBytes(): number | null {
    try {
      const free = statfs.getFreeSizeSync('/data/storage/el2');
      return free >= 0 ? free : null;
    } catch (_) {
      return null;
    }
  }
}