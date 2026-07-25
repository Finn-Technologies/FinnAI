# Google Play Console Checklist for FinnAI

This document demarcates automated repository preparation from manual actions required inside the Google Play Console interface.

---

## Part A: Completed Repository Artifacts (Automated & In-Repo)

- [x] **Package Identity**: Set to `com.abhiflex.finnai` across Manifest, Gradle, Kotlin paths.
- [x] **SDK Targets**: `compileSdk = 36`, `targetSdk = 36`, `minSdk = 26`.
- [x] **App Launcher Icon**: Adaptive icon configured (`mipmap-anydpi-v26/ic_launcher.xml`).
- [x] **Native 16 KB Page Size**: Relinked shared libraries in `llama-cpp-dart.aar` verified 16 KB aligned (`LOAD Align = 0x4000`).
- [x] **Release Signing Setup**: Enforced `android/key.properties` or environment variables for release builds with Gradle validation.
- [x] **AdMob & Privacy Consent**: Integrated Google UMP consent SDK (`AdConsentService`), environment-aware AdMob unit IDs (`kReleaseMode`), banner error collapse.
- [x] **Encrypted Local Storage**: Implemented authenticated AES-256-CTR + HMAC-SHA256 storage (`conversations.json.enc`) with legacy migration and data purge action.
- [x] **AI Safety & Reporting**: Added in-app Report dialog, serverless backend code, and red-team safety evaluation documentation.
- [x] **Production Scope Cleanup**: Static microphone removed, non-functional sidebar items removed, "Creations" gated behind `FINN_ENABLE_EXPERIMENTS`.
- [x] **Legal & Attribution**: Published `PRIVACY_POLICY.md`, `TERMS_OF_USE.md`, `THIRD_PARTY_NOTICES.md`, dynamic versioning, and open-source licence viewer.
- [x] **CI & Release Verification**: Added `.github/workflows/ci.yml` and `tool/verify_release.sh`.

---

## Part B: Manual Google Play Console Steps

Follow these steps in the [Google Play Console](https://play.google.com/console):

### 1. App Setup & Listing
- [ ] **App Name**: `FinnAI - On-Device AI Assistant`
- [ ] **Short Description**: `Private, on-device AI assistant powered by local open-source models.`
- [ ] **Full Description**: Copy detailed feature summary from `README.md`.
- [ ] **App Category**: Tools / Productivity.
- [ ] **Graphics Assets**:
  - App Icon: 512 × 512 px PNG.
  - Feature Graphic: 1024 × 500 px PNG.
  - Phone Screenshots: Minimum 2 screenshots (16:9 or 9:16 aspect ratio).

### 2. Privacy Policy & Data Safety
- [ ] **Privacy Policy URL**: Host `legal/PRIVACY_POLICY.html` on GitHub Pages or custom domain and enter URL.
- [ ] **Data Safety Questionnaire**: Fill out using `docs/DATA_SAFETY_DRAFT.md`.
- [ ] **Advertising ID Declaration**: Declare that the app uses Advertising ID for AdMob ads and UMP consent.

### 3. Closed Testing Track Setup
- [ ] **Create Closed Testing Track**: Create a new Closed Testing track named `Alpha Testing` or `Closed Beta`.
- [ ] **Upload App Bundle (AAB)**: Build and upload `build/app/outputs/bundle/release/app-release.aab`.
- [ ] **Add Testers**: Add at least 20 opted-in testers (required for new developer accounts for 14 days minimum).
- [ ] **Submit for Review**: Send build to Google for Closed Testing review.
