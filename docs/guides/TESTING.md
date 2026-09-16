# Testing FinnAI

## Running

```bash
flutter test                       # everything
flutter test test/engine/          # engine + model pipeline
flutter test test/features/        # feature/widget tests
flutter test --coverage            # CI uses this; writes coverage/lcov.info
bash test/shell/test_cleanup.sh    # packaged shell tests
```

If the Flutter tool aborts on the OHOS fork, add `--no-pub` (see [BUILD.md](BUILD.md)).

## Layout

`test/` mirrors `lib/`:

```text
test/
├── engine/     engine, model pipeline, prompt/intent, device profile, adaptive selection
├── features/   chat, conversations, search, settings, skills, you, creations, voice, reporting
├── app/        bootstrap, legal config, asset verification, release gates, platform shims
├── goldens/    golden PNGs
├── flux_golden_test.dart        # ⚠ must stay at the test root (resolves goldens/ relatively)
├── flutter_test_config.dart     # ⚠ must stay at the test root (registers the golden comparator)
└── shell/      shell-level tests
```

## Golden tests

`test/flux_golden_test.dart` renders whole screens and compares them to PNGs in `test/goldens/`.
`test/flutter_test_config.dart` installs a cross-platform comparator with a small pixel tolerance so
the suite passes on both macOS and Linux.

Regenerate after an intentional visual change:

```bash
flutter test --update-goldens test/flux_golden_test.dart
```

Any change that alters text rendered inside a golden (for example renaming the model) requires this,
and the regenerated PNG must be reviewed — not blindly committed.

## What the tests cover

- `test/engine/model_download_recovery_test.dart` — partial promotion and rejection of wrong sizes.
- `test/engine/prompt_intent_test.dart` — intent classification, output budgets, and which prompts
  are allowed to trigger the web-search decision pass.
- `test/features/conversation_store_test.dart` — encryption round-trips, legacy plaintext migration,
  archive fault-back, and the refuse-to-overwrite behaviour when the key is missing.
- `test/features/chat_generation_controller_test.dart` — queueing, cancellation, persistence.
- `test/app/release_hardening_test.dart` — immutable model revisions, digest format, markdown
  sanitization.

## Testing on a device

Unit tests cannot cover the native runtime, so real-device checks matter:

```bash
adb shell run-as com.abhiflex.finnai ls -la files/models/   # what actually downloaded
adb logcat -s flutter | grep FINN_                          # pipeline trace
adb exec-out screencap -p > /tmp/shot.png                   # capture the current screen
adb shell input tap X Y                                     # drive the UI
```

The `finn-device-test` agent skill in `.agents/skills/` has the full playbook.

## Adding a test

- Engine logic → `test/engine/`; widget/feature behaviour → `test/features/`; cross-cutting or
  release gates → `test/app/`.
- Import through `package:finn_ai/src/...` (absolute imports are used throughout).
- Prefer asserting observable behaviour over private internals.
