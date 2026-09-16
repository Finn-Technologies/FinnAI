---
name: finn-engine-seam
description: Work with FinnAI's native inference engine without breaking the engine seam — the rule that only lib/src/engine/** may import package:llama_cpp_dart. Use when touching the native runtime, the engine facade, backend/shim files, or when a build fails with an engine-seam violation.
when_to_use: Editing anything under lib/src/engine/ or lib/src/inference/, changing llama.cpp usage, adding an engine config or value type, or debugging "ENGINE SEAM VIOLATION" in CI.
---

# FinnAI engine seam

## The rule

**Only `lib/src/engine/**` may import `package:llama_cpp_dart`.** Within the engine, exactly one
file does it:

```text
lib/src/engine/backends/llama_shim.dart     ← the ONLY importer
```

Everything else in `lib/src/engine/` imports that shim. Everything outside the engine imports
`lib/src/inference/**` instead.

```dart
// ✅ engine code
import 'package:finn_ai/src/engine/backends/llama_shim.dart';

// ❌ anywhere outside the engine
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
```

Verify locally:

```bash
bash tool/verify_engine_seam.sh     # exits non-zero on a violation
```

CI runs the same script. If it fails, the output lists each offending file and line.

## Why it exists

The engine is meant to be extractable into its own package later
(`docs/architecture/ENGINE_ROADMAP.md`). The seam is what keeps that possible: the app depends on a
stable surface, and swapping the runtime means editing the shim and the `inference/` re-exports —
not every call site.

## The two trees, and which one to import

| Tree | Role | Import this from |
|---|---|---|
| `lib/src/engine/**` | Implementation: accelerator, adaptive selection, profiler, prompt, policy, metrics, catalog | Only other engine files (and tests) |
| `lib/src/inference/**` | App-facing surface: seven one-line `export` shims plus `evaluation.dart` | All app code under `lib/src/features/`, `lib/src/app/`, `lib/src/shared/`, and `main.dart` |

`inference/` is intentionally thin — each file is `library;` followed by a single `export`. If you
add engine API that app code needs, add a re-export there rather than importing `engine/` from a
feature.

**Engine code must never import through `inference/`.** That is a layering inversion: the engine
would be reaching its own types through the outward-facing surface. Import the sibling directly
(for example `package:finn_ai/src/engine/prompt/prompt_intent.dart`).

## Where things live

- `engine/finn_engine.dart` — public facade; re-exports the accelerator, config, stream, types and
  prompt formatter, and exposes the harness hooks `setLlamaNativeLogCapturePath` /
  `setLlamaRepackCacheDir`.
- `engine/finn_accelerator.dart` — the `FinnAccelerator` singleton (aliases `FinnEngine`,
  `FinnInference`). Owns install, load, residency, generation.
- `engine/adaptive/adaptive.dart` — backend and runtime-config selection.
- `engine/profiler/device_profile.dart` — hardware detection and the `InferencePlan`.
- `engine/policy/residency_policy.dart` — when to unload the model.
- `engine/metrics/ttft_metrics.dart` — latency tracing.
- `engine/catalog/model_catalog.dart` — the model records.
- `engine/eval/evaluation.dart` — quality acceptance checks used by the eval harness.
- `engine/backends/llama_shim.dart` — the single native import point.
- `third_party/llama_cpp_dart/` — vendored bindings, **excluded from analysis**, never hand-edited
  (patch via `tool/*.patch` and `tool/rebuild_llama_android_aar.sh`).

## Checklist before you finish

```bash
bash tool/verify_engine_seam.sh
dart analyze .
flutter test test/engine/
```

If you changed the facade's public surface, also update `docs/reference/ENGINE_API.md`.
