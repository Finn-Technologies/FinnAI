# Performance Validation

See [TTFT_ARCHITECTURE.md](TTFT_ARCHITECTURE.md) for phase-level
tap-to-first-visible-token instrumentation, residency policy, benchmark
controls, thermal handling, and the current safe limitation on shared
base-prefix snapshots.

## Physical device

- OnePlus Nord AC2001
- Qualcomm SM7250 (Snapdragon 765G), 8 CPU cores
- 8 GB RAM
- Android 12
- 4 KB kernel page size
- Flutter profile build, physical USB device

## TTFT benchmark — 29 July 2026

All rows are real on-device profile runs. Each summary contains five measured
requests; the conversation-warm harness performs an unmeasured priming turn
first. Prompt-token counts are explicitly estimated because the current
`llama_cpp_dart` worker does not expose tokenizer counts or separate native
prefill/sample timestamps.

| Scenario / configuration | p50 TTFT | p95 TTFT | Minimum | Maximum |
|---|---:|---:|---:|---:|
| Lite conversation warm, 4 decode / 6 batch threads, 512/256 batch | 2.542 s | 2.587 s | 2.526 s | 2.587 s |
| Lite conversation warm, 5 decode / 8 batch threads, 512/256 batch | **2.306 s** | **2.357 s** | 2.283 s | 2.357 s |
| Lite conversation warm, 3 decode / 4 batch threads, 128/64 batch | 3.174 s | 3.208 s | 3.147 s | 3.208 s |
| Plus conversation warm, 4 decode / 6 batch threads, 512/256 batch | 5.869 s | 5.914 s | 5.795 s | 5.914 s |
| Lite true cold, adaptive cool/thermal plan | 33.643 s | 33.702 s | 24.027 s | 33.702 s |

The winning cool balanced-device plan is 5 decode threads, 8 batch threads,
`n_batch=512`, and `n_ubatch=256`. Five consecutive Lite warm requests did not
collapse: samples were 2.283, 2.306, 2.305, 2.337, and 2.357 seconds. The
measured thermal plan uses 4/4 threads and 256/128 batches. It is slower but
avoids continuing the aggressive plan when Android thermal headroom is near
the severe threshold.

The cold phase record explains why mmap-only tuning cannot meet the cold
target:

| Lite true-cold phase | Cool run | Thermal run |
|---|---:|---:|
| Routing | 0 ms | 0 ms |
| Model mmap/engine spawn | 607 ms | 594 ms |
| Session + Dart prompt build | < 1 ms | 3 ms |
| Combined tokenization, prefill, first sample | 23.405 s | 33.101 s |
| Total first visible token | 24.027 s | 33.702 s |

The first two cold runs used the 5/8 cool plan and measured 24.027 and
24.721 seconds. At thermal headroom 0.897–0.966, the 4/4 thermal plan engaged;
the last three runs measured 33.652, 33.702, and 33.643 seconds. Android
thermal status remained `0`, while battery reached 40.6 °C and skin reached
44.5 °C, just below the reported 45 °C throttling threshold. The app was then
force-stopped to cool the device.

Exact-session reuse plus unchanged-task-policy suppression reduced the warm
Lite request from 107 estimated prompt tokens and approximately 6.9 seconds
to 36 estimated tokens and 2.306 seconds p50 with the winning plan. The Plus
warm prompt was 32 estimated tokens. A cold ambiguous Lite router pass
measured 32.583 seconds in the initial diagnostic run; deterministic direct
routing removes that entire prepass for clear Plus intents.

Measured resident footprints:

- Lite only after five warm requests: 755,008 KB PSS / 921,728 KB RSS.
- Plus only after five warm requests: 1,156,750 KB PSS / 1,323,452 KB RSS.
- Lite + Plus resident during the initial diagnostic: 1,664,635 KB PSS /
  1,831,516 KB RSS.
- Attributed swap stayed between 92 KB and 132 KB.

The engineering targets were not met on this runtime. Remaining warm latency
is almost entirely native prompt processing/first sampling even with only
32–36 estimated incremental tokens. Shared new-chat prefix KV is not claimed:
the dependency can queue/tokenize a prefix and save state, but cannot evaluate
it without sampling an extra token or clone a prepared sequence through its
public worker API.

