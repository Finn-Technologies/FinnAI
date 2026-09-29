# Architecture overview

FinnAI is a single-process Flutter app. There is no backend: the only network traffic is the
one-time model download and optional, explicit web-search queries.

## Layers and dependency direction

```text
        main.dart
            │
   lib/src/app/            bootstrap widget, global app state      (bootstrap.dart, app_state_store.dart)
            │
   lib/src/features/       one folder per user-facing feature
            │   chat/ onboarding/ conversations/ search/ settings/ flows/ you/ creations/ voice/ reporting/
            │
   lib/src/inference/      app-facing engine surface  ────────┐
            │              (thin re-export shims)             │
            │                                                 │
   lib/src/engine/  ◄─────────────────────────────────────────┘
            │              the ONLY place `package:llama_cpp_dart` is imported
            │              (engine/backends/llama_shim.dart)
            ▼
     native  libllama.so  (FinnAI-Accelerator, worker isolate)

   lib/src/shared/         theme, widgets, config      (imported by every layer)
   lib/src/platform/       OpenHarmony path shim
```

Rules that hold this together, and where they are enforced:

1. **The engine seam.** Only `lib/src/engine/**` may import `package:llama_cpp_dart`. App code goes
   through `lib/src/inference/**`, which re-exports engine types under a stable path. Enforced by
   `tool/verify_engine_seam.sh` in CI. Rationale and migration plan: `ENGINE_ROADMAP.md`.
2. **`shared/` never imports `features/` or `engine/`.** Widgets and theme are leaves.
3. **One model, one tier.** `finnModels` has exactly one entry (`finnModels.single`).

## State management

Plain singletons plus `ChangeNotifier` / `ValueNotifier`. There is no Provider, no InheritedWidget,
and no DI container. The singletons are:

| Singleton | Owns |
|---|---|
| `FinnAccelerator` (`FinnInference`, `FinnEngine`) | device profile, model install/download state, loaded runtimes, generation |
| `AppStateStore` | onboarding-complete marker, "delete all data" orchestration |
| `ConversationStore` | conversation list, active conversation, encryption key |
| `ChatGenerationController` | the single in-flight generation job, stream subscription |
| `YouProfileStore`, `FlowsStore`, `CreationStore`, `VoiceSettingsStore` | feature-local persisted state |

UI state that is not shared lives in `State` objects — notably `_HomeShellState` in
`features/chat/home_shell.dart`, which is the largest widget by far.

## One message, end to end

1. **Compose.** `HomeShell._send` (`features/chat/home_shell.dart`) normalizes the text, collects
   attachments, builds the system context from `YouProfileStore` + `FlowsStore`, and — if the local
   freshness policy (`WebSearchPolicy.shouldSearch`) says the query may need current facts — runs an
   upfront web search with a 3 s timeout.
2. **Start.** `ChatGenerationController.start` creates a `ChatGenerationJob` and subscribes to
   `FinnInference.generateReplyQueued`.
3. **Prepare.** The engine (`engine/finn_accelerator.dart`) ensures the model file exists, loads the
   runtime if needed (`_ensureLoaded` → `_loadModel`), picks an inference plan, and prepares or
   restores a per-conversation session. A saved prefix state (`FINN_PREFIX`) lets a warm turn skip
   most prefill.
4. **Generate.** Tokens stream from the native worker isolate. The controller appends them to the
   job; the UI paints them on a throttled tick (see `plan.tokenPaintIntervalMs`).
5. **Persist.** `ConversationStore` debounces writes (420 ms) and stores the conversation as an
   AES-256-GCM envelope; partial replies are checkpointed during streaming so a process death does
   not lose the turn.
6. **Surface.** Sources and timings come back on the job (`FINN_TTFT`, `FINN_PERF`); errors are
   mapped through `_friendlyError` into a message bubble.

## Where things can go wrong

The interesting failure modes are all around *long-running work*: model download, model load, and
generation. Each is cancellable and each persists enough state to resume:

- downloads resume from per-range offsets and are validated by size + SHA-256;
- a process kill during generation is reconciled to `interrupted` on next load;
- the engine unloads under memory pressure and reloads on demand.

See `MODEL_PIPELINE.md` for the model half and `CHAT_GENERATION_ARCHITECTURE.md` for the chat half.
