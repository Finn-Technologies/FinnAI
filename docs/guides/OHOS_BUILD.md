# OpenHarmony (HarmonyOS) build & port guide

This documents how to build, install and run FinnAI on HarmonyOS, what the port
does today, and what it deliberately does not do. It is the OHOS counterpart of
`BUILD.md`.

The OHOS platform lives under `ohos/` and is built with the **Flutter OpenHarmony
fork**, not with stock Flutter. Stock `flutter analyze`/`flutter test` on a
desktop host never touch the `ohos/` directory; OHOS is an additional target
alongside Android and iOS.

**Target: HarmonyOS 6.1.1 (API 24)** — the newest Release SDK the public
HarmonyOS Command Line Tools ship, and the newest image the Emulator offers.
HarmonyOS 7 (API 26) is developer-beta and gated behind a Huawei developer
account, so it is not a build target here.

---

## 1. Prerequisites

1. **Flutter OHOS fork toolchain** on `PATH`, *instead of* stock Flutter.
   Verify with `flutter doctor -v`: the HarmonyOS check must report ok and list
   `24:default` under `available api versions`.
2. **HarmonyOS Command Line Tools 6.1.1** (hvigor 6.24.2, ohpm 6.1.2,
   SDK 6.1.1.125 / API 24), unpacked at `~/Developer/command-line-tools`.
3. **JDK 17** and **cmake + ninja** (for the native rebuild below).
4. `~/.npmrc` containing `@ohos:registry=https://repo.harmonyos.com/npm/`.

`tool/ohos_env.sh` exports all of the variables hvigor, ohpm and the fork need.
Source it once per shell:

```bash
source tool/ohos_env.sh
```

It sets `DEVECO_SDK_HOME`, `JAVA_HOME`, and puts `bin`, the bundled Node and the
SDK's `hdc` on `PATH`.

---

## 2. One-time toolchain steps

### 2.1 Patch the engine HAR for API 24

```bash
bash tool/patch_ohos_engine_har.sh           # applies
bash tool/patch_ohos_engine_har.sh --check   # verifies, non-zero if unpatched
```

The Flutter OHOS fork's engine HAR ships ArkTS that annotates `autoFillManager`
types that only exist from API 26 (`FillRequest`, `AutoFillCallback`, `ViewData`,
`FillFailureResult`, `SaveRequest`, `AutoFillType`, `AutoFillTriggerType`,
`requestAutoFill`). ArkTS resolves type annotations at compile time, so
`hvigorw assembleHap` reports 14 errors in
`src/main/ets/plugin/editing/OhosAutoFillHelper.ets` and **no** app built with
this fork can be packaged against API 24.

The patch (`tool/ohos_engine_har_api24.patch`) changes compile-time typing only —
local aliases for the API-26 names, and an `ESObject` view of the namespace for
the two API-26-only calls. Both of that file's entry points already return early
below `AUTOFILL_SUPPORT_API` (26), so no behaviour changes on any API level.

If `flutter precache --ohos` (or a cache wipe) replaces the HAR, re-run the
script. Delete it once the fork targets an API 26 SDK.

### 2.2 Rebuild the llama.cpp shared libraries

```bash
bash tool/rebuild_llama_ohos.sh
```

`ohos/entry/libs/arm64-v8a/*.so` **must** be compiled against the *HarmonyOS*
NDK sysroot. HarmonyOS's musl does not export `__register_atfork`; llama.cpp
built against a newer OpenHarmony sysroot references it and then fails to load:

```
LlamaLibraryException: failed to open libllama.so: ... Error relocating
/data/storage/el1/bundle/libs/arm64/libllama.so: __register_atfork: symbol not found
```

When the SDK moves, these libraries must be **rebuilt**, never re-copied. The
script refuses to build if the sysroot it found does export `__register_atfork`,
so this cannot regress silently, and it verifies every SONAME afterwards
(`libllama.so`, not `libllama.so.0`) because the sandbox `dlopen`s by bare
filename.

Output: `libggml-base.so`, `libggml-cpu.so`, `libggml.so`, `libllama.so`,
`libmtmd.so`, built with `OHOS_STL=c++_static` so no `libc++_shared.so` has to
be packaged.

---

## 3. Emulator

HarmonyOS emulator images are geo-gated to the Chinese mainland since DevEco
6.1.0 Beta1. No proxy is needed — a `zh_CN` locale and timezone are enough:

```bash
export LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 TZ=Asia/Shanghai
Emulator -license accept
Emulator -imageList -deviceType Phone                    # works globally
Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force
# ~2.4 GB ARM64 image -> ~/Library/Huawei/Sdk/system-image/HarmonyOS-6.1.1/phone_all_arm/
Emulator -create FinnPhone -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"
# CLI-tools layout fix so the Emulator UI finds hdc (it looks in ~/Developer/sdk):
ln -s ~/Developer/command-line-tools/sdk ~/Developer/sdk
Emulator -start FinnPhone
```

