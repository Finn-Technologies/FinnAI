# Glossary

Terms used across the codebase and these docs.

| Term | Meaning |
|---|---|
| **FinnAI-Accelerator** | The native inference runtime bundled with the app (`libllama.so`), driven from Dart over a worker isolate. |
| **Engine seam** | The rule that only `lib/src/engine/**` imports `package:llama_cpp_dart`; everyone else uses `lib/src/inference/**`. Enforced by `tool/verify_engine_seam.sh`. |
| **Facade** | `lib/src/engine/finn_engine.dart`, re-exported as `lib/src/inference/finn_inference.dart`. The `FinnAccelerator` singleton is aliased as `FinnEngine` and `FinnInference`. |
| **GGUF** | The model file format. FinnAI validates the 4-byte magic plus exact length. |
| **mmproj** | The multimodal projector (SigLIP2) that turns images into embeddings the language model can read. Downloaded as a second artifact (`finnMmproj`). |
| **KV cache** | Per-token attention state. FinnAI stores it quantized (`q4_0` by default) with an F16 fallback for incompatible devices. |
| **Prefix state** | A serialized KV snapshot for a conversation's shared prefix, saved to disk so a warm turn skips prefill. Logged as `FINN_PREFIX`. |
| **Session** | A per-conversation native sequence holding the KV cache and prefix state. |
| **Prefill / decode** | Prefill processes the prompt (batch); decode emits tokens one at a time. |
| **TTFT** | Time to first token — the latency a user actually feels. Traced in `engine/metrics/ttft_metrics.dart`, logged as `FINN_TTFT`. |
| **Residency** | Whether the model is loaded in memory; `residency_policy.dart` decides when to unload (backgrounding, memory pressure). |
| **Adaptive selection** | Benchmarking/choosing a backend + runtime config per device (`engine/adaptive/adaptive.dart`). Android is pinned to CPU. |
| **Device profile** | Detected hardware facts (cores, RAM, storage, processor class) used to build an `InferencePlan`. |
| **Plan / RuntimeConfig** | The concrete thread/batch/context/KV settings handed to the native engine. |
| **Freshness policy** | `WebSearchPolicy.shouldSearch` — a local, deterministic check for whether a query may need current web facts. |
| **Grounded context** | Web-search excerpts injected into the prompt, surfaced to the user as sources. |
| **Creations** | Locally generated structured artifacts (documents/widgets/concepts). |
| **Skills** | User-authored instruction snippets injected into the private context. |
| **PROCESS_TEXT / "Ask Finn AI"** | Android text-selection integration that opens the app with the selected text. |
| **Engine seam violation** | CI failure produced when a non-engine file imports `package:llama_cpp_dart`. |
