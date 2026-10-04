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

### 2.3 Build the speech-recognition libraries

```bash
source tool/ohos_env.sh
bash tool/build_voice_ohos.sh
```

Builds `libonnxruntime.so` and the sherpa-onnx C API against the same sysroot and
installs them next to the llama.cpp libraries. It builds onnxruntime from source
(there is no OHOS prebuild to download), so it is slow -- roughly 900 translation
units. §8 explains the five patches it applies and the gates it enforces.

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
| `com.llfbandit.record/*` | `AudioRecordPlugin.ets` | PCM16 stream for on-device STT, plus `hasPermission` (needs `ohos.permission.MICROPHONE`) |
| `finn_ai/device_profile` | `DeviceProfilePlugin.ets` | RAM/ABI/SoC/free storage |
| `finn_ai/device_actions` | `DeviceActionsPlugin.ets` | the device-action catalog |
| `finn_ai/flow_schedule`, `finn_ai/flow_env` | `FlowPlugin.ets` | flow triggers, conditions, notifications |
| `finn_ai/share_file` | `SharePlugin.ets` | data export / share |

### Dart side

`lib/src/platform/` is the OHOS seam:

- `platform_target.dart` — `finnPlatform` / `isOpenHarmony`, plus the documented
  sandbox layout (`ohosSandboxFilesDir`, `ohosSandboxCacheDir`) as the single
  source of truth for "where is the sandbox". **Important:**
  `dart:io` reports `operatingSystem == 'linux'` and `Platform.isLinux == true`
  on HarmonyOS, so anything that branches on `Platform.isLinux` first (or on
  `Platform.isX` at all) silently classifies the app as desktop Linux. OHOS is
  fingerprinted by its per-app sandbox mount points instead.
- `openharmony_path_provider.dart` — path_provider, with hard-coded sandbox
  fallbacks if the native side is missing.
- `openharmony_key_storage.dart` — the conversation master key, in `dart:io`.

### Where the plugin layer is registered (it used to be nowhere)

`FinnPlugins.register()` used to be called only from
`EntryAbility.configureFlutterEngine`. **That never ran.** This app renders
through `FlutterEntry` + `FlutterPage` in `ets/pages/Index.ets`, and
`FlutterEntry` builds the engine itself, so the ability's hook is not on the
path. The result was that every ArkTS shim in `ets/plugins/` was dead code and
every channel answered `No registered handler for message.`

It went unnoticed because `OpenHarmonyPathProvider` falls back to hard-coded
sandbox paths, and because the features that depend on the other channels were
either hidden or reported `unavailable` anyway.

Registration now happens in **both** places, which is deliberate:

* `Index.ets` installs a `FlutterEngineConfigurator` via
  `setFlutterEngineConfigurator` **before** `aboutToAppear()`, because that is
  what builds the engine the configurator is later called with.
* `EntryAbility` keeps its `configureFlutterEngine` override.

Both are needed: this fork constructs two engines (`FlutterAbility.onCreate`
makes one, `FlutterEntry` makes another) and which one Dart talks to is decided
inside the fork. Registering a MethodChannel handler twice is idempotent -- it
replaces, never duplicates -- so registering on both is correct either way.

After this, the only channels that still log a missing handler are
`finn_ai/home_screen`, `finn_ai/process_text` and `flutter/processtext`, all
three of which are Android-only by design (HarmonyOS has no AppWidget and no
`PROCESS_TEXT`). `hilog` shows `Setting handler for channel '<name>'` once per
registered channel, which is the quickest way to confirm the layer is live.

### The conversation key does not use a platform channel

The master key is read and written with plain `dart:io` against the sandbox
`filesDir`. It used to go through a `finn_ai/secure_key` channel implemented in
`SecureKeyPlugin.ets`, which did nothing an ArkTS file API cannot do from Dart,
and which the engine bug below made unusable. `SecureKeyPlugin.ets` has been
removed.

Two rules keep this working:

1. **Same path, same bytes.** The file is still
   `<filesDir>/finn_secure_key_<alias>` and still holds the raw 32 key bytes, so
   a key file written by an earlier build is still readable. Both properties are
   pinned by `test/app/openharmony_key_storage_test.dart`.
2. **The directory comes from `path_provider` when it answers, and from
   `ohosSandboxFilesDir` when it does not.** In practice the channel did *not*
   answer on the API 24 emulator and the hard-coded path carried it —
   `FINN_SECURE_KEY path_provider unavailable, using the documented sandbox
   path` is the expected line in `hilog`, not a fault.

Verified on the API 24 emulator: an existing key file written by the old
`SecureKeyPlugin.ets` was read by the new `dart:io` implementation without being
rewritten, a new conversation encrypted and decrypted across a force-stop and
relaunch, and the sidebar listed it on relaunch.

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
  same response id**. The handler runs — its side effects land — but Dart
  receives an empty reply and raises `MissingPluginException`. The engine's own
  `FlutterNapi --> called handlePlatformMessage Channel: … Response ID: 33`
  line appears twice for one message, and the reply for that id is consumed by
  the first delivery.

  Observed channels: `finn_ai/flow_schedule`.
  Unaffected: `dev.fluttercommunity.plus/package_info`.
  **Resolved for `finn_ai/secure_key`:** that channel has been removed entirely
  and the conversation key is now `dart:io` file I/O, so conversation history
  persists across restarts on HarmonyOS (verified on the emulator).
  `finn_ai/flow_schedule` still needs either an engine fix or the same
  treatment.

  Ruled out: the channel name (renaming `finn_ai/secure_key` to a
  plugin-style name changes nothing), a null success envelope (replying `''`
  instead of `null` changes nothing), a startup race (retrying for 2.5 s changes
  nothing), and a missing handler (`Setting handler for channel` is logged, and
  the handler demonstrably runs).

  Verify a future change with:
  `hdc -t <target> shell "hilog -x" | grep handlePlatformMessage`.
- **Flows cannot fire unattended.** Notifications and condition reading work,
  and event triggers are subscribed while the app runs, but a *time* trigger
  needs a `WorkSchedulerExtensionAbility` plus its own headless Dart engine — the
  OpenHarmony counterpart of `lib/flow_background.dart`, which does not exist.
  Registering a work item that wakes an ability which cannot run the model would
  be worse than not scheduling it, so `FlowPlugin` logs the unscheduled triggers
  instead.

  **The engine half is not the obstacle.** Checked against the fork
  (`3.41.10-ohos-1.0.1`, `embedding/engine/`):
  `FlutterEngine`'s constructor takes a plain `common.Context`, not a
  `UIAbilityContext`, so an extension ability's context is enough;
  `DartEntrypoint(pathToBundle, library, functionName)` and
  `DartExecutor.executeDartEntrypoint` exist with exactly the shape Android uses;
  and `getDartExecutor()` is a `BinaryMessenger`, so a `MethodChannel` works with
  no window. `lib/flow_background.dart` itself needs no platform channels to run
  a flow — flows, conversations and the master key are all `dart:io` now, and
  search is `http`.

  **The obstacle is the time budget.** A `WorkSchedulerExtensionAbility` gets a
  short, suspendable window; loading `libllama.so` plus the 695 MB model already
  took ~75 s wall clock on the API 24 emulator before the first token. So a flow
  containing an `ask` block cannot be relied on to finish unattended, and one
  without it has little reason to be a background task. Work needed: build the
  extension ability and `module.json5` entry, confirm how much budget the
  emulator grants, and decide whether model-free flows are worth it.
- **Downloads are suspended when the app is backgrounded.**
  `ohos.permission.KEEP_BACKGROUND_RUNNING` is not declared because no
  continuous task exists to justify it. Keep the app foregrounded for a long
  transfer, or add a `backgroundTaskManager` long-running task.