`hdc list targets` then shows the emulator on `127.0.0.1:5555` (the port moves;
`tool/run_ohos.sh` and `tool/ohos_dev.sh` accept `--serial`).

---

## 4. Build, install, run

```bash
source tool/ohos_env.sh
bash tool/run_ohos.sh              # flutter build hap --debug + hdc install + aa start
bash tool/run_ohos.sh --no-build   # reinstall without rebuilding
bash tool/run_ohos.sh --clean      # uninstall first (wipes the downloaded model)
```

Debug output: `ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`.
It is unsigned on purpose; the emulator installs it as-is. Release signing is
provisioned out-of-band and never committed.

`ohos/entry/har/flutter.har` is written by the fork during `build hap` and is
gitignored. `ohos/oh-package.json5` carries an `overrides` block pointing
`@ohos/flutter_ohos` at it — see the comment in that file for why the override
has to be committed.

---

## 5. Driving the app

```bash
bash tool/ohos_dev.sh shot out.jpeg     # screenshot
bash tool/ohos_dev.sh tap 660 1400      # tap
bash tool/ohos_dev.sh text 'hello'     # type into the focused field
bash tool/ohos_dev.sh key back
bash tool/ohos_dev.sh logs 200         # hilog
bash tool/ohos_dev.sh logs-finn 200    # hilog, FINN_* only
bash tool/ohos_dev.sh restart
```

Flutter renders into a single surface, so `uitest dumpLayout` cannot see the
widget tree — verify UI with screenshots and behaviour with `FINN_*` hilog lines.

---

## 6. What the port does today

### Native plugin layer

`GeneratedPluginRegistrant.ets` is empty: none of the Flutter plugins FinnAI
depends on ship an OHOS implementation, so each one falls back to its default
method-channel implementation. `ohos/entry/src/main/ets/plugins/` answers those
**same** channels in ArkTS, so no Dart-side fork of any plugin is needed. One file
per channel, wired from `FinnPlugins.ets`:

| Channel | File | Covers |
|---|---|---|
| `plugins.flutter.io/path_provider` | `PathProviderPlugin.ets` | all directory getters |
| `plugins.flutter.io/url_launcher` | `UrlLauncherPlugin.ets` | `canLaunch`, `launch` |
| `dev.fluttercommunity.plus/package_info` | `PackageInfoPlugin.ets` | `getAll` |
| `plugins.flutter.io/image_picker` | `ImagePickerPlugin.ets` | `pickImage` (gallery) |
| `miguelruivo.flutter.plugins.filepicker` | `FilePickerPlugin.ets` | `custom`, `any`, `image` |
| `flutter_tts` | `TtsPlugin.ets` | `speak`/`stop` + the `speak.on*` callbacks |
| `com.llfbandit.record/*` | `AudioRecordPlugin.ets` | PCM16 stream for on-device STT |
| `finn_ai/secure_key` | `SecureKeyPlugin.ets` | conversation master key |
| `finn_ai/device_profile` | `DeviceProfilePlugin.ets` | RAM/ABI/SoC/free storage |
| `finn_ai/device_actions` | `DeviceActionsPlugin.ets` | the device-action catalog |
| `finn_ai/flow_schedule`, `finn_ai/flow_env` | `FlowPlugin.ets` | flow triggers, conditions, notifications |
| `finn_ai/share_file` | `SharePlugin.ets` | data export / share |

### Dart side

`lib/src/platform/` is the OHOS seam:

- `platform_target.dart` — `finnPlatform` / `isOpenHarmony`. **Important:**
  `dart:io` reports `operatingSystem == 'linux'` and `Platform.isLinux == true`
  on HarmonyOS, so anything that branches on `Platform.isLinux` first (or on
  `Platform.isX` at all) silently classifies the app as desktop Linux. OHOS is
  fingerprinted by its per-app sandbox mount points instead.
- `openharmony_path_provider.dart` — path_provider, with hard-coded sandbox
  fallbacks if the native side is missing.
- `openharmony_key_storage.dart` — the conversation master key.

### Platform behaviour notes

- **`dart:io` says "linux".** `Platform.isLinux` is `true` and
  `Platform.operatingSystem == 'linux'` on HarmonyOS. Anything branching on
  `Platform.isX` silently classifies the app as desktop Linux; use
  `lib/src/platform/platform_target.dart` instead. The engine's own
  `Platform.isLinux`-keyed paths (`/proc/meminfo`, the device-profile channel)
  do work on HarmonyOS, so they are left keyed that way deliberately.
- **Conversation encryption.** Android keeps the master key in the
  AndroidKeyStore. HarmonyOS's HUKS cannot: it exposes key *management* only
  (no `huks.encrypt`), `cryptoFramework`'s symmetric generator produces only
  ephemeral keys, and `importKeyItem`/`exportKeyItem` take asymmetric keys only.
  The key is therefore sealed by the per-app, per-user sandbox. See
  `docs/architecture/SECURITY_AND_PRIVACY_ARCHITECTURE.md`.
