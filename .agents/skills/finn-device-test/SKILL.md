---
name: finn-device-test
description: Build, install and exercise the FinnAI Android app on a connected device over ADB, capturing logs and screenshots. Use when behaviour must be verified on real hardware — model download, inference, vision, navigation, or a bug that only reproduces at runtime.
when_to_use: Verify a change end-to-end on a real device, reproduce a runtime bug, test the model pipeline after a catalog change, or check UI behaviour that widget tests cannot cover.
---

# Testing FinnAI on a device

Native inference, the download service and the PROCESS_TEXT integration cannot be covered by unit
tests, so verify those on hardware.

## Build and install

```bash
adb devices -l                                   # confirm a device is attached
flutter build apk --debug                        # ~86 MB, bundles the runtime
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.abhiflex.finnai/.MainActivity
```

If the Flutter tool aborts on the OHOS fork, add `--no-pub` (see `docs/guides/BUILD.md`).

## Interact like a user

```bash
adb exec-out screencap -p > /tmp/shot.png        # capture the screen
adb shell input tap 500 2258                     # tap at a coordinate
adb shell input swipe 540 1900 540 500 300       # swipe (300 ms)
adb shell "adb shell input text 'Hello%sthere'"  # spaces are %s
adb shell dumpsys window | grep mCurrentFocus    # which window has focus
```

The device screen sleeps quickly. Keep it awake while testing and restore it afterwards:

```bash
adb shell svc power stayon true
# ... test ...
adb shell svc power stayon false
```

## Watch the pipeline

```bash
adb logcat -c                                    # clear before a scenario
adb logcat -s flutter | grep -E "FINN_"
```

| Tag | Confirms |
|---|---|
| `FINN_INSTALLING_MODEL` | which URL the app is really downloading |
| `FINN_INSTALL_ARTIFACT_COMPLETE` | an artifact finished, with its byte count |
| `FINN_ENGINE` | the live config (threads, context, KV type, device) |
| `FINN_PREFIX` | prefix-cache hit/miss |
| `FINN_TTFT_SUMMARY` / `FINN_PERF` | latency and throughput |

`adb shell run-as com.abhiflex.finnai ls -la files/models/` shows the artifacts that actually
landed — sizes are the fastest way to prove *which* model is installed.

## Scenario checklist

Run at least: first launch → onboarding → model download → load → first chat → streaming →
new conversation → conversation reload after force-stop → settings → attachment picking → back
navigation. Then try to break it:

```bash
adb shell am force-stop com.abhiflex.finnai      # process death mid-generation
adb shell wm dismiss-keyguard                    # resume after backgrounding
adb shell "am start -a android.intent.action.PROCESS_TEXT -t text/plain \
  --es android.intent.extra.PROCESS_TEXT 'Explain gravity in one sentence' \
  -n com.abhiflex.finnai/.AskFinnActivity"
```

That last one exercises the "Ask Finn AI" text-selection integration end to end.

## Reinstall vs. reset

`adb install -r` keeps app data, so the downloaded model and conversations survive — which is
usually what you want when iterating. To test a true first run, clear data:

```bash
adb shell pm clear com.abhiflex.finnai
```

**This deletes the downloaded model (≈1.5 GB) and forces a full re-download.** Use it deliberately,
and remember it also wipes conversations.

## Before you report success

State exactly what you observed versus what you inferred. If you did not see a log line or a
screenshot confirming a behaviour, say it was not verified.
