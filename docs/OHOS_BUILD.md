# OpenHarmony (OHOS) build guide

This documents how to build and sign the OpenHarmony/HarmonyOS port of Finn AI,
and what that port does and does not support today.

The OHOS platform lives under `ohos/` and is built with the **Flutter OpenHarmony
fork**, not with stock Flutter. Stock `flutter`/`flutter analyze`/`flutter test`
on a desktop host never touch the `ohos/` directory; the OHOS target is an
additional platform alongside Android, not a replacement.

## Prerequisites

1. **Flutter OHOS fork toolchain** — clone
   [openharmony-sig/flutter_flutter](https://gitee.com/openharmony-sig/flutter_flutter)
   (use the branch matching the engine this port was built against; the
   `ohos/entry/oh-package-lock.json5` records the framework HAR version, e.g.
   `1.0.0-6591f6a305`) and put its `bin/` on your `PATH` **instead of** stock
   Flutter. Verify with `flutter doctor -v`: both the Flutter and OpenHarmony
   checks must report ok.
2. **DevEco Studio 5.0+** (or `command-line-tools-5.0`) with the OpenHarmony SDK
   (API 12 or newer; this project declares `compatibleSdkVersion 5.0.0(12)` and
   `compileSdkVersion 6.1.1(24)` in `ohos/build-profile.json5`).
3. **JDK 17** and the DevEco command-line tools on your `PATH`
   (macOS example, adjust `TOOL_HOME` to your install location):

   ```bash
   export JAVA_HOME=<JAVA_HOME>/Contents/Home
   export TOOL_HOME=/Applications/DevEco-Studio.app/Contents
   export DEVECO_SDK_HOME=$TOOL_HOME/sdk
   export PATH=$TOOL_HOME/tools/ohpm/bin:$PATH
   export PATH=$TOOL_HOME/tools/hvigor/bin:$PATH
   export PATH=$TOOL_HOME/tools/node/bin:$PATH
   ```

   (These are the environment steps from the fork's README; they were not
   re-verified in the CI environment used to author this document, which has no
   OHOS toolchain.)

## Building from a clean clone

`ohos/har/flutter.har` — the Flutter framework HAR that the `entry` module
depends on — is **gitignored** (`ohos/.gitignore` ignores `*.har`), so a fresh
clone cannot run an hvigor build until it is regenerated:

1. `flutter pub get` (with the fork's `flutter` on `PATH`).
2. `flutter build hap --debug` (or `flutter run`).

The fork's tooling materializes the generated OHOS project artifacts — including
`ohos/har/flutter.har`, copied from the fork's engine cache — during the
`build hap` flow. Resolution is wired as:
`ohos/entry/oh-package.json5` declares `"@ohos/flutter_ohos": "har/flutter.har"`,
and `ohos/entry/oh-package-lock.json5` pins that local HAR
(`registryType: "local"`). Once the HAR exists, `ohpm install` / hvigor sync
inside `ohos/` resolves it.

> **Not verified in this environment:** this repository's maintainers have no
> OHOS toolchain available where this doc was written, so the exact
> har-regeneration trigger could not be executed here. If `flutter build hap`
> reports `har/flutter.har` missing, re-running `flutter pub get` followed by
> `flutter build hap` with a properly provisioned fork (or re-adding the ohos
> platform via the fork's `flutter create --platforms ohos` template flow) is
> the documented recovery path. Do **not** hand-craft the HAR.

Debug output lands in `ohos/entry/build/default/outputs/default/` (gitignored).
Install with `hdc -t <deviceId> install <hap>` or let `flutter run` do it.

## Signing

- **Nothing signing-related is committed.** `ohos/build-profile.json5` keeps
  `signingConfigs` empty on purpose and the `default` product deliberately does
  **not** reference a signing config, so a clean checkout configures and builds
  an **unsigned** debug HAP without errors.
- Release signing materials (`.p12` key store, `.cer` certificate, provision
  profile) are **provisioned out-of-band** and must never be committed. To sign
  a release locally, add a signing config via DevEco Studio
  (File > Project Structure > Signing Configs) or edit
  `ohos/build-profile.json5` locally, then run `flutter build hap --release`.
  Keep those edits local; `*.hap`/`*.har` and signing material are gitignored.

## Current limitations of the OHOS port

The OHOS target is a functional subset of the Android app:

- **No Flutter plugins are implemented.** `ohos/entry/src/main/ets/plugins/`
  contains only the generated (and empty) `GeneratedPluginRegistrant.ets`, i.e.
  `flutter_secure_storage`, `image_picker`, `file_picker`, `url_launcher`, and
  `package_info_plus` are **unregistered** on OHOS and the features that need
  them degrade or are unavailable. `path_provider` is the one plugin that
  works, via an inline handler in `EntryAbility.ets` answering the
  `plugins.flutter.io/path_provider` channel (mirrored on the Dart side by
  `lib/src/openharmony/openharmony_path_provider.dart`).
- **Single generic CPU inference backend.** `ohos/entry/libs/arm64-v8a/` ships
  the generic llama.cpp `.so` set (`libllama.so`, `libggml.so`,
  `libggml-base.so`, `libggml-cpu.so`, `libmtmd.so`), built from the pinned
  `llama_cpp_dart`/`llama.cpp` commits (`tool/rebuild_llama_android_aar.sh`
  pins: package `1a8c7563`, llama.cpp `d6d0ce82`) with this repo's
  OpenHarmony SDK (`native/build/cmake/ohos.toolchain.cmake`,
  `OHOS_STL=c++_static`, plain unversioned `SONAME`s). Rebuilding with a
  newer sysroot than the target OS (e.g. one referencing
  `__register_atfork`, `@since` newer than the device) breaks `dlopen` at
  startup, so the libs must be rebuilt — not just copied — when the SDK
  moves. There is no GPU or CPU-variant backend
  dispatch as on Android, so performance/adaptive-backend features
  (see `docs/ENGINE_ROADMAP.md`) have no OHOS equivalent yet.
- **No background downloads.** `ohos.permission.KEEP_BACKGROUND_RUNNING` was
  removed from `ohos/entry/src/main/module.json5` because no continuous-task
  (`backgroundTaskManager`) code exists — declaring the permission without a
  continuous task granted nothing. Consequence: model downloads are suspended
  by the system when the app is backgrounded; keep the app foregrounded for
  long transfers. Wiring a continuous task is the future enhancement that
  would justify re-adding the permission.

## Versioning

`ohos/AppScope/app.json5` (`versionCode` / `versionName`) must be bumped **in
lockstep with `pubspec.yaml`** (`version: 1.0.4+7` → code `7`, name `1.0.4`)
on every release. The Android `versionCode`/`versionName` come from pubspec
via the Flutter Gradle plugin; the OHOS manifest has no such bridge, so the
bump is manual. Keep `versionCode` monotonically increasing across both
platforms.
