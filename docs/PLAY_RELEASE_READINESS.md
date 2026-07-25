# FinnAI Google Play Release Readiness Checklist

This document tracks all tasks required to make FinnAI ready for Google Play Closed Testing.

## Phase 1: Baseline Inspection & Diagnostics
- [x] Record Flutter / Dart SDK versions (`Flutter 3.44.7`, `Dart 3.12.2`)
- [x] Run baseline `flutter pub get`
- [x] Run baseline `dart format`
- [x] Run baseline `flutter analyze` (0 issues found)
- [x] Run baseline `flutter test` (20 passed, 1 golden failure due to icon/branding updates)
- [x] Run baseline `flutter build apk --debug` (Success)
- [x] Create release readiness documentation and tracking checklist

## Phase 2: Android Identity & Release Configuration
- [ ] Verify Android package identity (`com.abhiflex.finnai`) across Gradle, Kotlin, Manifests, and tests
- [ ] Verify launcher icon resources & adaptive icons (`mipmap-anydpi-v26/ic_launcher.xml`)
- [ ] Update Android target SDK & compile SDK to 36 (keeping `minSdk = 26`)
- [ ] Implement secure release signing configuration via `key.properties` / environment variables with `key.properties.example`
- [ ] Ensure release build fails clearly when signing credentials are missing (never fall back to debug)
- [ ] Update Dart package name (`finn_ai`), description, and `package_info_plus` integration for version/build display

## Phase 3: AdMob Privacy & Consent
- [ ] Upgrade `google_mobile_ads` package to latest compatible stable version
- [ ] Implement `AdConsentService` (`lib/src/privacy/ad_consent_service.dart`) using Google UMP APIs
- [ ] Refactor startup in `lib/main.dart` to initialize consent asynchronously without blocking local AI
- [ ] Configure debug vs production Ad Unit IDs using `kReleaseMode` checks
- [ ] Add interactive "Privacy choices" option in Settings calling `ConsentForm.showPrivacyOptionsForm`
- [ ] Refactor Banner Ad widget lifecycle, consent checks, auto-collapsing on failure, and remove unused interstitial ad code

## Phase 4: Encrypted Storage & Privacy Safeguards
- [ ] Implement authenticated AES-256-GCM encryption for conversation storage using Android Keystore / `flutter_secure_storage`
- [ ] Implement seamless migration from legacy plaintext `conversations.json` to encrypted storage without data loss
- [ ] Add unit tests for encrypted storage (save/load, migration, corruption, key errors, atomic writes)
- [ ] Update privacy disclosures in Onboarding and Settings to accurately explain network use vs on-device processing

## Phase 5: In-App AI Response Reporting & Safety
- [ ] Add "Report" action button to all completed assistant messages
- [ ] Create in-app Report dialog with reason selector, context preview, explicit prompt inclusion toggle, and legal notice
- [ ] Implement `ReportService` (`lib/src/reporting/report_service.dart`) with HTTPS, timeouts, and `FINN_REPORT_ENDPOINT` configuration
- [ ] Build deployable serverless reporting backend (`reporting-service/`) with Hono/Cloudflare Worker/Node handler, schema validation, and rate limiting
- [ ] Strengthen model safety system prompts, add supportive self-harm intervention guidance, and document red-team tests (`docs/AI_SAFETY_TESTING.md`)

## Phase 6: Production Scope Cleanup
- [ ] Hide microphone action from production UI (remove unnecessary microphone permission)
- [ ] Remove/hide non-functional "You" and "Skills" sidebar items and refine sidebar layout
- [ ] Gate incomplete "Creations" flow behind `FINN_ENABLE_EXPERIMENTS` flag (disabled by default)

## Phase 7: Settings, Legal, Privacy & Data Controls
- [ ] Display dynamic app version and build number via `package_info_plus` in Settings
- [ ] Create legal policy documents (`legal/PRIVACY_POLICY.md`, `legal/TERMS_OF_USE.md`, HTML versions)
- [ ] Implement in-app Open-Source Licence viewer (`showLicensePage`) and update `THIRD_PARTY_NOTICES.md`
- [ ] Add interactive "Delete all local data" feature to purge history, keys, models, and cache

## Phase 8: Native Library & 16 KB Page-Size Compatibility
- [ ] Inspect bundled `llama-cpp-dart.aar` ARM64 `.so` libraries for 16 KB page boundary alignment
- [ ] Document 16 KB verification findings in `docs/NATIVE_16KB_VERIFICATION.md`

## Phase 9: Asset & Permission Cleanup
- [ ] Clean up runtime asset declarations in `pubspec.yaml` (copy required icons to clean asset directories)
- [ ] Enforce minimal Android permissions in `AndroidManifest.xml` (`INTERNET` only)
- [ ] Audit application logging to ensure no prompt, response, key, or report data leaks in release

## Phase 10: Testing & Quality Assurance
- [ ] Add comprehensive unit tests for consent, encryption, reporting, feature flags, and settings
- [ ] Update golden tests and existing test suite to match updated UI and branding

## Phase 11: Continuous Integration & Verification
- [ ] Create GitHub Actions workflow (`.github/workflows/ci.yml`) for automated PR & branch validation
- [ ] Create release verification script (`tool/verify_release.sh`) for pre-release validation

## Phase 12: Play Store Readiness Documentation
- [ ] Update `README.md` to reflect production product identity
- [ ] Create `docs/PLAY_CONSOLE_CHECKLIST.md` separating repository tasks from external manual tasks
- [ ] Create `docs/DATA_SAFETY_DRAFT.md` for Google Play Console Data Safety form declaration
- [ ] Create `docs/SECURITY_AND_PRIVACY_ARCHITECTURE.md` and `docs/REPORTING_BACKEND.md`

## Phase 13: Final Build & Verification
- [ ] Verify `dart format` compliance
- [ ] Verify `flutter analyze` (0 issues)
- [ ] Verify `flutter test` (100% pass)
- [ ] Build debug APK (`flutter build apk --debug`)
- [ ] Build release AAB (`flutter build appbundle --release`) using test signing config
- [ ] Verify no secrets, keystores, or build artifacts are staged in Git

## Phase 14: Branch Commit & Remote Push
- [ ] Commit all changes to branch `release/google-play-readiness`
- [ ] Push branch to remote `origin`
