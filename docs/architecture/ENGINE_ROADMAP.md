# FinnAI Accelerator → Independent Engine: 12-Month Runway

**North star:** in 12 months `FinnAI Accelerator` is a standalone engine
(own `libfinn_accelerator.so` or a Dart package) with **zero**
`third_party/llama_cpp_dart` imports in `lib/src/engine` — llama.cpp is one
backend among N.

Progress is tracked by quarter. Each quarter ships Green tests, keeps TTFT
and peak-RSS on budget devices within family, and keeps `flutter analyze` /
`flutter test` green before merge.

---

## Q1 — Interface (now, Track 5 Phase 1)

**Branch:** `worktree-track5-engine`; lands after Track 1 so multimodal
adapter changes can rebase cleanly.

- **Engine seam:** `lib/src/engine/api/engine_api.dart` — `abstract class
  FinnEngine { Future<void> load(ModelSpec); Future<GenerationStream>
  generate(PromptSpec, MediaList); Future<void> unload();
  EngineCapabilities get capabilities; }` plus `ModelSpec`, `PromptSpec`,
  `MediaList`, `GenerationEvent`. Mirror current surface but **owned** by the
  engine layer.
- **Backend adapter:** `lib/src/engine/backends/llama_backend.dart` wraps
  `LlamaEngine` / `EngineSession` / `MultimodalContext`. **Only** this file
  (plus the transitional `llama_shim.dart`) may `import
  'package:llama_cpp_dart'`.
- **Accelerator facade:** `FinnAccelerator` depends on `FinnEngine` via
  constructor injection (`debugEngineFactory` for tests / fakes).
  `LlamaEngine.spawn` lives only in the adapter. Behavior is byte-identical.
- **Speed wins, no arch change:** thread pinning already via
  `DeviceProfiler.plan` (SM7325 big-core pin), `nBatch`/`nUbatch` adaptive by
  `device_profile`, `FlashAttention` gated `!isLowEnd`, KV `Q4_0`/`iq4_nl`
  compact kept, `defragThreshold 0.1` low-end else `-1`, `searchDecision`
  skipped when `hasAttachedImage`. TTFT split `tokenize+prefill` via native
  trace where exposed, else Dart stopwatches.
- **Build decoupling:** `tool/verify_engine_seam.sh` +
  `analysis_options.yaml` header enforce the `backends/` allowlist. Documented
  in `docs/ENGINE_API.md`.
- **Track 1 coordination:** `docs/ENGINE_API.md` is the contract both tracks
  share; vision mmproj path stays `useGpu: false` until Track 1's Xiaomi bench.

**Exit bar:** `flutter analyze` clean, `flutter test` green,
`grep -r "llama_cpp_dart" lib/src/engine --include="*.dart" | grep -v backends`
empty for real imports, bench on Xiaomi 11 Lite 5G NE not regressed (19 → 21+
tok/s target as side-effect, not a migration requirement).

---

## Q2 — Vulkan / OpenCL Bench Fix

Focus: make the GPU paths the harness already tries **worth keeping**.

- **Fix the bench path** in `adaptive/adaptive.dart`:
  remove or correctly gate `if (Platform.isAndroid) return null` so
  `optimizeForDevice → _spawnBenchmarkEngine` can actually try
  Vulkan/OpenCL on drivers that ship them. Keep Adreno 642L BDA bug on CPU
  via an allow-list.
- **Tune the bench gate** (`hasOffloadHeadroom`, 15 s timeout, benchmark drop
  on failure) so a broken GPU driver falls back to CPU without bricking
  startup and without rewriting the cache with a bogus pick.
- **Validate on Xiaomi 11 Lite 5G NE:** toggling
  `FINN_ENABLE_GPU` dart-define + `FINN_BENCHMARK=1` harness records the
  winning backend; `adb logcat | grep FINN_BENCH` proves the GPU candidate
  was tried and was either picked or credibly beat.
- Keep the adapter seam: GPU discovery results stay as `EngineDevice` in
  `EngineCapabilities`; accelerator policy stays in Dart.

**Exit bar:** reproducible Vulkan/OpenCL win on at least one mid-range
device with no regression on unsupported Adrenos.

---

## Q3 — KV / Opt Kernels

Focus: memory wins that buy back context.

- **KV kernels:** explore tighter KV quantization paths and attention
  fast-paths behind `FinnKvCacheType` (`turboQuant2Bit` / `compactQ8` /
  `compactQ4` / `fp16`) without changing the public `ModelSpec.config`.
  Gate by `isLowEnd` so entry devices never pay the fallback tax.
- **Batch/opt:** micro-bench `batchThreads` per device (currently `batchThreads
  ?? 8` fixed) and tighten `nRsSeq` / `lookaheadWindow` on recurrent models.
- **Budgeted benchmark harness:** sweep `PlanOverrides` without rebuilding;
  keep `FINN_BENCH_F16_KV` / `FINN_BENCH_FLASH_OFF` toggles meaningful.
- Backend adapter hides kernel choices; engine callers keep using
  `PromptSpec`/`ModelSpec` unchanged.

**Exit bar:** PSS / steady-state RSS guides met after warm model on Tab A8
3 GB and Motorola G85; no thread-pinning regression.

---

## Q4 — Standalone `libfinn_accelerator.so`

Focus: the engine can ship as its own native library.

- Extract a loadable `libfinn_accelerator.so` (or an equivalent Dart package
  wrapping the native engine) that second-party hosts can link without pulling
  `third_party/llama_cpp_dart` into their `pubspec.yaml`.
- `llama_cpp_dart` becomes one *registered* backend; a thin registry
  (`EngineBackendRegistry`) picks `LlamaBackend` by default and future
  backends (server stub, delegate) by an `FINN_ENGINE_BACKEND` allow-list.
- Migration is mechanical: every `llama_cpp_dart` import outside
  `backends/` is already gone after Q1, so the `.so` split touches only the
  `android/app` Gradle / `CMakeLists.txt` plumbing and the host's loader.

**Exit bar:** downstream can depend on `finn_accelerator` (Dart) +
`libfinn_accelerator.so` (native) and run chat + vision without any
`llama_cpp_dart` dependency. Existing Flutter app keeps `third_party/`
for the source build behind a feature flag until fully sunset.

---

## Cross-cutting Guardrails

- No model swap in Phase 1 (keep LFM2.5-VL 1.6B Q4_0 + mmproj F16).
- `flutter gen-l10n`, `flutter test` (27 suites + new l10n/memory/bench)
  stays green; `tool/verify_release.sh` + `tool/verify_native_alignment.py`
  remain passable.
- Xiaomi 11 Lite 5G NE is the shared perf gate for Tracks 1, 4, 5:
  `flutter run --dart-define=FINN_BENCHMARK=1`, `adb logcat | grep FINN`.
- Track 5 rebases onto Track 1 after it lands; conflicts on
  `finn_accelerator.dart` serialize through the `ENGINE_API.md` contract.

## What Is NOT In Scope (Phase 1)

- New kernels, NPU delegates, or model-format migration — these are Q2–Q4.
- Removing `third_party/llama_cpp_dart` from the repo — its Java/Kotlin shim
  and FFI stay until the Q4 split.
- Download / store changes — Track 4 owns RAM + store; Track 1 owns mmproj
  install flow.

