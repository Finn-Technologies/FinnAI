# FinnAI - On-Device AI Assistant for Android and OpenHarmony

FinnAI is a private, on-device AI assistant with low-latency offline inference built with Flutter, powered by our custom **FinnAI-Accelerator** native inference runtime and the **LFM2.5-VL 1.6B** model by Liquid AI (GGUF weights downloaded from Hugging Face at runtime).

Package Identifier: `com.abhiflex.finnai`

---

## Key Features

- **⚡ FinnAI-Accelerator**: High-performance C++ and Dart FFI on-device inference runtime running on dedicated worker isolates with cancellable streams. The engine also exposes llama.cpp lookahead sampling (`lookaheadWindow`) for tuning multi-token prediction.
- **🔍 Hardware-Adaptive Topology**: Detects CPU core clusters and asymmetric architectures (big.LITTLE). Automatically pins decode loops to fast performance cores (e.g. 2 cores on entry chips, 4 on balanced/flagship) to eliminate cross-cluster barrier synchronization stalls.
- **🛡️ Multi-Tier Device Optimization**: Seamless, crash-free execution from 3GB entry tablets (e.g., Samsung Galaxy Tab A8 / Unisoc T618) to high-end 8GB+ smartphones (Snapdragon 7+ Gen 3 / Dimensity 7025 / Snapdragon 8 series).
- **📦 Compact KV Cache & TurboQuant Ready**: Supports compact `Q8_0`, `Q4_0`, and `TurboQuant 2-Bit/3-Bit` KV-cache configurations, shrinking KV memory consumption to roughly **32–64 MB** even on long multi-turn chats (see `docs/PERFORMANCE_VALIDATION.md`).
- **🔒 AES-256-GCM Encrypted Storage**: Conversations are protected using AES-256-GCM authenticated encryption (`package:cryptography`) with master keys secured in Android KeyStore (`FlutterSecureStorage`).
- **🎨 Creations & Skills**: Generates structured documents, widgets, and app concepts on device. Custom skills and local personalization feed a private system context.
- **📎 Attachments**: Supports selected image and text/document attachments when the local runtime can process them; unsupported files are rejected.
- **📊 Time-to-First-Token (TTFT) Telemetry**: Monotonic latency tracking and token generation rate telemetry without leaking prompt contents.
- **🚨 AI Safety & Honest Reporting**: In-app safety report action opening a transparent, user-reviewable email addressed to `finn_org@proton.me`.
- **🗑️ Complete Data Sovereignty**: Truthful "Delete All Local Data" action with instant cache and encrypted storage purging.

---

## Repository Structure

```text
FinnAI/
├── android/                   # Android native project (com.abhiflex.finnai, 16KB ELF aligned)
├── ohos/                      # OpenHarmony native project
├── assets/                    # Fonts, icons, and runtime assets
├── docs/                      # Technical & release documentation (see full list below)
├── legal/                     # Legal policies
│   ├── PRIVACY_POLICY.md
│   └── TERMS_OF_USE.md
├── lib/                       # Flutter Application Source
│   ├── src/
│   │   ├── engine/            # ⚡ FinnEngine compatibility/export layer
│   │   ├── inference/         # 🧠 Local model runtime, profiling, and routing
│   │   ├── conversations/     # 🔒 Encrypted local chat persistence
│   │   ├── home/              # 💬 Chat shell and attachments
│   │   ├── creations/         # 🎨 Structured local creations
│   │   ├── skills/            # 🧩 Built-in and custom skills
│   │   ├── you/               # 👤 Local personalization
│   │   ├── search/            # 🌐 Best-effort optional web grounding
│   │   ├── openharmony/       # 🔧 OpenHarmony platform adaptations
│   │   └── flux_app.dart      # Application bootstrap
│   └── main.dart
├── store-listing/             # Play listing copy and store graphics
├── test/                      # Unit, widget, and architecture test suite
├── tool/                      # Build & verification scripts
│   ├── verify_release.sh      # Automated release verification
│   └── build_play_release.sh  # Production AAB builder
└── THIRD_PARTY_NOTICES.md     # Open-source license attribution notices
```

### Documentation Tree (`docs/`)

| Document | Purpose |
|---|---|
| `docs/AI_SAFETY_TESTING.md` | Red-team safety test matrix |
| `docs/ARCHITECTURE_STATUS.md` | Implemented vs partial vs planned architecture status |
| `docs/CHAT_GENERATION_ARCHITECTURE.md` | Generation coordinator & stream lifecycle |
| `docs/DATA_SAFETY_DRAFT.md` | Google Play Data Safety section questionnaire draft |
| `docs/ENGINE_API.md` | Engine seam API contract (Track 1 ↔ Track 5) |
| `docs/ENGINE_ROADMAP.md` | 12-month engine independence runway (Q1–Q4) |
| `docs/I18N.md` | Localization infrastructure and ARB workflow |
| `docs/NATIVE_16KB_VERIFICATION.md` | Source build provenance and 16 KB verification |
| `docs/PERFORMANCE_VALIDATION.md` | Physical on-device benchmark telemetry |
| `docs/PLAY_CONSOLE_CHECKLIST.md` | Manual Play Console submission steps |
| `docs/PLAY_RELEASE_READINESS.md` | Master Play Store release checklist |
| `docs/REPORTING_BACKEND.md` | Legacy/optional reporting endpoint design |
| `docs/SECURITY_AND_PRIVACY_ARCHITECTURE.md` | Security & AES-256-GCM encryption design |
| `docs/TTFT_ARCHITECTURE.md` | Time-to-first-token measurement architecture |
| `docs/UPLOAD_KEY_RESET.md` | Play upload-key reset handoff runbook |

For the current implementation boundary and migration status, see `docs/ARCHITECTURE_STATUS.md`.

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

## Building for Android (Google Play Release)

To build a release Android App Bundle (AAB), configure release signing in `android/key.properties`:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=/absolute/path/to/upload-keystore.jks
```

Build the release bundle with environment defaults:

```bash
export FINN_SUPPORT_URL="https://finn-org.vercel.app/support"
export FINN_SUPPORT_EMAIL="finn_org@proton.me"
export FINN_REPORT_EMAIL="finn_org@proton.me"
export FINN_PRIVACY_POLICY_URL="https://finn-org.vercel.app/privacy"
export FINN_TERMS_URL="https://finn-org.vercel.app/terms"

./tool/build_play_release.sh
```

FinnAI ships an ARM64 native inference runtime. Release bundles are strictly checked for 16KB ELF page alignment (Android 15+ compatible) and validated against Google Play production gates.

---

## Building for OpenHarmony

FinnAI also targets OpenHarmony. See `docs/OHOS_BUILD.md` for the toolchain
prerequisites, environment setup, and build/run instructions for the `ohos/`
project.
