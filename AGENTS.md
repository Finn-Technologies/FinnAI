# AGENTS.md — operating FinnAI

FinnAI is a **private, on-device AI assistant** for Android, OpenHarmony and desktop Linux: a Flutter UI over a
native llama.cpp runtime (`FinnAI-Accelerator`) that runs a single downloaded model
(`LFM2.5-VL Q4_0`: the 3B on capable phones, the 1.6B elsewhere) entirely on the device. There is no server, no account, and no cloud
inference.

This file is the contract for any agent or engineer working in this repository. Read it before
editing. `docs/architecture/CODE_MAP.md` tells you *which file to edit for which behaviour*.

---

## 1. Hard constraints (do not break these)

| Rule | Why | How it is enforced |
|---|---|---|
| **Only `lib/src/engine/**` may import `package:llama_cpp_dart`.** Everything else depends on the engine facade. | Keeps the native runtime swappable and the app buildable without the FFI package. | `bash tool/verify_engine_seam.sh` (runs in CI) |
| **One model family, two tiers, one tier per device** (ADR 0013). The 3B goes to devices `ModelTierPolicy` clears, the 1.6B everywhere else; a device downloads only its selected tier. Never add a third tier without measuring it on a real device. | Download, verification, storage, settings and deletion key off the selected tier's artifacts (model + its own projector). | `FinnAccelerator.selected`, `ModelTierPolicy`, `test/engine/model_tier_policy_test.dart` |
| **Never change the model's `downloadUrl`, `expectedBytes` or `sha256Digest` without verifying against Hugging Face.** | A wrong digest makes downloads fail; a wrong size silently corrupts installs. | `test/app/release_hardening_test.dart` |
| **`lib/l10n/app_localizations*.dart` are generated.** Edit `lib/l10n/app_*.arb`, never the generated files. | `flutter gen-l10n` overwrites them. | `flutter pub get` / build |
| **Code must be `dart format` clean.** | CI gate. | `dart format --output=none --set-exit-if-changed .` |
| **User-facing strings go through `L10n.of(context)`.** | The app ships 5 locales. | review |
| **`engine/` imports nothing from `features/`, `app/`, `shared/`, `platform/`; only `chat` imports other features; no Dart file over 600 lines.** Pre-existing violations are baselined and may only shrink. | Keeps units small enough for an agent to hold in context and stops new coupling. | `bash tool/verify_boundaries.sh` (runs in CI) |
| **A turn never runs more than one search, and the model never emits tool calls in chat** (direction, see ADR 0001; the current loop is being removed). FinnAI Code is a separate mode with its own bounded action loop (ADR 0010); it never feeds chat. | A 1.6B model loops on tool calls. | `docs/decisions/0001-app-driven-search.md`, `docs/decisions/0010-finnai-code.md` |

---

## 1a. Where the rules live

Root rules are here. Area rules are nested and short; read the one for the directory you edit:
`lib/src/engine/AGENTS.md`, `lib/src/features/chat/AGENTS.md`, `lib/src/features/flows/AGENTS.md`,
`lib/src/features/creations/AGENTS.md`, `lib/src/features/search/AGENTS.md`, `lib/src/features/code/AGENTS.md`.
Every `lib/src/features/<name>/` has a `README.md` (purpose, entry points, invariants).
Why-decisions are in `docs/decisions/` — read before undoing one. `PLAN.md` is the roadmap and progress log.

**When you finish a change:** if you added, moved or deleted a file named in `docs/architecture/CODE_MAP.md`,
update the map (a test fails if it names a missing file). If you fixed a baselined violation, delete its line
in `tool/boundaries_baseline.txt`.

---

## 2. Repository layout

```text
FinnAI/
├── AGENTS.md                     # this file
├── README.md                     # product + developer entry point
├── lib/
│   ├── main.dart                 # entry point (no logic beyond bootstrap)
│   ├── l10n/                     # ARB sources + generated localizations + l10n_helper
│   └── src/
│       ├── app/                  # bootstrap widget + global app state
│       ├── features/             # one folder per user-facing feature
│       │   ├── chat/             # chat shell + generation controller
│       │   ├── onboarding/       # first-run flow + upgrade screen
│       │   ├── conversations/    # encrypted conversation persistence
│       │   ├── search/           # web grounding + headless browser
│       │   ├── settings/  flows/  you/  creations/  voice/  reporting/
│       │   ├── code/             # FinnAI Code: a coding agent (second app in the app)
│       ├── engine/               # ⚡ the ONLY place llama_cpp_dart is imported
│       ├── inference/            # public re-export surface of the engine (see below)
│       ├── platform/             # OS-specific shims (OpenHarmony)
│       └── shared/               # theme, widgets, config
├── test/                         # mirrors lib/ (app/, engine/, features/) + goldens/
├── .agents/skills/               # repo-local agent skills (see §6)
├── docs/                         # architecture / guides / reference / operations / legal
├── android/  ohos/  linux/       # native platform projects (linux/ = GTK runner, see docs/guides/LINUX.md)
├── third_party/llama_cpp_dart/   # vendored FFI bindings (excluded from analysis)
└── tool/                         # build + verification scripts
```

### The engine seam (`engine/` vs `inference/`)

- `lib/src/engine/**` owns the native runtime. `engine/backends/llama_shim.dart` is the **only**
  file that imports `package:llama_cpp_dart`.
