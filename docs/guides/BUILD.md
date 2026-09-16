# Building FinnAI

## Prerequisites

| Tool | Version used by CI | Notes |
|---|---|---|
| Flutter | `3.47.2` (stable) | pinned in `.github/workflows/ci.yml` |
| Dart | bundled with Flutter | `>=3.6.0` per `pubspec.yaml` |
| JDK | 17 | Android Gradle build |
| Android SDK | platform 34–36, build-tools 35, NDK/CMake | installed on demand by Gradle |

The repo also targets OpenHarmony; see [OHOS_BUILD.md](OHOS_BUILD.md) for that toolchain.

## Standard commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## Known issue: "No Hmos SDK found"

This checkout is sometimes built with the **OpenHarmony Flutter fork**, which runs an OHOS tooling
regeneration step for every command that would run `pub get`. If `HOS_SDK_HOME` is unset, the
command aborts with:

```text
[!] No Hmos SDK found. Try setting the HOS_SDK_HOME environment variable.
```

Workarounds, in order of preference:

```bash
dart analyze .              # analyzer without the Flutter tool wrapper
flutter test --no-pub       # skips the regeneration step
flutter build apk --no-pub  # same, for builds
```

`--no-pub` is safe as long as `flutter pub get` has already been run and no `.arb` file changed.

## Known issue: "built with the incorrect architecture"

If the SDK cache contains x86_64 host tools (for example `impellerc`, `flutter_tester`,
`gen_snapshot` under `bin/cache/artifacts/engine/darwin-x64/`) on an Apple-silicon Mac without
Rosetta, every build fails with:

```text
The binary was built with the incorrect architecture to run on this machine.
```

Fix by installing the matching arm64 host artifacts for the engine revision in
`bin/cache/engine.version`, or install Rosetta (`sudo softwareupdate --install-rosetta`).

## Device build & install

```bash
flutter build apk --debug
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.abhiflex.finnai/.MainActivity
adb logcat -s flutter
```

The debug APK is large (≈86 MB) because it bundles the native inference runtime plus debug
symbols; the release APK is far smaller.

## Native runtime

`third_party/llama_cpp_dart/` is vendored and excluded from analysis. It is patched through
`tool/llama_android_build.patch` / `tool/llama_android_native.patch` and rebuilt with
`tool/rebuild_llama_android_aar.sh` — do not hand-edit the vendored sources.

## Prebuilt signing configuration

Release builds read `android/key.properties` (`storePassword`, `keyPassword`, `keyAlias`,
`storeFile`). Without it, `tool/verify_release.sh` fails its signing gate.