- **Speech-to-text: the native libraries now exist.** `tool/build_voice_ohos.sh`
  builds `libonnxruntime.so` and the sherpa-onnx C API for OHOS arm64 and
  installs them into `ohos/entry/libs/arm64-v8a/`. Both are ARM64 OHOS ELFs that
  need only `libc.so`, carry unversioned SONAMEs and package no
  `libc++_shared.so`, and the Dart FFI reaches them because `dart:io` reports
  OHOS as Linux, which is the branch that already loads them on Android. Text to
  speech stays compiled **out**, so espeak-ng (GPL-3.0) is not in the shipped
  library; the script fails the build if it is. `voiceSupportedOnPlatform`
  includes OpenHarmony.
  `ohos.permission.MICROPHONE` is declared, which `AudioRecordPlugin.ets`'s
  `hasPermission` needs before HarmonyOS will grant a capture.
  **Still unconfirmed:** end-to-end transcription. The emulator has no usable
  microphone, so it needs a physical HarmonyOS phone. Until then treat the voice
  button on OHOS as unproven rather than working. Read-aloud on OHOS still uses
  the *system* engine -- `libfinn_tts.so` is not built for OHOS, and the failure
  is expected and logged as `FINN_TTS prepare failed: ... libfinn_tts.so`.
- **TTS is the system engine only.** The on-device Supertonic voice
  (`libfinn_tts.so` via FFI) is not built for OHOS, so read-aloud falls back to
  `flutter_tts` → HarmonyOS `textToSpeech`. `flutter_pcm_sound` (PCM playback of
  Supertonic output) is Android-only and stays that way.
- **Device actions are honest, not generous.** `torch`, `media`, `volume`,
  `set_alarm` and `set_timer` report `unavailable`: HarmonyOS gives a
  third-party app no public API for them. `vibrate` **does** work, through the
  public `vibrator` kit with `ohos.permission.VIBRATE`, with the same 400 ms
  default and 50..2000 ms clamp as Android. Note `startVibration` takes *two*
  arguments on API 24 (`VibrateEffect` + `VibrateAttribute`, whose `usage` is
  required), not one. Compiled and permission-declared, but **not yet confirmed
  on hardware**: the emulator has no vibrator, so `startVibration` there
  rejects and the action honestly reports `unavailable`. `dial`,
  `compose_sms`, `compose_email`, `navigate`, `open_url`, `take_photo`,
  `open_settings`, `show_alarms`, `open_app` and `share` (clipboard) all work.
- **`PROCESS_TEXT` and memory-pressure callbacks** stay Android-only; neither has
  a HarmonyOS equivalent a Flutter app can subscribe to.
- **`Emulator` screen lock.** The first `aa start` after boot fails with
  `10106102 … device screen is locked`; `power-shell wakeup` fixes it, and
  `tool/run_ohos.sh` is run after a wakeup.

---

## 8. Building the OHOS speech stack

`tool/build_voice_ohos.sh` builds `libonnxruntime.so` and the sherpa-onnx C API
for OHOS arm64 and installs them into `ohos/entry/libs/arm64-v8a/`. It is the OHOS
sibling of `tool/rebuild_sherpa_android.sh`, and like
`tool/rebuild_llama_ohos.sh` the libraries must be **rebuilt** when the SDK moves,
never re-copied.

**Why two projects.** sherpa-onnx downloads a prebuilt onnxruntime per platform
and there is no OHOS build to download, so onnxruntime is built first and handed
over via `SHERPA_ONNXRUNTIME_INCLUDE_DIR` / `SHERPA_ONNXRUNTIME_LIB_DIR`. The
headers in `third_party/onnxruntime/include` are the same 1.28.x release the Dart
FFI was generated against.

### The five onnxruntime patches (`tool/onnxruntime_ohos_build.patch`)

onnxruntime 1.28.2 *configures cleanly* against the stock HarmonyOS NDK
toolchain, then needs five patches. It defines `__MUSL__` and `__OHOS__`, so they
key off `__OHOS__` the way upstream keys off `__APPLE__`.