- **Launcher widgets** (`HomeScreenService`) stay Android-only: HarmonyOS has no
  `AppWidget` API FinnAI can drive from the app.
- **Data export** uses `DocumentViewPicker.save()`: HarmonyOS has no cross-app
  share intent, so the user picks the destination.
- **Error reporting.** `progress.dart`'s error mapper used to match the string
  "storage" anywhere in an exception, which turned a `libllama.so` load failure
  (whose message contains the `/data/storage/el1/...` sandbox path) into "Not
  enough free storage to download this model." It now matches library-load
  failures first, and only matches real exhaustion phrases.

---

## 7. Known limitations

- **Some `finn_ai/*` channels lose their reply (open engine bug).** With
  Flutter OHOS fork `3.41.10-ohos-1.0.1` (engine `9161402dc0e1`), a platform
  message is sometimes delivered to the registered handler **twice under the
  same response id**. The handler runs — its side effects land, which is how this
  was found: `finn_ai/secure_key`'s `write` creates the key file — but Dart
  receives an empty reply and raises `MissingPluginException`. The engine's own
  `FlutterNapi --> called handlePlatformMessage Channel: … Response ID: 33`
  line appears twice for one message, and the reply for that id is consumed by
  the first delivery.

  Observed channels: `finn_ai/secure_key`, `finn_ai/flow_schedule`.
  Unaffected: `plugins.flutter.io/path_provider`,
  `dev.fluttercommunity.plus/package_info`.

  Ruled out: the channel name (renaming `finn_ai/secure_key` to a
  plugin-style name changes nothing), a null success envelope (replying `''`
  instead of `null` changes nothing), a startup race (retrying for 2.5 s changes
  nothing), and a missing handler (`Setting handler for channel` is logged, and
  the handler demonstrably runs).

  Mitigation: a bounded retry in `OpenHarmonyKeyStorage._invoke`. **Consequence:
  conversation history cannot be persisted across restarts on HarmonyOS**, and
  the store shows its read-only storage-error banner, because the key read-back
  verification never sees a reply. Chat, inference and every other feature are
  unaffected.

  To finish this, either fix the engine's response-id handling, or move the
  conversation key off a method channel. Verify with:
  `hdc -t <target> shell "hilog -x" | grep handlePlatformMessage`.
- **Flows cannot fire unattended.** Notifications and condition reading work,
  and event triggers are subscribed while the app runs, but a *time* trigger
  needs a `WorkSchedulerExtensionAbility` plus its own headless Dart engine — the
  OpenHarmony counterpart of `lib/flow_background.dart`, which does not exist.
  Registering a work item that wakes an ability which cannot run the model would
  be worse than not scheduling it, so `FlowPlugin` logs the unscheduled triggers
  instead. Work needed: new ExtensionAbility, a module.json5 entry, and a Dart
  entrypoint wired the way `finn_ai/flow_background` is on Android.
- **Downloads are suspended when the app is backgrounded.**
  `ohos.permission.KEEP_BACKGROUND_RUNNING` is not declared because no
  continuous task exists to justify it. Keep the app foregrounded for a long
  transfer, or add a `backgroundTaskManager` long-running task.
- **Speech-to-text needs a Whisper runtime.** The PCM capture path is
  implemented and verified, but `sherpa_onnx` has no OHOS build, so
  `third_party/onnxruntime` headers are not yet backed by an OHOS
  `libonnxruntime.so`. `voiceSupportedOnPlatform` keeps the voice UI hidden until
  that exists, rather than showing a mic that cannot transcribe.
- **TTS is the system engine only.** The on-device Supertonic voice
  (`libfinn_tts.so` via FFI) is not built for OHOS, so read-aloud falls back to
  `flutter_tts` → HarmonyOS `textToSpeech`. `flutter_pcm_sound` (PCM playback of
  Supertonic output) is Android-only and stays that way.
- **Device actions are honest, not generous.** `torch`, `media`, `volume`,
  `vibrate`, `set_alarm` and `set_timer` report `unavailable`: HarmonyOS gives a
  third-party app no public API for them. `dial`, `compose_sms`,
  `compose_email`, `navigate`, `open_url`, `take_photo`, `open_settings`,
  `show_alarms`, `open_app` and `share` (clipboard) all work.
- **`PROCESS_TEXT` and memory-pressure callbacks** stay Android-only; neither has
  a HarmonyOS equivalent a Flutter app can subscribe to.
- **`Emulator` screen lock.** The first `aa start` after boot fails with
  `10106102 … device screen is locked`; `power-shell wakeup` fixes it, and
  `tool/run_ohos.sh` is run after a wakeup.

---

## 8. Versioning

`ohos/AppScope/app.json5` (`versionCode` / `versionName`) must be bumped **in
lockstep with** `pubspec.yaml` (`version: 2.0.0-beta+9` → code `9`, name
`2.0.0`). The fork rewrites `AppScope` from pubspec on every build, but
`oh-package.json5` has no such bridge and is updated by hand. Keep
`versionCode` monotonically increasing across platforms.