- `lib/src/inference/**` is the **app-facing surface**: seven one-line `export` shims that point at
  engine internals, so the rest of the app never imports `engine/` paths directly. This is what
  makes the engine extractable later (see `docs/architecture/ENGINE_ROADMAP.md`).
- Rule of thumb: **app code imports from `inference/`; engine code imports its own siblings.**

---

## 3. Commands

```bash
# Dependencies
flutter pub get

# Static analysis + format + tests (what CI runs)
dart format --output=none --set-exit-if-changed .
bash tool/verify_engine_seam.sh
bash tool/verify_boundaries.sh
flutter analyze
flutter test
bash test/shell/test_cleanup.sh

# Focused test runs
flutter test test/engine/                     # engine + model pipeline
flutter test test/features/chat_generation_controller_test.dart

# Build + install on a connected device
flutter build apk --debug
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.abhiflex.finnai/.MainActivity

# Watch runtime logs (engine + model pipeline log under FINN_*)
adb logcat -s flutter

# Full release verification (signed AAB, 16 KB alignment gate)
./tool/verify_release.sh
```

**If `flutter analyze`/`flutter test` abort with "No Hmos SDK found"**, this checkout is using the
OpenHarmony Flutter fork and the command is triggering OHOS tooling regeneration. Run the same
command with `--no-pub` (`flutter test --no-pub`), or use `dart analyze .` directly. See
`docs/guides/BUILD.md`.

---

## 4. Common tasks

### Change the on-device model
1. Update the tier's entry in `lib/src/engine/catalog/model_catalog.dart` (`name`, `parameterLabel`,
   `fileName`, `downloadUrl`, `expectedBytes`, `sha256Digest`) **and** its `projector` if that changes.
   Which device gets which tier is `ModelTierPolicy` (ADR 0013).
2. Verify `expectedBytes` and the SHA-256 against the Hugging Face LFS metadata:
   `curl -s "https://huggingface.co/api/models/<repo>/tree/<revision>"` — the `lfs.oid` **is** the
   sha256 and `size` is the byte count.
3. Update every surface that names the model: `lib/l10n/app_en.arb` (`settingsModelArchitectureValue`,
   `onboardingInstall*`) **and the other locales**, `docs/legal/TERMS_OF_USE.md`,
   `docs/legal/PRIVACY_POLICY.md`, `THIRD_PARTY_NOTICES.md`, `README.md`.
4. `flutter test --update-goldens test/flux_golden_test.dart` if onboarding renders the name.
5. Add the previous filename to `_retiredModelFiles` in `finn_accelerator.dart` so upgrades delete it.

### Add a feature screen
Put it in `lib/src/features/<feature>/`, use `FinnPageHeader` + `FluxColors`/`FluxRadius` from
`lib/src/shared/`, route through `FinnPageRoute` (`shared/widgets/finn_page_route.dart`, re-exported by `chat/home_shell.dart`; from the sidebar use `_pushFromSidebar` in `chat/shell/navigation.dart`), and add every string to
`lib/l10n/app_en.arb` (and the other four locales) before running `flutter pub get`.

Creations work differently — a creation is a runnable artifact, so read
`docs/architecture/CREATIONS.md` before touching anything under `lib/src/features/creations/`.

### Debug the model pipeline on a device
```bash
adb shell run-as com.abhiflex.finnai ls -la files/models/   # downloaded artifacts
adb logcat -s flutter | grep FINN_                          # pipeline trace
```
Key log tags: `FINN_INSTALLING_MODEL`, `FINN_INSTALL_ARTIFACT_COMPLETE`, `FINN_ENGINE`,
`FINN_PREFIX`, `FINN_PROMPT`, `FINN_TTFT`, `FINN_PERF`. See
`docs/architecture/MODEL_PIPELINE.md`.

---

## 5. Gotchas

- **Golden tests**: `test/flutter_test_config.dart` must stay at the `test/` root, and
  `test/flux_golden_test.dart` resolves `goldens/…` relative to itself — keep both where they are.
- **Generated localizations** are committed; run `flutter pub get` after editing any `.arb`.
- **`third_party/llama_cpp_dart/` is vendored and excluded from analysis.** Patch via
  `tool/llama_android_build.patch` + `tool/rebuild_llama_android_aar.sh`, never by hand-editing.
- **The engine is single-model and CPU-pinned on Android.** Don't re-enable accelerator probing on
  Android; see the comment in `lib/src/engine/loader/device_optimizer.dart`'s `optimizeForDevice`.
- **Conversations are AES-256-GCM encrypted** with a key in Android KeyStore. If the key is missing
  but an encrypted file exists, the store refuses to overwrite — that is deliberate
  (`ConversationStore._storageError`), not a bug to "fix" by deleting the file.

---

## 6. Repo-local skills

Task playbooks live in `.agents/skills/` and are auto-discovered (invoke with `/<name>`):

| Skill | Use when |
|---|---|
| `finn-model-pipeline` | Touching the catalog, download, verification, residency, or loading |
| `finn-engine-seam` | Adding/changing anything that touches the native runtime or its facade |
| `finn-feature` | Adding or changing a user-facing feature screen or string |
| `finn-device-test` | Building, installing, and exercising the app on a real device |
| `finn-release` | Preparing or verifying a release build |

Desktop and large-screen work (window classes, docked sidebar, Linux runner) is documented in
`docs/guides/LINUX.md`; breakpoints live only in `lib/src/shared/layout/finn_layout.dart`.
