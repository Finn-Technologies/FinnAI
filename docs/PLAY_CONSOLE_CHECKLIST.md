# Google Play Console Checklist for FinnAI

This document demarcates automated repository preparation from manual actions required inside the Google Play Console interface.

---

## Part A: Completed Repository Artifacts (Automated & In-Repo)

- [x] **Package Identity**: Set to `com.abhiflex.finnai` across Manifest, Gradle, Kotlin paths.
- [x] **SDK Targets**: `compileSdk = 36`, `targetSdk = 36`, `minSdk = 26`.
- [x] **App Launcher Icon**: Adaptive icon configured (`mipmap-anydpi-v26/ic_launcher.xml`).
- [x] **Native 16 KB Static Compatibility**: Recompiled all five shared libraries from the exact pinned llama.cpp sources using NDK r28; the AAR and packaged APK verify at `PT_LOAD Align = 0x4000`.
- [ ] **Native 16 KB Runtime Validation**: Install the release on an Android 15-or-newer arm64 environment where `getconf PAGE_SIZE` is `16384`, then exercise model loading and multi-turn inference.
- [x] **Release Signing Setup**: Enforced `android/key.properties` or environment variables for release builds with Gradle validation.
- [x] **AdMob & Privacy Consent**: Integrated Google UMP consent SDK (`AdConsentService`), environment-aware AdMob unit IDs (`kReleaseMode`), PG maximum ad-content rating, and banner error collapse.
- [x] **Encrypted Local Storage**: Implemented authenticated AES-256-GCM storage (`conversations.v2.enc`) with secure key storage, atomic legacy migration, and data purge action.
- [x] **AI Safety & Reporting**: Added the in-app Report dialog and red-team safety evaluation. Reports are prepared as user-reviewable emails addressed to `finn_org@proton.me`.
- [x] **Production Features**: The obsolete microphone and Models navigation are removed; Creations, You, and Skills are implemented, persisted locally, and covered by widget/store tests.
- [x] **Legal & Attribution**: Published `PRIVACY_POLICY.md`, `TERMS_OF_USE.md`, `THIRD_PARTY_NOTICES.md`, dynamic versioning, and open-source licence viewer.
- [x] **CI & Release Verification**: Added `.github/workflows/ci.yml`, `tool/verify_release.sh`, and fail-closed `tool/build_play_release.sh`.
- [x] **Store Copy & app-ads.txt Source**: Added reviewed English listing copy plus the AdMob publisher declaration and crawler rules under `store-listing/`.
- [x] **Public Website**: Privacy, terms, support, `app-ads.txt`, and crawler
  rules are deployed on `https://finn-org.vercel.app` from the separate
  `Finn-Technologies/landing-page` repository.

---

## Part B: Manual Google Play Console Steps

Follow these steps in the [Google Play Console](https://play.google.com/console):

### 1. App Setup & Listing
- [ ] **App Name**: Use `Finn AI: Local AI Assistant`.
- [ ] **Descriptions**: Copy the reviewed text from `store-listing/en-US/listing.md`.
- [ ] **App Category**: Productivity.
- [ ] **Graphics Assets**:
  - [x] App Icon: `store-listing/icon-512.png`.
  - [x] Feature Graphic: `store-listing/feature-graphic-1024x500.png`.
  - [x] Phone Screenshots: three verified 1080 × 1920 images under
    `store-listing/`.
- [ ] **Developer Website**: Enter `https://finn-org.vercel.app`.
- [x] **Support Contact**: Use `finn_org@proton.me`.

### 2. Privacy Policy & Data Safety
- [x] **Privacy Policy Hosting**: Public URL verified at
  `https://finn-org.vercel.app/privacy`.
- [x] **Terms Hosting**: Public URL verified at
  `https://finn-org.vercel.app/terms`.
- [ ] **Data Safety Questionnaire**: Fill out using `docs/DATA_SAFETY_DRAFT.md`.
- [ ] **Advertising ID Declaration**: Declare that the app uses Advertising ID for AdMob ads and UMP consent.
- [ ] **Ads Declaration**: Select **Yes, my app contains ads**.
- [ ] **Target Audience and Content**: Select the actual intended age groups.
  The SDK flags remain unspecified until this publisher-owned choice is made;
  update them before release if the app is child-directed or includes users
  under the applicable age of consent.
- [ ] **Content Rating**: Complete the questionnaire truthfully for an
  unrestricted generative AI assistant and advertising.
- [ ] **Generative AI Reporting**: On a physical device with a configured mail
  client, report a generated response and verify the addressed email arrives at
  `finn_org@proton.me` before uploading production.

### 3. Closed Testing Track Setup
- [ ] **Create Closed Testing Track**: Create a new Closed Testing track named `Alpha Testing` or `Closed Beta`.
- [ ] **Upload App Bundle (AAB)**: Build and upload `build/app/outputs/bundle/release/app-release.aab`.
- [ ] **Add Testers**: For personal developer accounts created after
  November 13, 2023, keep at least **12 testers opted in continuously for 14
  days** before applying for production access.
- [ ] **Submit for Review**: Send build to Google for Closed Testing review.

### 4. AdMob Launch
- [x] **Host verification**:
  `https://finn-org.vercel.app/app-ads.txt` and `/robots.txt` return HTTP 200.
- [ ] **Verify Ownership**: Link the same developer website in the Play listing,
  then wait for AdMob's app-ads.txt status to show **Verified**.
- [ ] **App Readiness**: Link the live Play listing to the AdMob app and complete
  AdMob app-readiness review. New apps do not fully serve ads until verification
  and approval.
- [ ] **Privacy Message**: Publish a production European regulations message in
  AdMob Privacy & messaging and verify **Privacy choices** appears when required.

### 5. Final Production Build
- [ ] Configure the permanent Play upload key in `android/key.properties` or
  the four supported `KEYSTORE_*` environment variables.
- [ ] **Back up the keystore and `key.properties`** (encrypted vault / offline
  storage, never git). If the upload key is lost, Google Play must reset it via
  support and no upload is accepted in the meantime.
- [ ] **Verify the keystore fingerprint before uploading**: run
  `./tool/export_upload_key_cert.sh` and confirm the printed SHA1 matches the
  upload key certificate registered in Play Console (Setup > App signing >
  Upload key). A mismatch is rejected at upload time with a "signed with the
  wrong key" error.
- [x] **Upload key reset handoff**: the upload key reset is **in progress** —
  the new keystore (`android/release-keystore.jks`, alias `finn`) is
  configured, its certificate (`build/upload-key-cert.pem`, SHA1
  `DF:D5:96:…:7B:A3`) was submitted to Google Play for the reset, and we are
  waiting for Play's confirmation before building/uploading. Follow
  `docs/UPLOAD_KEY_RESET.md` for the remaining steps (verify fingerprint,
  bump versionCode, build AAB, upload).
- [ ] Confirm all four default `finn-org.vercel.app` routes are live; override
  them only for a deliberate alternate environment.
- [ ] Run `./tool/build_play_release.sh`. Do not upload an AAB produced by
  `tool/verify_release.sh`; that verifier intentionally uses a temporary key.
- [ ] Upload the generated AAB and use Play's pre-launch report before rollout.