1. **`mlas/lib/fp16_common.h`** -- require `__ARM_FEATURE_FP16_VECTOR_ARITHMETIC`
   as well as `MLAS_F16VEC_INTRINSICS_SUPPORTED`. ORT defines the latter for every
   non-Apple ARM64 target, but applies `-march=armv8.2-a+fp16` only *per source*
   to the `*_fp16.cpp` kernels. The core fp32 translation units include this
   header transitively via `mlasi.h`, so on any toolchain whose default `-march`
   lacks FP16 -- the HarmonyOS clang, for one -- they fail on `vaddq_f16` even
   though they call nothing in the file. The fp16 kernels, which do get the flag,
   are unaffected.
2. **`mlas/lib/mlasi.h`** -- same for `bfloat16_t` (`__bf16`) and the SBGEMM
   kernel members, which need `+bf16`.
3. **`core/platform/posix/env.cc`** -- add `__OHOS__` to the
   `pthread_setaffinity_np` carve-out; HarmonyOS's musl has no such function.
   Losing per-thread affinity is a throughput concern only, same as on Android.
4. **`cmake/onnxruntime.cmake`** -- omit `VERSION`/`SOVERSION` on OHOS. The
   sandbox resolves `DT_NEEDED` by SONAME out of `libs/arm64` and Dart's
   `DynamicLibrary.open` uses the bare filename, so a versioned name means
   shipping the 18 MB stripped library twice.
5. **`core/session/model_editor_c_api.cc`** -- bind two `set().insert()` results
   to named variables instead of structured bindings. Clang 15 rejects a
   structured binding captured by the rollback lambda; GCC accepts it.

Plus one change the script makes to the FetchContent'd **pytorch/cpuinfo**:
its `CPUINFO_SUPPORTED_PLATFORM` gate allowlists OS names and has no `OHOS`, so
it compiles no platform sources at all and `cpuinfo_arm_linux_init` /
`_deinit` are undefined at link time. HarmonyOS is Linux-compatible for its
purposes (`/proc/cpuinfo`, `sched_getaffinity`), so the allowlist is taught
`OHOS`.

### Why the FP16 kernels are not simply built with `-march=armv8.2-a+fp16`

That flag would compile, and it is tempting. It must not be used: FP16 vector
arithmetic is ARMv8.6-A, which only Snapdragon 8 Gen 3 / Kirin 9010 class parts
have. A `libonnxruntime.so` built that way `SIGILL`s on Snapdragon 8 Gen 1/2 and
Kirin 9000, which is most of the installed base. Patches 1 and 2 keep the fp32
translation units off the FP16 ISA instead, so no fp32 code path can emit an
fp16 instruction. `libonnxruntime.so` still *contains* fp16 and bf16 kernels --
ORT compiles those TUs with the flags itself -- but executing them happens only
when an fp16/bf16 model is loaded, and Whisper and Silero are fp32.

### Gates the script enforces

* espeak-ng must not appear in `libsherpa-onnx-c-api.so` (GPL-3.0). Matched as
  `espeak[_-]ng` so the harmless `OfflineSpeaker` symbol does not trip it.
* every shipped library must have an unversioned SONAME
* no library may need `libc++_shared.so`

Then strip (`llvm-strip --strip-unneeded`): these ship inside the HAP and carry
~26 MB of debug info otherwise. The HAP goes from ~156 MB to ~178 MB.

What this does **not** give you: on-device spoken replies. Those need
`libfinn_tts.so` (`android/app/src/main/cpp/finn_supertonic.cc`) plus PCM
playback, neither built for OHOS, so OHOS reads replies with the system engine.

---

## 9. Versioning

`ohos/AppScope/app.json5` (`versionCode` / `versionName`) must be bumped **in
lockstep with** `pubspec.yaml` (`version: 2.0.0-beta+9` → code `9`, name
`2.0.0`). The fork rewrites `AppScope` from pubspec on every build, but
`oh-package.json5` has no such bridge and is updated by hand. Keep
`versionCode` monotonically increasing across platforms.