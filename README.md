# FinnAI

**A private, on-device AI assistant for Android, OpenHarmony and desktop Linux.**

FinnAI runs one language model entirely on your device — no server, no account, no cloud
inference. The Flutter UI sits on top of **FinnAI-Accelerator**, a native llama.cpp runtime, and
runs **LFM2.5-VL 1.6B (Q4_0)** with its SigLIP2 vision projector. Weights are downloaded once from
Hugging Face and never leave the device.

- **Package id:** `com.abhiflex.finnai`
- **Platforms:** Android (primary), OpenHarmony, Linux desktop (x86-64 / arm64; see [docs/guides/LINUX.md](docs/guides/LINUX.md))
- **Model:** LFM2.5-VL 1.6B Q4_0 + `mmproj-LFM2.5-VL-1.6b-F16` vision projector (≈1.55 GB total), plus the on-device speech model for voice mode (Whisper base + Silero VAD, ≈161 MB) and spoken replies (Supertonic 3 voice, ≈398 MB, 31 languages), all downloaded with it

---

## What it does

| Capability | Where |
|---|---|
| Offline chat with streaming replies | `lib/src/features/chat/` |
| One-time model download with resume + SHA-256 verification | `lib/src/engine/` |
| Encrypted (AES-256-GCM) conversation history | `lib/src/features/conversations/` |
| Image understanding via the vision projector | `lib/src/engine/`, `lib/src/features/chat/` |
| Optional web grounding (explicit, per-query) | `lib/src/features/search/` |
| Skills, personalization, creations, hands-free voice | `lib/src/features/{skills,you,creations,voice}/` |
| FinnAI Code: a coding agent with its own terminal, writing, editing and running projects in a real Alpine Linux on Android (proot: packages, git, compilers, network; ADR 0012) or an emulated Linux elsewhere, on the on-device model or your own OpenRouter / Command Code / OpenCode Zen / OpenCode Go / OpenAI-compatible key | `lib/src/features/code/` |
| Share selected text into the app ("Ask Finn AI") | `android/…/MainActivity.kt` + `chat/home_shell.dart` |

Everything user-visible is localized (EN / DE / ES / FR / IT) from `lib/l10n/app_*.arb`.

---

## Quick start

```bash
flutter pub get
flutter test                      # 220+ unit, widget and golden tests
flutter build apk --debug
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.abhiflex.finnai/.MainActivity
```

Full toolchain notes (including the OpenHarmony SDK error you may hit) are in
[docs/guides/BUILD.md](docs/guides/BUILD.md).

> **Using the OpenHarmony Flutter fork?** `flutter analyze` / `flutter test` may abort with
> *"No Hmos SDK found"*. Add `--no-pub`, or use `dart analyze .`.

---

## Documentation

Start at **[docs/README.md](docs/README.md)**. The most useful pages first:

| Document | What it covers |
|---|---|
| [AGENTS.md](AGENTS.md) | Operating contract: hard constraints, commands, common tasks |
| [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md) | How the app is layered and how a message flows end to end |
| [docs/architecture/CODE_MAP.md](docs/architecture/CODE_MAP.md) | "To change *X*, edit *Y*" |
| [docs/architecture/MODEL_PIPELINE.md](docs/architecture/MODEL_PIPELINE.md) | Download → verify → load → infer, with log tags |
| [docs/guides/TESTING.md](docs/guides/TESTING.md) | Test layout, golden tests, device testing |
| [docs/guides/RELEASE.md](docs/guides/RELEASE.md) | Store release checklist |
| [docs/reference/GLOSSARY.md](docs/reference/GLOSSARY.md) | Domain terms (`KV cache`, `mmproj`, `TTFT`, …) |

Agent skills for common workflows live in [`.agents/skills/`](.agents/skills).

---

## Repository layout

```text
FinnAI/
├── lib/            Flutter app (see lib/src/{app,features,engine,inference,shared,platform})
├── test/           Mirrors lib/ (+ goldens/ and flutter_test_config.dart at the root)
├── android/        Android host project, download service, PROCESS_TEXT integration
├── ohos/           OpenHarmony host project
├── third_party/    Vendored llama_cpp_dart FFI bindings (excluded from analysis)
├── assets/         Fonts, icons, runtime assets
├── tool/           Build + verification scripts
└── docs/           architecture/ guides/ reference/ operations/ legal/ design/ store/
```

---

## Building a release

Configure signing in `android/key.properties`, then:

```bash
export FINN_SUPPORT_URL="https://finn-org.vercel.app/support"
export FINN_SUPPORT_EMAIL="finn_org@proton.me"
export FINN_REPORT_EMAIL="finn_org@proton.me"
export FINN_PRIVACY_POLICY_URL="https://finn-org.vercel.app/privacy"
export FINN_TERMS_URL="https://finn-org.vercel.app/terms"

./tool/verify_release.sh        # signed AAB + 16 KB ELF alignment gate
```

---

## License

FinnAI is proprietary software. Third-party components — including `llama.cpp`, `ggml`,
`llama_cpp_dart`, and the LFM2.5-VL 1.6B model under the LFM Open License v1.0 — are attributed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and in the in-app licence screen.
