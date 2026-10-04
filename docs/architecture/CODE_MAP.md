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
| The panel, its scrim, the menu/close morph and the open/close swipe (shared by FinnAI and FinnAI Code) | `lib/src/shared/widgets/finn_sidebar_surface.dart` (`FinnSidebarSurface`, `FinnSidebarToggleButton`), the chat drag logic in `lib/src/features/chat/shell/sidebar_surface.dart` |
| The sidebar's circle destinations, buttons, and the history-grid card (a chat in FinnAI, a session in FinnAI Code) | `lib/src/shared/widgets/finn_sidebar_parts.dart` (`FinnSidebarHistoryTile`) |
| The brand row and its reveal (the other app's name, blurred, inline) | `lib/src/shared/widgets/finn_brand_switcher.dart` (`FinnBrandSwitcher`, `BrandExpansion` — both sidebars share one expansion value so they resize on the same frame) |
| The soft top/bottom fade over a scrolling transcript | `lib/src/shared/widgets/finn_edge_fade.dart` |
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
| News and weather sources (keyless) | `lib/src/features/search/providers/news_provider.dart`, `weather_provider.dart` (routed by `SearchPolicy.providerFor` or a `news:` / `weather:` flow step, see `chat/flow_wiring.dart`) |
| The one search a turn gets (budget, failure note) | `lib/src/features/search/search_turn.dart` (`SearchTurn.run`, `defaultBudget`) |
| Where chat runs the search for send / continue / regenerate / edit | `lib/src/features/chat/shell/send.dart` (`_groundTurn`) |
| Turning search results into prompt context | `lib/src/features/search/search_agent.dart` (`groundedContextForSources`, `searchAndFetch`) |
| The search step the eval applies before the engine | `lib/main.dart` (`_groundEvalTurn`) → `engine/eval/harness.dart` (`EvalGrounder`) |

## Flows (automations)

A flow is a tree of blocks (ask, web, notify, speak, action, wait, branch, save-to-chat, stop) plus triggers and "only if" conditions. Rules: `lib/src/features/flows/AGENTS.md`; decision: `docs/decisions/0009-flows-v3.md`.

| To change… | Edit |
|---|---|
| The flow, its triggers and block data model | `lib/src/features/flows/{flow_model,flow_blocks,flow_triggers,flow_conditions}.dart` |
| The run log (holds no model text) | `lib/src/features/flows/flow_run_log.dart` |
| Saving and loading flows | `lib/src/features/flows/{flows_store,flows_codec}.dart` |
| How a run executes blocks (grounding, stop rules, the three-place grant rule, background runs) | `lib/src/features/flows/flow_runner.dart` |
| What a flow may reach outside itself (model, search, sink, notifier, speaker) | `lib/src/features/flows/flow_ports.dart` |
| The real implementations of those ports (engine, search, conversations) | `lib/src/features/chat/flow_wiring.dart` |
| Ready-made flows (morning brief, web check, reminder, low battery, headset) | `lib/src/features/flows/flow_templates.dart` |
| When a time trigger next fires | `lib/src/features/flows/flow_schedule.dart` (mirrored in `android/…/FlowScheduler.kt`) |
| Arming alarms and event triggers, notification permission | `lib/src/features/flows/flow_scheduler.dart` + `android/…/{FlowScheduler,FlowTriggerStore,FlowTriggerService,FlowDispatcher,FlowChannels}.kt` |
| Device conditions (battery, charging, headset, Wi-Fi) | `lib/src/features/flows/flow_environment.dart` + `android/…/FlowEnvironmentBridge.kt` |
| Runs with the app closed (headless engine) | `lib/flow_background.dart` + `android/…/FlowBackgroundRunner.kt` |
| Tap-a-notification-to-run, trigger sync at startup | `lib/src/features/chat/shell/flows.dart` |
| A flow told in a sentence (phrases, line DSL, model fallback) | `lib/src/features/flows/{flow_phrases,flow_script,flow_author,flow_intent}.dart` |
| The Flows list and filters | `lib/src/features/flows/flows_page.dart` |
| The flowchart editor and its sheets | `lib/src/features/flows/{flow_editor_page,flow_chart,flow_edit,flow_trigger_sheet,flow_condition_sheet,flow_block_sheet,flow_schedule_sheet}.dart` |
| Block icons and labels | `lib/src/features/flows/{flow_icons,flow_labels}.dart` |
| "New flow" (describe / template / blank) and the describe page | `lib/src/features/flows/{flow_new,flow_describe_page}.dart` |
| A run's live view | `lib/src/features/flows/flow_run_page.dart` |
| What the Flows screens do to a flow (run, enable, delete, grant) | `lib/src/features/flows/flows_actions.dart` |
| Making a flow from chat ("every morning…") | `lib/src/features/chat/shell/make.dart` |

## Creations

See `docs/architecture/CREATIONS.md` for the spec DSL, the generation pipeline and the widget bridge.

| To change… | Edit |
|---|---|
| The creation screen (gallery cards, builder transcript, widget detail) | `lib/src/features/creations/creations_page.dart` + `parts/` |
| What a mini app may contain (the node vocabulary) | `lib/src/features/creations/spec/mini_app_spec.dart` |
| The size caps enforced on every spec | `lib/src/features/creations/spec/spec_limits.dart` |
| Which template a brief gets, and the template list | `lib/src/features/creations/templates/template_catalog.dart` |
| A template's layout and slots (apps / widgets) | `lib/src/features/creations/templates/app_templates.dart`, `widget_templates.dart` |
| Slot limits and sanitising | `lib/src/shared/slots/slots.dart` |
| What the model is told to produce (slots / decks) | `lib/src/features/creations/templates/slot_prompt.dart`, `creation_prompts.dart` (decks) |
| Deck themes and layouts | `lib/src/features/creations/spec/deck_theme.dart`, `deck/slide_card.dart`, `deck/pptx_writer.dart` |
| Template chips and the slot editor UI | `lib/src/features/creations/parts/template_ui.dart` |
| Pick → fill → retry → fallback behaviour | `lib/src/features/creations/creation_generator.dart` (+ `spec/spec_validator.dart` for decks) |
| The starter deck used when a deck cannot be generated | `lib/src/features/creations/creation_fallbacks.dart` |
| Recovering malformed or truncated model JSON | `lib/src/features/creations/json_salvage.dart` |
| Sandboxed app expressions (the security boundary) | `lib/src/features/creations/spec/safe_expression.dart` |
| Running a mini app (state, rendering, host screen) | `lib/src/features/creations/runtime/` |
| The slide deck viewer / `.pptx` export | `lib/src/features/creations/deck/` |
| Colours for tiles and specs | `lib/src/features/creations/creation_palette.dart` |
| Stored creations, versions and migration | `lib/src/features/creations/creation_store.dart` + `creation_model.dart` |
| Widget kinds (counter, checklist, tracker) and their spec | `lib/src/features/creations/spec/widget_spec.dart`, `templates/widget_templates.dart` |
| Home-screen widget pinning, launcher shortcuts and file sharing (Dart side) | `lib/src/features/creations/home_screen_service.dart` |
| Home-screen widget rendering and taps with the app closed (Kotlin side) | `android/…/FinnHomeWidgetProvider.kt`, `FinnHomeWidgetRenderer.kt`, `FinnHomeWidgetStore.kt`, `FinnHomeWidgetActions.kt` |
| A widget as it looks in the app | `lib/src/features/creations/widget_preview.dart` |
| Opening, adding to the home screen, exporting a creation | `lib/src/features/creations/creation_launcher.dart`, `creation_shelf.dart` |
| A mini app's saved state across launches | `lib/src/features/creations/runtime/mini_app_persistence.dart` |
| "Make me an app / widget / deck" typed in chat | `lib/src/features/creations/creation_request.dart`, `lib/src/features/chat/shell/make.dart` |
| The card a chat reply carries for what was made | `lib/src/features/conversations/message_card.dart`, `lib/src/features/chat/message_card_view.dart` |

## FinnAI Code

A second app inside the app: its own sessions, settings and providers, in the same design language. Rules: `lib/src/features/code/AGENTS.md`; decision: `docs/decisions/0010-finnai-code.md`.

| To change… | Edit |
|---|---|
| Switching between FinnAI and FinnAI Code (the brand row, the remembered choice) | `lib/src/shared/widgets/finn_brand_switcher.dart`, `lib/src/shared/config/app_mode.dart`, `lib/src/app/app_mode_host.dart` |
| The Code screen (sidebar, header, transcript, composer, navigation) | `lib/src/features/code/code_shell.dart`, `lib/src/features/code/ui/` |
| What the model is told, and how its reply is read (the action protocol) | `lib/src/features/code/agent/agent_protocol.dart` |
| The request loop: steps, approvals, stop, loop guards | `lib/src/features/code/agent/code_agent.dart` |
| What an action does (file write, command) | `lib/src/features/code/agent/action_runner.dart` |
| What a command may not do | `lib/src/features/code/sandbox/command_policy.dart` |
| Running a command (timeout, size cap, environment) | `lib/src/features/code/sandbox/shell_sandbox.dart` |
| The project folder and its path rules | `lib/src/features/code/sandbox/workspace.dart` |
| The providers (names, URLs, key and billing pages) | `lib/src/features/code/providers/code_provider.dart` |
| Live model lists and how each provider's list is read | `lib/src/features/code/providers/code_model.dart` |
| Request shapes and reading a streamed reply | `lib/src/features/code/providers/code_wires.dart` |
| Fetching models, allowance, testing a key, falling back between request shapes | `lib/src/features/code/providers/provider_client.dart` |
| API keys, model cache, the selected model | `lib/src/features/code/providers/provider_store.dart`, `providers/secret_store.dart` |
| On-device vs cloud model behind one interface | `lib/src/features/code/providers/gateways.dart` |
| Sessions and their storage | `lib/src/features/code/sessions/code_session.dart`, `sessions/code_session_store.dart` |
| Permission mode, step limit, network switch | `lib/src/features/code/settings/code_settings_store.dart`, `settings/code_agent_page.dart` |
| Provider pages (key, allowance, models, test) | `lib/src/features/code/settings/code_provider_page.dart`, `settings/code_providers_page.dart` |
| Model picker and the cloud disclosure | `lib/src/features/code/ui/code_models_page.dart` |
| Error and refusal wording | `lib/src/features/code/ui/code_text.dart` |
| What "delete all data" removes for Code | `lib/src/features/code/code_services.dart` (`deleteAll`), `lib/src/app/app_state_store.dart` |

## Apps, onboarding, settings, features

| To change… | Edit |
|---|---|
| Startup sequence, splash, routing decision | `lib/src/app/bootstrap.dart` |
| Onboarding pages, install progress, upgrade screen | `lib/src/features/onboarding/onboarding_flow.dart` |
| Settings hub and its pages (model, voice, access, data, about) | `lib/src/features/settings/settings_*.dart` |
| Global "delete all data" orchestration | `lib/src/app/app_state_store.dart` |
| You: what FinnAI remembers (store, pages) | `lib/src/features/you/{you_memory_store,you_page,you_category_page,you_privacy_page}.dart` |
| Personalization profile (name, style, instructions) | `lib/src/features/you/{you_profile_page,you_profile_store}.dart` |
| Search across chats, creations and You | `lib/src/features/chat/search_page.dart` |
| A chat's options (rename, pin, export, delete) | `lib/src/features/chat/chat_options.dart` |
| Hands-free voice | `lib/src/features/voice/{voice_sheet,voice_chat_controller,voice_settings_store,tts_backend}.dart` |
| Spoken replies (on-device voices, playback, language choice) | `lib/src/features/voice/tts/{local_tts_backend,supertonic_native,supertonic_worker,supertonic_text,supertonic_nfkd,tts_events,tts_voice_catalog,tts_voice_store,pcm_output,language_pick,fallback_tts_backend}.dart` + the C++ runner `android/app/src/main/cpp/finn_supertonic.cc` (decision: `docs/decisions/0008-licence-clean-voice.md`), `lib/src/features/voice/{reply_chunker,model_fetch}.dart` |
| Speaking-voice style picker (F1/F2/M1/M2) | `lib/src/features/settings/settings_voice_page.dart` (picker) + `lib/src/features/voice/voice_settings_store.dart` (`ttsStyle`) |
| Live voice bar (pill, caption, chat <-> voice morph) | `lib/src/features/chat/widgets/{voice_pill,voice_morph_bar}.dart`, the composer's attachment chip in `composer_attachment.dart` |
| Setup / upgrade download (language model + add-ons) | `lib/src/features/onboarding/model_install.dart`, `lib/src/app/speech_model_addon.dart` |
| Speech recognition (mic, VAD, Whisper, model download) | `lib/src/features/voice/stt/{sherpa_speech_backend,stt_worker,stt_events,stt_model_store,mic_source,audio_math,transcript_filter,speech_backend}.dart` |
| Report-an-answer dialog + backend | `lib/src/features/reporting/` |
| Legal URLs / licence text | `lib/src/shared/config/{legal_config,licenses}.dart` |

## Shared UI

| To change… | Edit |
|---|---|
| Colors, radii, text theme, system UI overlays | `lib/src/shared/theme/flux_theme.dart` |
| Space reserved below bottom-anchored UI (composer, nav bar height) | `lib/src/shared/theme/flux_theme.dart` (`FluxBottomInset.bottomOf`) |
| Buttons, pills, icon registry (`FluxIcons`), glass surfaces | `lib/src/shared/widgets/flux_controls.dart` |
| Flat raised surfaces (fill + 1px hairline, never a shadow), the pill text field, filter chips, the progressive backdrop blur | `lib/src/shared/widgets/flux_surfaces.dart` (`FluxSurfaces`, `FluxPillField`, `FluxChip`, `FluxProgressiveBlur`, `FluxGlass`) |
| Page header used by every sub-page | `lib/src/shared/widgets/finn_page_header.dart` |
| Design primitives (circle button, row tile, switch, reveal animation) | `lib/src/shared/widgets/finn_ui.dart` |
| A caption under a page title | `lib/src/shared/widgets/finn_page.dart` (`FinnCaption`) |
| Dialogs, sheets, popup menus, primary buttons | `lib/src/shared/widgets/finn_overlays.dart` |
| A standard secondary page (header, scrolling column, footer) | `lib/src/shared/widgets/finn_page.dart` |
| Long-press context menu | `lib/src/shared/widgets/flux_context_menu.dart` |
| App background | `lib/src/shared/widgets/ambient_background.dart` |

## Platform & tooling

| To change… | Edit |
|---|---|
| Android manifest, permissions, PROCESS_TEXT alias | `android/app/src/main/AndroidManifest.xml` |
| Android host + method channels | `android/app/src/main/kotlin/com/abhiflex/finnai/MainActivity.kt` |
| Android home-screen widget + share bridge | `android/…/FinnHomeScreenBridge.kt` (+ the manifest receiver/provider and `proguard-rules.pro`) |
| OpenHarmony path handling | `lib/src/platform/openharmony_path_provider.dart` |
| OpenHarmony platform detection (use this, not `Platform.isX`) | `lib/src/platform/platform_target.dart` |
| OpenHarmony conversation-key storage | `lib/src/platform/openharmony_key_storage.dart`, `lib/src/features/conversations/conversation_crypto.dart` (`createConversationCrypto`) |
| OpenHarmony host ability + native plugin channels | `ohos/entry/src/main/ets/entryability/EntryAbility.ets`, `ohos/entry/src/main/ets/plugins/` (one file per channel, listed in `docs/guides/OHOS_BUILD.md`) |
| OpenHarmony toolchain env, build/run, emulator, native libs | `tool/ohos_env.sh`, `tool/run_ohos.sh`, `tool/ohos_dev.sh`, `tool/patch_ohos_engine_har.sh` (+ `tool/ohos_engine_har_api24.patch`), `tool/rebuild_llama_ohos.sh` (+ `tool/llama_ohos_build.patch`) |
| Page transition used by every sub-page, and the sidebar → page hand-off | `lib/src/shared/widgets/finn_page_route.dart` (`FinnPageRoute`), `lib/src/features/chat/shell/navigation.dart` (`_pushFromSidebar`); timings in `FluxMotion` |
| Engine-seam CI gate | `tool/verify_engine_seam.sh` |
| Release verification | `tool/verify_release.sh`, `tool/build_play_release.sh` |
| CI pipeline | `.github/workflows/ci.yml`, `.github/workflows/release.yml` |

## Tests

`test/` mirrors `lib/`: `test/engine/`, `test/features/`, `test/app/`. `test/flutter_test_config.dart`
and `test/flux_golden_test.dart` must stay at the `test/` root (they resolve `goldens/` relatively).
See `docs/guides/TESTING.md`.

## Desktop and large screens (Linux, tablets)

See `docs/guides/LINUX.md`.

| To change… | Edit |
|---|---|
| Window-size classes, sidebar width, when the sidebar docks | `lib/src/shared/layout/finn_layout.dart` (`FinnLayout`) |
| The docked sidebar surface | `lib/src/shared/widgets/finn_sidebar_surface.dart` (`FinnSidebarSurface.docked`), `lib/src/features/chat/shell/sidebar_surface.dart` (`_sidebarSurface`), `lib/src/features/code/code_shell.dart` |
| Max width of sub-pages | `lib/src/shared/widgets/finn_page_route.dart` (`maxPageWidth`) |
| Enter-to-send, Ctrl+N / Ctrl+B / Ctrl+, | `lib/src/shared/widgets/enter_to_send.dart`, `lib/src/shared/widgets/desktop_shortcuts.dart` |
| Desktop-only guards (`isDesktop`) and ignored phone-only channel calls | `lib/src/platform/platform_target.dart`, `lib/src/platform/desktop_setup.dart` |
| Where the conversation key lives on Linux | `lib/src/platform/linux_key_storage.dart` |
| Read aloud on Linux | `lib/src/features/voice/linux_speech.dart`, `voice/read_aloud.dart` |
| Finding `libllama.so`, free disk space and the CPU name on desktop Linux | `lib/src/engine/profiler/desktop_profile.dart` (`DesktopProfile`), `device_profile.dart` (`llamaLibraryPath`, `desktop`) |
| Refusing a download that cannot fit (Linux) | `lib/src/engine/download/artifact.dart` (`_requireDesktopStorage`) |
| Why the prefix cache is off on Linux | `lib/src/engine/session/session_prep.dart` (`_prefixCacheEnabled`) |
| Esc / Alt+Left closes a page | `lib/src/shared/widgets/finn_page_route.dart` (`_BackKeys`) |
| The welcome screen's starfield and glow card (drawn, not photos) | `lib/src/features/onboarding/starfield.dart` (`Starfield`, `WelcomeGlowCard`) |
| First-run screens on a wide window (artwork left, text and controls right) | `lib/src/features/onboarding/wide_step.dart` (`WideStepLayout`, `WelcomeStartButton`) |
| FinnAI's own title bar, window buttons and resize edges (the native GTK bar is removed) | `lib/src/shared/widgets/finn_window_frame.dart` (`FinnWindowFrame`, `FinnTitleBar`, `finnAppBuilder`), `lib/src/platform/window_chrome.dart` (the `finn_ai/window` channel) |
| The title bar going dark over a full-bleed black screen | `FinnBlackScreen` in `finn_window_frame.dart`, used by the onboarding welcome page |
| Vertical spacing on wide windows (phone offsets are capped) | `lib/src/shared/layout/finn_layout.dart` (`FinnLayout.scaleY`) |
| The GTK runner: window title, size, minimum size, icon, the window channel (drag, resize, minimise, maximise, fullscreen) | `linux/runner/my_application.cc` |
| Bundling the model runtime, `.desktop` file, icon | `linux/CMakeLists.txt`, `linux/packaging/` |
| Building llama.cpp for Linux | `tool/rebuild_llama_linux.sh` |
