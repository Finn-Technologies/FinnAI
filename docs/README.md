# FinnAI documentation

Index of everything under `docs/`. If you are an agent, read
[../AGENTS.md](../AGENTS.md) first — it holds the hard constraints.

## architecture/

| Document | Covers |
|---|---|
| [OVERVIEW.md](architecture/OVERVIEW.md) | Layers, dependency direction, and the end-to-end path of one user message |
| [CODE_MAP.md](architecture/CODE_MAP.md) | "To change *X*, edit *Y*" lookup table |
| [MODEL_PIPELINE.md](architecture/MODEL_PIPELINE.md) | The model lifecycle: catalog → download → verify → load → infer → delete |
| [CHAT_GENERATION_ARCHITECTURE.md](architecture/CHAT_GENERATION_ARCHITECTURE.md) | Generation controller, stream lifecycle, cancellation |
| [TTFT_ARCHITECTURE.md](architecture/TTFT_ARCHITECTURE.md) | Time-to-first-token tracing and what each phase measures |
| [SECURITY_AND_PRIVACY_ARCHITECTURE.md](architecture/SECURITY_AND_PRIVACY_ARCHITECTURE.md) | AES-256-GCM storage, key handling, egress boundaries |
| [ENGINE_ROADMAP.md](architecture/ENGINE_ROADMAP.md) | Plan for extracting the engine into its own package |

## guides/

| Document | Covers |
|---|---|
| [BUILD.md](guides/BUILD.md) | Toolchain setup, known SDK errors, build commands |
| [TESTING.md](guides/TESTING.md) | Test layout, golden tests, device testing |
| [RELEASE.md](guides/RELEASE.md) | Play Store release checklist |
| [OHOS_BUILD.md](guides/OHOS_BUILD.md) | OpenHarmony toolchain and build |
| [I18N.md](guides/I18N.md) | ARB workflow and localization rules |
| [NATIVE_16KB_VERIFICATION.md](guides/NATIVE_16KB_VERIFICATION.md) | 16 KB ELF page-alignment provenance |

## reference/

| Document | Covers |
|---|---|
| [ENGINE_API.md](reference/ENGINE_API.md) | The engine facade contract |
| [PERFORMANCE_VALIDATION.md](reference/PERFORMANCE_VALIDATION.md) | On-device benchmark numbers |
| [ASSETS_RUNTIME.md](reference/ASSETS_RUNTIME.md) | Runtime asset inventory |
| [GLOSSARY.md](reference/GLOSSARY.md) | Domain terms used across these docs |

## operations/

Runbooks and store-submission paperwork: [AI_SAFETY_TESTING.md](operations/AI_SAFETY_TESTING.md),
[DATA_SAFETY_DRAFT.md](operations/DATA_SAFETY_DRAFT.md),
[PLAY_CONSOLE_CHECKLIST.md](operations/PLAY_CONSOLE_CHECKLIST.md),
[UPLOAD_KEY_RESET.md](operations/UPLOAD_KEY_RESET.md),
[REPORTING_BACKEND.md](operations/REPORTING_BACKEND.md).

## legal/

[PRIVACY_POLICY.md](legal/PRIVACY_POLICY.md) and [TERMS_OF_USE.md](legal/TERMS_OF_USE.md).
The app links to hosted copies configured through `FINN_PRIVACY_POLICY_URL` / `FINN_TERMS_URL`.

## Other folders

- `design/` — Figma exports used as visual reference.
- `store/` — Play Store listing copy and graphics.
- `media/` — demo recordings.
