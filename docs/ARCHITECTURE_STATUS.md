# FinnAI Architecture Status

This document separates **implemented architecture** from **migration targets** so the repository does not imply that planned backend independence is already complete.

## Current state

### Implemented

- `FinnEngine` provides the public engine-facing compatibility/export layer.
- llama.cpp integration is routed through `lib/src/engine/backends/llama_shim.dart` rather than being imported throughout the application.
- The accelerator owns local inference orchestration, model/session lifecycle, memory handling, profiling, and telemetry.
- The repository has automated tests around engine behavior and an engine-seam verification script.
- CI validates formatting, analysis, tests/coverage, release artifacts, ARM64 packaging, and Android 16 KB native alignment.

### In migration / partial

- The backend boundary is currently a **llama.cpp seam**, not yet a fully engine-independent backend interface.
- `FinnAccelerator` currently contains several responsibilities that would be cleaner as separate runtime/model/session/policy components.
- Some architecture documentation describes the intended multi-backend destination rather than the exact implementation currently present on `main`.

## Target architecture

```text
Flutter application
        |
        v
   FinnEngine API
        |
        v
 FinnAI Accelerator
        |
        +-------------------+
        |                   |
        v                   v
   Backend API        Device/Memory Policy
        |
   +----+----+----------------+
   |         |                 |
 llama.cpp  future CPU      future GPU/NPU
```

The high-level engine API should remain stable while backend implementations evolve independently.

## Recommended decomposition

The current accelerator can be incrementally decomposed into focused components:

- `EngineRuntime` — runtime lifecycle and worker/isolate coordination.
- `ModelManager` — model discovery, loading, unloading, and cache ownership.
- `SessionManager` — conversation/session lifecycle and session resources.
- `GenerationCoordinator` — generation, cancellation, streaming, and orchestration.
- `DevicePolicy` — hardware topology and backend/runtime selection.
- `MemoryPolicy` — KV-cache, image-cache, paging, and memory-pressure decisions.
- `BenchmarkController` — benchmark execution and validation workflows.
- `Telemetry` — latency/performance instrumentation without prompt-content leakage.

These are migration targets, not requirements for a single large rewrite. Prefer small, reviewable PRs that preserve behavior.

## Roadmap discipline

When adding architecture documentation, use these labels:

- **Implemented** — present and exercised in the current codebase.
- **Partial** — present in some form but still coupled to the current backend or missing pieces.
- **Planned** — design/roadmap work that has not landed yet.

This distinction is especially important for backend independence: the current design is a migration architecture, while true backend independence remains a future milestone.

## Related work

See GitHub issue #13 for the tracked work to split `FinnAccelerator` responsibilities and establish a backend contract independent of llama.cpp.
