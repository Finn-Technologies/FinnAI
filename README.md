# FinnAI - On-Device AI Assistant for Android

FinnAI is a private, on-device AI assistant built with Flutter, powered by local open-source Prism ML Bonsai GGUF models and `llama.cpp`.

Package Identifier: `com.abhiflex.finnai`

---

## Key Features

- **On-Device Local Inference**: Powered by Prism ML Bonsai GGUF models (`Bonsai 1.7B`, `Bonsai 4B`, `Bonsai 8B`) running via C++ native binaries on worker isolates.
- **Authenticated Encrypted Storage**: Conversations are protected using AES-256-CTR + HMAC-SHA256 authenticated encryption with master keys secured in Android KeyStore (`FlutterSecureStorage`).
- **Google Play & Android 15 Ready**:
  - Target SDK 36, Compile SDK 36, Min SDK 26.
  - **Native 16 KB Page Alignment**: All bundled ARM64 `.so` libraries in `android/app/libs/llama-cpp-dart.aar` are compiled with 16 KB segment alignment (`-Wl,-z,max-page-size=16384`).
- **AdMob Privacy & UMP Consent**: Integrated Google User Messaging Platform (UMP) SDK. Ad requests are made only after consent is granted. Debug builds use official Google test IDs; release builds use production IDs.
- **AI Safety & Report Action**: In-app AI response reporting system (`ReportDialog`) with category classification, user prompt inclusion controls, and deployable serverless reporting backend (`reporting-service/`).
- **Settings & Data Sovereignty**: Dynamic versioning, open-source licence viewer, interactive privacy choices, legal documents, and one-tap "Delete All Local Data" action.

---

## Repository Structure & Documentation

```text
FinnAI/
├── android/                   # Android native project (com.abhiflex.finnai)
├── assets/                    # Assets and launcher icons
├── docs/                      # Technical & release documentation
│   ├── PLAY_RELEASE_READINESS.md          # Master Play Store release checklist
│   ├── NATIVE_16KB_VERIFICATION.md         # 16 KB ARM64 ELF alignment verification
│   ├── SECURITY_AND_PRIVACY_ARCHITECTURE.md # Security & AES-256-CTR encryption design
│   ├── DATA_SAFETY_DRAFT.md               # Google Play Data Safety section questionnaire draft
│   ├── PLAY_CONSOLE_CHECKLIST.md          # Manual Play Console submission steps
│   ├── AI_SAFETY_TESTING.md               # Red-team safety test matrix
│   └── REPORTING_BACKEND.md               # Serverless reporting endpoint deployment guide
├── legal/                     # Legal policies
│   ├── PRIVACY_POLICY.md / .html
│   └── TERMS_OF_USE.md / .html
├── lib/                       # Flutter / Dart application source code
├── reporting-service/         # Node.js serverless backend for AI response reports
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

### 2. Run Locally (Debug)
```bash
flutter run
```

### 3. Run Static Analysis & Tests
```bash
flutter analyze
flutter test
```

### 4. Run Automated Release Verification
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
flutter build appbundle --release
```

The output bundle will be generated at `build/app/outputs/bundle/release/app-release.aab`.
