# FinnAI - On-Device AI Assistant for Android

FinnAI is a private, on-device AI assistant built with Flutter, powered by the local open-source Qwen 3.5 2B GGUF model and `llama.cpp`.

Package Identifier: `com.abhiflex.finnai`

---

## Key Features

- **On-Device Local Inference**: Powered by the Qwen 3.5 2B GGUF model running via C++ native binaries on worker isolates.
- **Hardware-Adaptive Runtime**: Device profiling tunes context size, thread counts, and KV-cache compression for smooth on-device generation.
- **Creations**: Generates and stores structured app, widget, and presentation concepts entirely on device.
- **You & Skills**: Local personalization, response-style controls, built-in capabilities, and reusable custom instructions feed a private system context.
- **AES-256-GCM Encrypted Storage**: Conversations are protected using AES-256-GCM authenticated encryption (`package:cryptography`) with master keys secured in Android KeyStore (`FlutterSecureStorage`).
- **AdMob Privacy & UMP Consent**: Integrated Google User Messaging Platform (UMP) SDK. Banner ads collapse cleanly to 0 height (`SizedBox.shrink()`) when unconsented or inactive.
- **AI Safety & Report Action**: In-app AI response reporting system (`ReportDialog`) with category classification and prompt inclusion controls. Reports open as complete, user-reviewable emails addressed to `finn_org@proton.me`; nothing is sent until the user confirms it in their mail app.
- **Settings & Data Sovereignty**: Dynamic versioning, open-source licence viewer, interactive privacy choices, legal documents, and truthful "Delete All Local Data" action returning detailed deletion results.
- **Responsive, Low-Overhead UI**: Instrument Sans, Figma-imported icons, reduced-motion support, lazy sidebar composition, bounded input work, and no runtime gradients or backdrop blur.

---

## Repository Structure & Documentation

```text
FinnAI/
├── android/                   # Android native project (com.abhiflex.finnai)
├── assets/                    # Assets and launcher icons
├── docs/                      # Technical & release documentation
│   ├── PLAY_RELEASE_READINESS.md          # Master Play Store release checklist
│   ├── NATIVE_16KB_VERIFICATION.md         # Source build provenance and 16 KB verification
│   ├── SECURITY_AND_PRIVACY_ARCHITECTURE.md # Security & AES-256-GCM encryption design
│   ├── DATA_SAFETY_DRAFT.md               # Google Play Data Safety section questionnaire draft
│   ├── PLAY_CONSOLE_CHECKLIST.md          # Manual Play Console submission steps
│   ├── AI_SAFETY_TESTING.md               # Red-team safety test matrix
│   ├── PERFORMANCE_VALIDATION.md            # Physical Nord inference/UI measurements
│   └── REPORTING_BACKEND.md               # Legacy optional HTTPS reporting design
├── legal/                     # Legal policies
│   ├── PRIVACY_POLICY.md
│   └── TERMS_OF_USE.md
├── lib/                       # Flutter / Dart application source code
├── store-listing/             # Play listing copy and app-ads.txt source
├── test/                      # Unit & widget test suite
├── tool/                      # Verification scripts
│   ├── verify_release.sh      # Temporary-key automated release verification
│   └── build_play_release.sh  # Fail-closed production AAB builder
└── THIRD_PARTY_NOTICES.md     # Open-source license attribution notices
```

---

## Quick Start & Development

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run Static Analysis & Tests
```bash
flutter analyze
flutter test
```

### 3. Run Automated Release Verification
```bash
./tool/verify_release.sh
```

---

## Building for Production (Google Play Release)

To build a release Android App Bundle (AAB), configure release signing in `android/key.properties`:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=/absolute/path/to/upload-keystore.jks
```

Finn AI includes production defaults for its public website:

```text
Privacy:  https://finn-org.vercel.app/privacy
Terms:    https://finn-org.vercel.app/terms
Support:  https://finn-org.vercel.app/support
Email:    finn_org@proton.me
Reports:  finn_org@proton.me
```

You may override them for another environment:

```bash
export FINN_SUPPORT_URL="https://finn-org.vercel.app/support"
export FINN_SUPPORT_EMAIL="finn_org@proton.me"
export FINN_REPORT_EMAIL="finn_org@proton.me"
export FINN_PRIVACY_POLICY_URL="https://finn-org.vercel.app/privacy"
export FINN_TERMS_URL="https://finn-org.vercel.app/terms"

./tool/build_play_release.sh
```

FinnAI currently ships an ARM64 native inference runtime, so Play artifacts
must remain ARM64-only. `tool/verify_release.sh` rejects accidental extra ABIs.
The production builder also rejects missing values, non-HTTPS URLs, reserved
`.invalid` domains, missing signing material, or any failed release check.

Before launch, host `store-listing/app-ads.txt` at the root of the developer
website linked from the Play listing. Complete the remaining publisher-owned
steps in `docs/PLAY_CONSOLE_CHECKLIST.md`.

The production builder requires a valid `FINN_REPORT_EMAIL`. The app opens a
complete pre-addressed report in the user's mail client; it never embeds mail
credentials or claims delivery before the user presses Send.
