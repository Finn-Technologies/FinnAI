# FinnAI - On-Device AI Assistant for Android

FinnAI is a private, on-device AI assistant built with Flutter, powered by local open-source Prism ML Bonsai GGUF models and `llama.cpp`.

Package Identifier: `com.abhiflex.finnai`

---

## Key Features

- **On-Device Local Inference**: Powered by Prism ML Bonsai GGUF models (`Bonsai 1.7B`, `Bonsai 4B`, `Bonsai 8B`) running via C++ native binaries on worker isolates.
- **AES-256-GCM Encrypted Storage**: Conversations are protected using AES-256-GCM authenticated encryption (`package:cryptography`) with master keys secured in Android KeyStore (`FlutterSecureStorage`).
- **AdMob Privacy & UMP Consent**: Integrated Google User Messaging Platform (UMP) SDK. Banner ads collapse cleanly to 0 height (`SizedBox.shrink()`) when unconsented or inactive.
- **AI Safety & Report Action**: In-app AI response reporting system (`ReportDialog`) with category classification and prompt inclusion controls. Reporting is disabled until a production endpoint (`FINN_REPORT_ENDPOINT`) is configured.
- **Settings & Data Sovereignty**: Dynamic versioning, open-source licence viewer, interactive privacy choices, legal documents, and truthful "Delete All Local Data" action returning detailed deletion results.

---

## Repository Structure & Documentation

```text
FinnAI/
├── android/                   # Android native project (com.abhiflex.finnai)
├── assets/                    # Assets and launcher icons
├── docs/                      # Technical & release documentation
│   ├── PLAY_RELEASE_READINESS.md          # Master Play Store release checklist
│   ├── NATIVE_16KB_VERIFICATION.md         # 16 KB ARM64 ELF alignment verification (BLOCKED)
│   ├── SECURITY_AND_PRIVACY_ARCHITECTURE.md # Security & AES-256-GCM encryption design
│   ├── DATA_SAFETY_DRAFT.md               # Google Play Data Safety section questionnaire draft
│   ├── PLAY_CONSOLE_CHECKLIST.md          # Manual Play Console submission steps
│   ├── AI_SAFETY_TESTING.md               # Red-team safety test matrix
│   └── REPORTING_BACKEND.md               # Serverless reporting endpoint deployment guide
├── legal/                     # Legal policies
│   ├── PRIVACY_POLICY.md
│   └── TERMS_OF_USE.md
├── lib/                       # Flutter / Dart application source code
├── reporting-service/         # Cloudflare Worker backend for AI response reports
├── test/                      # Unit & widget test suite
├── tool/                      # Verification scripts
│   └── verify_release.sh      # Complete automated release verification script
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

Build the release App Bundle:
```bash
flutter build appbundle --release \
  --dart-define=FINN_SUPPORT_EMAIL="support@yourdomain.com" \
  --dart-define=FINN_PRIVACY_POLICY_URL="https://yourdomain.com/privacy" \
  --dart-define=FINN_TERMS_URL="https://yourdomain.com/terms" \
  --dart-define=FINN_REPORT_ENDPOINT="https://reports.yourdomain.com/v1/reports"
```
