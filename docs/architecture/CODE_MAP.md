# Code map — "to change *X*, edit *Y*"

**Engine layout.** `lib/src/engine/finn_accelerator.dart` holds the state and the public shape of the
engine (fields, statics, `_setStatus`). Its behaviour lives in `part` files, each an `extension` on
`FinnAccelerator`: `install/` (install lifecycle), `download/` (artifact, service + Dart downloads,
progress, artifact helpers), `loader/` (model loader, residency, model files, device optimiser),
`generate/` (reply API, one turn, prompt rendering, cancellation, reply gate), `session/` (KV session
preparation and key). Statics are referenced as `FinnAccelerator.<name>` inside a part.

Use this before grepping. Paths are relative to the repository root.

## Model system (see also `MODEL_PIPELINE.md`)

| To change… | Edit |
|---|---|
| Which model is downloaded (name, file, URL, size, sha) | `lib/src/engine/catalog/model_catalog.dart` (`finnModels`, `finnMmproj`) |
| The model name shown in the UI | `lib/l10n/app_*.arb` → `onboardingInstall*`, `settingsModelArchitectureValue`, then `flutter pub get` |
| Download / resume / retry / stall handling | `lib/src/engine/download/artifact.dart` (`_ensureDownloaded`), `download/service_download.dart` (`_ensureArtifactWithService`), `download/dart_download.dart` (`_downloadSegmented`, `_downloadSingleStream`) |
| Android-side transfer (segments, foreground notification) | `android/app/src/main/kotlin/com/abhiflex/finnai/ModelDownloadService.kt` |
| Integrity checks (size, GGUF magic, SHA-256) | `lib/src/engine/loader/model_files.dart` (`_isVerifiedModelFile`, `_looksLikeGguf`), `download/artifact.dart` (`_verifyPromotedArtifact`) |
| Disk-space pre-checks | `lib/src/engine/install/install_lifecycle.dart` (`install`), `download/artifact.dart` (`_ensureDownloaded`), `loader/model_files.dart` (`installMmproj`) |
| What upgrades delete | `finn_accelerator.dart` (`_retiredModelFiles`), `lib/src/engine/loader/model_files.dart` (`_removeRetiredModelArtifacts`) |
| Model storage location | `lib/src/engine/loader/model_files.dart` (`_createModelDirectory` → app support dir `/models`) |

## Inference

| To change… | Edit |
|---|---|
| Threads, batch, context, KV type, flash attention | `lib/src/engine/profiler/device_profile.dart` (`DeviceProfiler.plan`) |
| Backend/accelerator selection and caching | `lib/src/engine/adaptive/adaptive.dart` |
| Engine spawn parameters / multimodal wiring | `lib/src/engine/loader/model_loader.dart` (`_loadModel`, `spawnWith`) |
| Post-download device optimisation | `lib/src/engine/loader/device_optimizer.dart` (`optimizeForDevice`) |
| When the model is unloaded | `lib/src/engine/loader/residency.dart` (`releaseMemory`), `loader/model_files.dart` (`_queueUnload`) + `lib/src/engine/policy/residency_policy.dart` |
| System prompt and chat template | `lib/src/engine/prompt/prompt_formatter.dart` |
| Intent classification / output budgets / search gating | `lib/src/engine/prompt/prompt_intent.dart` |
| Which llama.cpp API surface the app sees | `lib/src/engine/backends/llama_shim.dart` (the only `llama_cpp_dart` importer) |
| Latency instrumentation | `lib/src/engine/metrics/ttft_metrics.dart` |

## Chat

| To change… | Edit |
|---|---|
| Chat screen state and `build` | `lib/src/features/chat/home_shell.dart` |
| Message bubbles, replies, sources, dialogs | `lib/src/features/chat/widgets/` (`bubbles.dart`, `replies.dart`, `sources.dart`, `dialogs.dart`, `conversation.dart`) |
| Composer | `lib/src/features/chat/widgets/composer.dart` |
| Sidebar | `lib/src/features/chat/widgets/sidebar.dart`, `sidebar_tiles.dart` |
| Send / stop / regenerate / continue behaviour | `lib/src/features/chat/shell/send.dart` (`_send`, `_regenerateReply`, `_continueReply`), `shell/navigation.dart` (`_stopReply`) + `chat_generation_controller.dart` |
| Streaming, cancellation, persistence of a turn | `lib/src/features/chat/chat_generation_controller.dart` |
| Conversation storage format / encryption / history limits | `lib/src/features/conversations/conversation_store.dart` |
| Attachment picking (camera / photos / files) | `lib/src/features/chat/shell/attachments.dart` (`_pickFromCamera`, `_pickFromGallery`, `_pickFromFileSystem`) |
| Selected-text share ("Ask Finn AI") | `android/…/MainActivity.kt` + `lib/src/features/chat/shell/selected_text.dart` (`selectedTextPrompt`), `shell/lifecycle.dart` (`_handleIncomingProcessText`) |
| Markdown rendering of replies | `lib/src/shared/widgets/safe_markdown_text.dart` |

## Web grounding

