import 'dart:io';

/// The OS families FinnAI ships for, as a single source of truth.
///
/// `dart:io` reports OpenHarmony as none of Android/iOS/macOS/Windows, so every
/// `Platform.isX` check falls through and the app silently degrades to
/// "unsupported". This enum plus [finnPlatform] is what every platform branch
/// in the app should ask instead, so a HarmonyOS build stops guessing.
///
/// Note for engine code: `engine/` must not import this file
/// (`tool/verify_boundaries.sh`), so engine files branch on
/// `Platform.operatingSystem` or receive the answer through `engine/api/`.
enum FinnPlatform { android, ios, macos, linux, windows, openHarmony }

bool? _detectedOpenHarmony;
FinnPlatform? _override;

/// True when the app is running on HarmonyOS / OpenHarmony.
///
/// Detection order matters. `dart:io` on the OHOS Flutter fork reports
/// `operatingSystem == 'linux'` and `Platform.isLinux == true`, so probing
/// `Platform.isLinux` first would classify OHOS as desktop Linux. OpenHarmony
/// is instead fingerprinted by the per-app sandbox mount points, which only
/// exist inside an app process on an OHOS device.
bool get isOpenHarmony {
  final override = _override;
  if (override != null) return override == FinnPlatform.openHarmony;
  final cached = _detectedOpenHarmony;
  if (cached != null) return cached;
  final detected = _detectOpenHarmony();
  _detectedOpenHarmony = detected;
  return detected;
}

/// Which platform this build is running on.
FinnPlatform get finnPlatform {
  final override = _override;
  if (override != null) return override;
  if (isOpenHarmony) return FinnPlatform.openHarmony;
  if (Platform.isAndroid) return FinnPlatform.android;
  if (Platform.isIOS) return FinnPlatform.ios;
  if (Platform.isMacOS) return FinnPlatform.macos;
  if (Platform.isWindows) return FinnPlatform.windows;
  return FinnPlatform.linux;
}

/// True on the two platforms that get the full mobile feature set (voice,
/// device actions, launcher widgets).
bool get isMobile =>
    finnPlatform == FinnPlatform.android || finnPlatform == FinnPlatform.ios;

/// True on a desktop OS, where there is a keyboard and a pointer and the
/// window is resizable.
bool get isDesktop =>
    finnPlatform == FinnPlatform.linux ||
    finnPlatform == FinnPlatform.macos ||
    finnPlatform == FinnPlatform.windows;

/// HarmonyOS's documented directory layout for an `entry` module in the `el2`
/// sandbox, used when the `path_provider` channel cannot be reached.
///
/// These are the same values `OpenHarmonyPathProvider` falls back to, kept here
/// so the OHOS seam has one place that knows where the sandbox is. Anything that
/// needs a real sandbox directory in Dart should prefer
/// `PathProviderPlatform.instance` and use these only as a last resort.
const String ohosSandboxFilesDir = '/data/storage/el2/base/haps/entry/files';
const String ohosSandboxCacheDir = '/data/storage/el2/base/haps/entry/cache';

bool _detectOpenHarmony() {
  try {
    // el2 is the writable per-application sandbox root and el1 the read-only
    // bundle mount; either is conclusive, and neither exists off-device.
    if (Directory('/data/storage/el2').existsSync() ||
        Directory('/data/storage/el1').existsSync() ||
        Directory('/data/app/el2').existsSync()) {
      return true;
    }
  } catch (_) {
    // Some sandboxes deny stat() on the mount points; fall through.
  }
  // Fallback for hosts where the sandbox is not mounted but the platform string
  // still says OpenHarmony.
  const ohosNames = {'ohos', 'harmonyos', 'openharmony'};
  return ohosNames.contains(Platform.operatingSystem);
}

/// Test hook. Pass `null` to return to real detection.
void debugSetFinnPlatformOverride(FinnPlatform? platform) {
  _override = platform;
  _detectedOpenHarmony = null;
}
