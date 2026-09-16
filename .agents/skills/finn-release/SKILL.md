---
name: finn-release
description: Prepare and verify a FinnAI Play Store release — signing config, store metadata, the 16 KB native alignment gate, and the full verification script. Use before cutting a version, bumping the build number, or when release verification fails.
when_to_use: Cutting a release, bumping the version, preparing a Play Store upload, verifying a signed AAB, or debugging a failed release gate.
---

# Releasing FinnAI

## 1. Version and copy

- Bump `version:` in `pubspec.yaml` (the format is `x.y.z+build`; the build number must increase for
  every Play upload).
- Update anything the release changes: `README.md`, `docs/store/en-US/listing.md`, and — if the
  model changed — the l10n strings, legal docs and `THIRD_PARTY_NOTICES.md`
  (see the `finn-model-pipeline` skill).

## 2. Signing

`android/key.properties` must exist with `storePassword`, `keyPassword`, `keyAlias`, `storeFile`.
This file is gitignored and must never be committed. Keyed uploads fail without it.

## 3. Store URLs

`tool/verify_release.sh` and `tool/build_play_release.sh` read these from the environment:

```bash
export FINN_SUPPORT_URL="https://finn-org.vercel.app/support"
export FINN_SUPPORT_EMAIL="finn_org@proton.me"
export FINN_REPORT_EMAIL="finn_org@proton.me"
export FINN_PRIVACY_POLICY_URL="https://finn-org.vercel.app/privacy"
export FINN_TERMS_URL="https://finn-org.vercel.app/terms"
```

The scripts require HTTPS and will fail fast on a missing or malformed URL.

## 4. Verify

```bash
./tool/verify_release.sh
```

This builds the signed release artifacts and enforces the hard gates, including **16 KB ELF page
alignment** on the native libraries (required for Android 15+;
see `docs/guides/NATIVE_16KB_VERIFICATION.md`).

Run the full CI-equivalent suite first:

```bash
dart format --output=none --set-exit-if-changed .
bash tool/verify_engine_seam.sh
flutter analyze
flutter test
bash test/shell/test_cleanup.sh
```

## 5. Pre-upload checklist

- [ ] version bumped, build number increased
- [ ] `flutter test` green, including goldens
- [ ] engine seam passes
- [ ] release script passes, 16 KB alignment OK
- [ ] store listing and screenshots current (`docs/store/`)
- [ ] privacy policy and terms reflect what the app actually does — especially web-search egress
      and what is stored on disk
- [ ] Data safety form matches `docs/operations/DATA_SAFETY_DRAFT.md`
- [ ] `docs/operations/PLAY_CONSOLE_CHECKLIST.md` walked through

## Gotchas

- The release APK/AAB is far smaller than the debug build; a sudden size jump usually means native
  artifacts changed — check `tool/rebuild_llama_android_aar.sh` output.
- Never hand-edit `third_party/llama_cpp_dart/`; patch and rebuild through `tool/`.
- A golden diff is a release blocker until a human has looked at the image.
