---
name: finn-model-pipeline
description: Safely change or debug FinnAI's on-device model pipeline — the model catalog, download and resume, integrity verification, storage, loading and deletion. Use when the task mentions the model, its download, the projector (mmproj), the catalog, expectedBytes/sha256, install progress, or "the app downloaded the wrong model".
when_to_use: Editing model_catalog.dart, changing the model name or digest, debugging a stalled or corrupt download, checking what the app actually downloaded, or adding/retiring a model artifact.
---

# FinnAI model pipeline

Full background: `docs/architecture/MODEL_PIPELINE.md`. Read it first.

## House rules (violating these breaks the product)

1. **One model, one tier.** `finnModels` has exactly one entry. Never add a second catalog entry,
   tier, or fallback model.
2. **The digest is the contract.** Never change `downloadUrl`, `expectedBytes`, or `sha256Digest`
   without re-verifying against Hugging Face LFS metadata.
3. **UI, docs and legal must agree with the catalog.** The model name appears in
   `lib/l10n/app_*.arb` (all five locales), `README.md`, `THIRD_PARTY_NOTICES.md`,
   `docs/legal/PRIVACY_POLICY.md` and `docs/legal/TERMS_OF_USE.md`. A mismatch between what the UI
   says and what the app downloads is the single worst bug class in this repo.
4. **Never import `package:llama_cpp_dart` outside `lib/src/engine/**`.**

## Verify a digest before you write it

```bash
curl -s "https://huggingface.co/api/models/<owner>/<repo>/tree/<revision>" \
  | python3 -c "import sys,json; [print(e['path'], e['size'], (e.get('lfs') or {}).get('oid')) for e in json.load(sys.stdin)]"
```

`lfs.oid` **is** the SHA-256; `size` is `expectedBytes`. The revision in the URL must be a 40-char
immutable commit, never `main`. `test/app/release_hardening_test.dart` enforces the URL shape.

## Changing the model

1. Update `lib/src/engine/catalog/model_catalog.dart` — `name`, `parameterLabel`, `fileName`,
   `downloadUrl`, `expectedBytes`, `sha256Digest`, and `finnMmproj` if the projector changed.
2. Update the UI strings: `lib/l10n/app_en.arb` (`onboardingInstallTitleInstalling`,
   `onboardingInstallTitleReady`, `onboardingInstallPreparing`, `settingsModelArchitectureValue`)
   **and** `app_de/es/fr/it.arb`, then `flutter pub get`.
3. Update `README.md`, `THIRD_PARTY_NOTICES.md`, `docs/legal/*`.
4. Add the previous filename to `_retiredModelFiles` in
   `lib/src/engine/finn_accelerator.dart` so upgrades delete it.
5. Regenerate goldens: `flutter test --update-goldens test/flux_golden_test.dart`, then *look* at the
   diff (`test/goldens/onboarding_model.png`) before committing.
6. Run the gates:

```bash
dart analyze .
flutter test
bash tool/verify_engine_seam.sh
```

## Debugging on a device

```bash
# What actually landed on disk (exact byte counts)
adb shell run-as com.abhiflex.finnai ls -la files/models/

# Pipeline trace
adb logcat -s flutter | grep -E "FINN_INSTALLING_MODEL|FINN_INSTALL_ARTIFACT_COMPLETE|FINN_RESUME|FINN_MMPROJ"
```

Log tags and their meanings are tabulated in `MODEL_PIPELINE.md`.

Expected artifacts for the shipped model:

| File | Bytes |
|---|---|
| `LFM2.5-VL-1.6B-Q4_0.gguf` | 695752480 |
| `mmproj-LFM2.5-VL-1.6b-F16.gguf` | 853993856 |

## Non-obvious invariants worth preserving

- A promoted artifact that fails SHA-256 **must be deleted** (`_verifyPromotedArtifact`). Otherwise
  `_isVerifiedModelFile` (size + GGUF magic only) accepts it on every later run and it can never be
  re-downloaded.
- `isInstalled()` is deliberately cheap. Do not add a full hash there — it runs on every launch.
- The projector downloads **second** and is optional for text chat, so its failures are tolerated.
  Any failure path that tolerates it must also ensure a later startup resumes the `.part`
  (`_resumeInterruptedMmproj`), or vision stays silently disabled forever.
- `removeAllModels()` must cancel an in-flight install before deleting, or the Android foreground
  service will rename a partial back into place after the unlink.

## Tests to run after a change here

```bash
flutter test test/engine/ test/app/release_hardening_test.dart test/features/conversation_store_test.dart
```
