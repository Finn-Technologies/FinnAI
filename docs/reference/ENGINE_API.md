# FinnAI Engine API Contract — Track 1 ↔ Track 5 Coordination

**Owner:** Track 5 (Engine abstraction), co-signed by Track 1 (Multimodal).  
**Status:** Phase 1 (now) — interface + adapter; no kernel changes.  
**Branch:** `worktree-track5-engine` (work in the repository root; paths below are repo-relative).

## Purpose

The app depends on the **engine seam** (`lib/src/engine/api/engine_api.dart`) rather than on `third_party/llama_cpp_dart` directly. This lets the team swap or add backends (Vulkan / OpenCL / future NPU delegate) without touching every call site and keeps Tracks 1 and 5 from stepping on `finn_accelerator.dart`.

## Files

| Path | Role | May import `llama_cpp_dart`? |
|---|---|---|
| `lib/src/engine/api/engine_api.dart` | Engine seam: `FinnEngine`, `ModelSpec`, `PromptSpec`, `MediaList`, `GenerationEvent`, `EngineCapabilities`, `FinnEngineSession`. No FFI imports. | ❌ |
| `lib/src/engine/backends/llama_backend.dart` | Sole adapter wrapping `LlamaEngine` / `EngineSession` / `MultimodalContext`. Translates seam types ↔ FFI types. | ✅ (only file in `lib/src/engine`) |
| `lib/src/engine/backends/llama_shim.dart` | Transitional shim re-exporting `llama_cpp_dart` so the rest of `lib/src/engine` can migrate off it in phases. New code should not add consumers. | ✅ (shim) |
| `lib/src/engine/finn_accelerator.dart` | High-level facade: downloads, residency, TTFT, web-search orchestration. Depends on `FinnEngine`; construction stays in `backends/`. | ❌ (via shim bridge, to be removed) |
| `lib/src/engine/adaptive/*`, `profiler/*`, `policy/*`, `metrics/*`, `prompt/*`, `session/*` | Heuristics / profiling / policy. Already on owned types. | ❌ |

Enforcement: `tool/verify_engine_seam.sh` (`grep -r "import.*package:llama_cpp_dart" lib/src/engine | grep -v backends` must be empty) + the header in `analysis_options.yaml`. New engine code importing `llama_cpp_dart` outside `backends/` is rejected in review and blocked in CI.

## Seam Surface (Phase 1)

```dart
// lib/src/engine/api/engine_api.dart

abstract class FinnEngine {
  Future<void> load(ModelSpec spec);
  Future<GenerationStream> generate(PromptSpec prompt, MediaList media);
  Future<void> unload();
  EngineCapabilities get capabilities;

  // Low-level session surface kept for FinnAccelerator's existing
  // conversation/KV logic; will tighten as the facade migrates further.
  bool get isDisposed;
  Future<FinnEngineSession> createSession({int seqId = 0, int lookaheadWindow = 0});
  Future<void> dispose();
  bool get multimodalLoaded;
  bool get canShift;
  List<EngineDevice> get devices;
  String get systemInfo;
  String get packageVersion;
  String get llamaCppCommit;
}

@immutable
class ModelSpec { String path; String? mmprojPath; FinnEngineConfig config; String modelLabel; String sha256Digest; }

@immutable
class EngineMedia { Uint8List bytes; EngineMediaKind kind; String? id; }
typedef MediaList = List<EngineMedia>;

@immutable
class PromptSpec { String prompt; int maxTokens; EngineSamplerConfig sampler; bool addSpecial; bool parseSpecial; EngineContextShiftPolicy shiftPolicy; int nKeep; }

sealed class GenerationEvent {}
class EngineTokenEvent extends GenerationEvent { int id; Uint8List bytes; String text; int position; }
class EngineShiftEvent extends GenerationEvent { int nKeep; int nDiscard; int newPosition; }
class EngineDoneEvent  extends GenerationEvent { GenerationFinishReason reason; int generatedCount; int committedPosition; String trailingText; }

typedef GenerationStream = Stream<GenerationEvent>;
```

`ModelSpec.config` is `FinnEngineConfig` (thread/batch/KV/FlashAttention knobs from `device_profile.dart`). `EngineSamplerConfig` mirrors the llama sampler fields the app tunes. Backends translate both to native `ContextParams`/`SamplerParams`.

## Production Wiring

- **Production:** `FinnAccelerator` loads via `LlamaBackend`. Direct `LlamaEngine.spawn` stays inside `llama_backend.dart`.
- **Tests / fakes:** `FinnAccelerator` exposes `debugEngineFactory` (nullable `dynamic`) so tests can inject a fake `FinnEngine` without ever importing `llama_cpp_dart`.
- **Speed wins preserved** (no arch change): thread pinning via `DeviceProfiler.plan` (decode 2–4 fast cores), `nBatch`/`nUbatch` adaptive by `device_profile`, `FlashAttention` gated `!isLowEnd`, KV `compactQ4` retained, `searchDecision` skipped when `hasAttachedImage`, `defragThreshold 0.1` on low-end else `-1`, KV `compactQ4`/`iq4_nl` keep, TTFT split `tokenize+prefill` via native trace else Dart stopwatches.
- **Multimodal (Track 1 coordination):** Vision path stays in the accelerator (mmproj detection, media marker, `hasAttachedImage` gate) while native `MultimodalContext` is owned by the backend. Track 1's multi-image / async `readAsBytes` work lands first; Track 5 rebases onto it and keeps the backend's `MultimodalParams(nThreads: batchThreads, useGpu: false)` in sync with `device_profile`.

## Adding a New Backend

1. Create `lib/src/engine/backends/<name>_backend.dart` implementing `FinnEngine` + `FinnEngineSession`.
2. Translate `ModelSpec`→native load, `PromptSpec`+`MediaList`→native generate, native events→`GenerationEvent`.
3. Register in a factory (future `EngineBackendRegistry`) behind a `FINN_ENGINE_BACKEND` allow-list; keep `LlamaBackend` as the default.
4. No file outside `backends/` should need a `llama_cpp_dart` import.

## Verification

```bash
flutter analyze        # 0 issues
flutter test           # green
tool/verify_engine_seam.sh        # no llama imports outside backends/
grep -rn "package:llama_cpp_dart" lib/src/engine --include="*.dart" | grep -v backends   # empty (imports only)
```

## Open Questions for Tracks 1 ↔ 5

- **Projector GPU path:** `MultimodalParams(useGpu:)` stays `false` in Phase 1; widen when Track 1's Xiaomi mmproj bench shows headroom.
- **KV standalone path:** `libfinn_accelerator.so` exploration (Phase 4) stays in `docs/ENGINE_ROADMAP.md`.