| To change… | Edit |
|---|---|
| When a query triggers a search (and why) | `lib/src/features/search/search_policy.dart` (`WebSearchPolicy.reasonFor`, `SearchPlanReason`) and `search_turn.dart` (`SearchPlanner.plan`) |
| How a query is cleaned / which endpoints are used | `lib/src/features/search/web_search_service.dart` (`_cleanSearchQuery`, `search`) |
| The one search a turn gets (budget, failure note) | `lib/src/features/search/search_turn.dart` (`SearchTurn.run`, `defaultBudget`) |
| Where chat runs the search for send / continue / regenerate / edit | `lib/src/features/chat/shell/send.dart` (`_groundTurn`) |
| Turning search results into prompt context | `lib/src/features/search/search_agent.dart` (`groundedContextForSources`, `searchAndFetch`) |
| The search step the eval applies before the engine | `lib/main.dart` (`_groundEvalTurn`) → `engine/eval/harness.dart` (`EvalGrounder`) |

## Creations

See `docs/architecture/CREATIONS.md` for the spec DSL, the generation pipeline and the widget bridge.

| To change… | Edit |
|---|---|
| The creation screen (gallery tiles, builder transcript) | `lib/src/features/creations/creations_page.dart` |
| What a mini app may contain (the node vocabulary) | `lib/src/features/creations/spec/mini_app_spec.dart` |
| The size caps enforced on every spec | `lib/src/features/creations/spec/spec_limits.dart` |
| What the model is told to produce | `lib/src/features/creations/creation_prompts.dart` |
| Validate → repair → fallback behaviour | `lib/src/features/creations/creation_generator.dart` + `spec/spec_validator.dart` |
| The starter creation used when generation fails | `lib/src/features/creations/creation_fallbacks.dart` |
| Recovering malformed or truncated model JSON | `lib/src/features/creations/json_salvage.dart` |
| Sandboxed app expressions (the security boundary) | `lib/src/features/creations/spec/safe_expression.dart` |
| Running a mini app (state, rendering, host screen) | `lib/src/features/creations/runtime/` |
| The slide deck viewer / `.pptx` export | `lib/src/features/creations/deck/` |
| Colours for tiles and specs | `lib/src/features/creations/creation_palette.dart` |
| Stored creations, versions and migration | `lib/src/features/creations/creation_store.dart` + `creation_model.dart` |
| Home-screen widget pinning and file sharing (Dart side) | `lib/src/features/creations/home_screen_service.dart` |
| Home-screen widget rendering (Kotlin side) | `android/…/FinnHomeWidgetProvider.kt`, `FinnHomeWidgetRenderer.kt`, `FinnHomeWidgetStore.kt` |

## Apps, onboarding, settings, features

| To change… | Edit |
|---|---|
| Startup sequence, splash, routing decision | `lib/src/app/bootstrap.dart` |
| Onboarding pages, install progress, upgrade screen | `lib/src/features/onboarding/onboarding_flow.dart` |
| Settings rows, delete-all-data, licence screen | `lib/src/features/settings/settings_page.dart` |
| Global "delete all data" orchestration | `lib/src/app/app_state_store.dart` |
| Skills | `lib/src/features/flows/{flows_page,flows_store}.dart` |
| Personalization profile | `lib/src/features/you/{you_page,you_profile_store}.dart` |
| Hands-free voice | `lib/src/features/voice/{voice_sheet,voice_chat_controller,voice_settings_store}.dart` |
| Report-an-answer dialog + backend | `lib/src/features/reporting/` |
| Legal URLs / licence text | `lib/src/shared/config/{legal_config,licenses}.dart` |

## Shared UI

| To change… | Edit |
|---|---|
| Colors, radii, text theme, system UI overlays | `lib/src/shared/theme/flux_theme.dart` |
| Buttons, pills, icon registry (`FluxIcons`), glass surfaces | `lib/src/shared/widgets/flux_controls.dart` |
| Page header used by every sub-page | `lib/src/shared/widgets/finn_page_header.dart` |
| Long-press context menu | `lib/src/shared/widgets/flux_context_menu.dart` |
| App background | `lib/src/shared/widgets/ambient_background.dart` |

## Platform & tooling

| To change… | Edit |
|---|---|
| Android manifest, permissions, PROCESS_TEXT alias | `android/app/src/main/AndroidManifest.xml` |
| Android host + method channels | `android/app/src/main/kotlin/com/abhiflex/finnai/MainActivity.kt` |
| Android home-screen widget + share bridge | `android/…/FinnHomeScreenBridge.kt` (+ the manifest receiver/provider and `proguard-rules.pro`) |
| OpenHarmony path handling | `lib/src/platform/openharmony_path_provider.dart` |
| Page transition used by every sub-page | `lib/src/features/chat/widgets/sources.dart` (`FinnPageRoute`) |
| Engine-seam CI gate | `tool/verify_engine_seam.sh` |
| Release verification | `tool/verify_release.sh`, `tool/build_play_release.sh` |
| CI pipeline | `.github/workflows/ci.yml`, `.github/workflows/release.yml` |

## Tests

`test/` mirrors `lib/`: `test/engine/`, `test/features/`, `test/app/`. `test/flutter_test_config.dart`
and `test/flux_golden_test.dart` must stay at the `test/` root (they resolve `goldens/` relatively).
See `docs/guides/TESTING.md`.