## Inference

The compile-time `FINN_BENCHMARK` harness ran two real, consecutive local
generations against the installed GGUF models. Reported decode rate excludes
first-token/prefill time.

| Configuration | Cold first token | Decode | Warm first token | Warm decode |
|---|---:|---:|---:|---:|
| Bonsai 1.7B, 4 threads, original prompt/router budget | 30.001 s | 4.94 tok/s | 2.798 s | 4.86 tok/s |
| Bonsai 1.7B, 4 threads, compact prompt/bounded router | 24.916 s | 4.96 tok/s | 2.704 s | 4.96 tok/s |
| Bonsai 1.7B, 3 threads, compact prompt/bounded router | 24.928 s | 4.47 tok/s | 2.688 s | 4.27 tok/s |
| Bonsai 4B, 4 threads, direct complex-request route | 52.442 s | 2.38 tok/s | 6.712 s | 2.32 tok/s |
| Bonsai 1.7B, corrected non-thinking template + compact safety prompt | 23.135 s | 4.96 tok/s | 2.010 s | 4.97 tok/s |

The 4-thread balanced-device plan is retained: it delivered approximately
11–16% more decode throughput than 3 threads without a first-token penalty.
The final compact prompt reduced measured cold 1.7B first-token time by 22.9%
against the original baseline. More importantly, explicitly priming Qwen 3's
empty non-thinking block fixed a real zero-visible-token failure on the 1-bit
model and avoided decoding the wrapper as output. A warm second turn completed
in 5.834 s total.

Clear writing, coding, analysis, and other complex prompts now bypass the
generative Lite routing pass. On the measured Nord this avoids up to one full
Lite prepass before beginning the 4B response. Ambiguous prompts still use the
requested Lite-model routing behavior.

Measured during 4B generation:

- Total PSS: 1,568,365 KB
- Total RSS: 1,701,388 KB
- Swap attributed to the process: 60 KB

## UI and navigation

A normal profile build exercised Home → sidebar → Creations → Home → You →
Home → Skills on the physical Nord. Android `gfxinfo` reported:

- 196 rendered frames
- 4 janky frames (2.04%)
- 5 ms median frame time
- 13 ms p95
- 22 ms p99
- 0 slow bitmap uploads
- 0 slow draw-command submissions

The measured renderer was Skia/OpenGL. The current Android 12 compatibility
selection is retained because this physical-device run stayed comfortably
inside the frame budget.

The final build was then installed over the existing app data and rechecked:

- Cold Android activity launch: 792 ms
- Sidebar transition: 0/2 janky frames, 12 ms p95
- Creations transition: 0/4 janky frames, 12 ms p95
- Home → You → Skills sequence: 0/6 janky frames, 12 ms p95
- Lite-resident idle/prewarmed process: about 916 MB RSS
- In-response Stop control: generation cancelled and unfinished assistant
  placeholder removed successfully

An ARM64 Pixel 10 emulator with 4 GB RAM was also used for the final
production-profile UI pass. Home, the settled sidebar banner, Creations, You,
Skills, and the retained Settings screen were opened and visually inspected at
a 360 × 808 logical viewport. The three feature pages use the same measured
back-control and title anchors as Settings; this is also locked by a widget
regression test. No Flutter fatal exception or app ANR appeared in the captured
Android logs. At the end of the idle navigation pass the process reported
approximately 207 MB total PSS with no attributed swap.

The sidebar AdMob platform view is created only after the opening animation has
settled and disposed before closing begins. This keeps the native banner out of
the animated transform while preserving a stable bottom placement and history
padding.

## Native runtime

The source-built llama/ggml runtime completed multi-turn local generation on the Nord
without native linker, mmap, or symbol failures. Every packaged arm64 ELF and
the release APK and AAB pass 16 KB static alignment checks, and both artifacts
were verified to contain only `arm64-v8a` native libraries. Runtime validation on an
Android 15+ device or emulator with a real 16 KB kernel remains required; the
Nord reports a 4 KB page size.
