# FinnAI Google Play Release Readiness Status Report

This document records the exact completion and verification status of all release readiness items for the `release/google-play-readiness` branch.

---

## Technical Audit & Verification Summary

| Feature / Workstream | Implementation Status | Verification Status | Notes / Blockers |
|---|---|---|---|
| **Android Application ID** | `COMPLETE` | `VERIFIED` | Confirmed `com.abhiflex.finnai` across `build.gradle.kts`, `namespace`, `applicationId`, and `MainActivity.kt`. |
| **Custom Launcher Icon** | `COMPLETE` | `VERIFIED` | Custom FinnAI launcher icon packaged in `mipmap-anydpi-v26/ic_launcher.xml` and density folders. |
| **Native llama.cpp AAR** | `COMPLETE` | `VERIFIED (Nord + static) / 16 KB RUNTIME PENDING` | Rebuilt all five arm64 libraries from the exact pinned `llama_cpp_dart` and `llama.cpp` sources with NDK r28. Multi-turn generation passed on a OnePlus Nord. APK/AAB are ARM64-only and every packaged ELF has at least `0x4000` `PT_LOAD` alignment. A runtime test on a 16 KB kernel remains required. |
| **Runtime SVG Assets** | `COMPLETE` | `VERIFIED` | All 20 required Figma icons copied to `assets/runtime/` and verified via `test/asset_verification_test.dart`. |
| **AES-256-GCM Encryption** | `COMPLETE` | `VERIFIED` | Replaced custom crypto with maintained `cryptography` package. Verified roundtrips, tampered tag detection, key persistence, and atomic legacy migration in `test/conversation_store_test.dart`. |
| **Truthful AI Reporting** | `COMPLETE` | `VERIFIED (App + Backend tests) / STORAGE CONFIG PENDING` | The canonical Vercel Function is deployed from `Finn-Technologies/landing-page` and stores reports in Upstash Redis for 30 days. Production health remains fail-closed until the three Vercel environment variables are configured. |
| **System Safety Prompts** | `COMPLETE` | `VERIFIED (Templates + observed output)` | Applied the compact `finnSafetySystemPrompt` to all tiers and modes. Automated template tests pass and user-visible generation was observed on the physical Nord after correcting Qwen 3 non-thinking priming. |
| **Creations, You & Skills** | `COMPLETE` | `VERIFIED` | Persistent local creation generation, personalization, response styles, built-in/custom Skills, private inference-context integration, responsive screens, and deletion coverage. |
| **Delete All Local Data** | `COMPLETE` | `VERIFIED` | Truthful deletion of onboarding state, encrypted history, keys, downloaded models, creations, profile preferences, and Skills. Returns `DeletionResult` with error reporting. Verified in `test/app_state_store_test.dart`. |
| **Legal & Privacy Disclosures** | `COMPLETE` | `VERIFIED` | The app defaults to public privacy, terms and support routes on `finn-org.vercel.app`; compile-time overrides remain available. `THIRD_PARTY_NOTICES.md` includes full licences. |
| **AdMob UMP & Banner Layout** | `COMPLETE` | `VERIFIED` | UMP consent callbacks have timeout protection. Google Mobile Ads 9.x is configured with a PG maximum content rating. Ads are limited to stable Settings, settled sidebar, and idle Creations placements. The sidebar native view is mounted only after opening completes and disposed before closing begins; every placement collapses while unconsented or generating. Chat, onboarding, You, and Skills stay ad-free. |
| **Verification & CI** | `COMPLETE` | `VERIFIED` | `tool/verify_release.sh` updated with `set -euo pipefail` and truthful failure logging. CI workflow updated in `.github/workflows/ci.yml`. Release signing gate verified in `test/release_signing_gate_test.dart`. |

---

## Release Blockers & Manual Action Required Before Production Launch

1. **16 KB Runtime Validation**:
   - Static compatibility is complete: all source-built llama/ggml libraries
     and the packaged release APK pass 16 KB alignment verification.
   - Run the release on an Android 15-or-newer arm64 environment where
     `adb shell getconf PAGE_SIZE` returns `16384`.
   - Exercise model load, multi-turn generation, download resume, mmap, and
     memory-pressure behavior before production.

2. **Vercel Reporting Storage Configuration**:
   - Connect an Upstash Redis database to the landing-page Vercel project.
   - Configure `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`, and a
     strong `RATE_LIMIT_SALT` for Production.
   - Confirm `https://finn-org.vercel.app/health` returns `{"status":"ok"}`.

3. **Production Signing Keystore**:
   - Configure `android/key.properties` with production upload key credentials before generating final release AAB for Google Play Console.

4. **Play Support Email**:
   - The public support page is configured in-app. Select a separate real,
     monitored email address for the required Play Console support-email field.

5. **AdMob Verification and Publisher Declarations**:
   - Publish `store-listing/app-ads.txt` at the developer website root and link
     that website from the Play listing.
   - Complete AdMob app readiness and publish the required UMP privacy message.
   - Choose the real Play target audience. FinnAI intentionally does not guess
     child-directed or under-age-of-consent flags in code.

6. **Store Graphics and Account-Gated Testing**:
   - Capture final phone screenshots and create the 1024 × 500 feature graphic
     after the production identity and website are final.
   - New personal Play accounts created after November 13, 2023 must complete a
     closed test with at least 12 continuously opted-in testers for 14 days.
