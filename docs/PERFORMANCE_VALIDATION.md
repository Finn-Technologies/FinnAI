# Performance Validation

See [TTFT_ARCHITECTURE.md](TTFT_ARCHITECTURE.md) for phase-level
tap-to-first-visible-token instrumentation, residency policy, benchmark
controls, thermal handling, and the current safe limitation on shared
base-prefix snapshots.

## Physical device

- Xiaomi 11 Lite 5G NE
- Qualcomm SM7325 (Snapdragon 778G), 8 CPU cores (4× A78 @ 2.4 GHz + 4× A55)
- 8 GB RAM
- Android 14 (MIUI)
- Flutter profile build, physical USB device
- Model: Qwen3.5-2B Q4_K_M (gated-delta-net hybrid; 18/24 SSM layers)

## TTFT and decode benchmark — 17 August 2026

All rows are real on-device profile runs of the `FINN_BENCHMARK` harness with
`FINN_BENCH_NO_SEARCH` (pure inference, no network). The harness keeps the
activity visible so the process stays in the Android `top-app` cgroup; without
that, MIUI throttles the A78 cluster to ~700 MHz and decode collapses ~45×
(measured 8.5 s/token vs 52 ms/token on the same build).

| Scenario | TTFT | Decode |
|---|---:|---:|
| New conversation (warm engine, no search) | 2.13 s p50 (2.12–2.31 s) | 52 ms/token ≈ 19 tok/s |
| Conversation-warm follow-up (KV cached) | 0.43 s | 52 ms/token ≈ 19 tok/s |
| True cold (fresh engine + prefix prefill) | 4.66 s (model load 2.67 s + prefill 1.9 s) | — |
| Search turn (web fetch + grounded prefill) | 14.2 s | ~10 tok/s sustained |

Long-form answers sustain ~9 tok/s after thermal ramp (a 780-token recipe
answer completes in ~85 s on the warm device).

### Plan

The balanced-device plan is **4 decode threads / 4 batch threads**, with
`n_batch=512`, `n_ubatch=256`, q8_0 KV, flash attention on, context 8192.

Measured decode-thread sweep (screen on, full CPU, affinity-pinned to the
fastest cluster):

| Decode threads | ms/token |
|---:|---:|
| 3 | 189 |
| 4 | 52 |
| 6 | 60–72 |

Two native changes drive the win:

1. **Threadpool CPU affinity** (`ggml_threadpool_new_impl`): pools pin to the
   fastest CPU cluster detected from `cpuinfo_max_freq`, so no worker lands on
   an efficiency core where every per-node barrier waits for it (measured
   7.8 ms/barrier with a throttled/straggler thread vs 5 µs/barrier on the
   fast cluster).
2. **Prompt diet**: safety prefix 340 → 261 tokens, task instruction and
   search-decision directive compressed, decision-pass cap 20 → 12 tokens,
   web-excerpt cap 1400 → 900 chars.

### Historical (Bonsai era, OnePlus Nord)

The pre-Qwen3.5 measurements below used the earlier Bonsai models on a
Snapdragon 765G and are retained only as history — they do not describe the
current runtime.

| Configuration | Cold first token | Decode | Warm first token | Warm decode |
|---|---:|---:|---:|---:|
| Bonsai 1.7B, 4 threads, original prompt/router budget | 30.001 s | 4.94 tok/s | 2.798 s | 4.86 tok/s |
| Bonsai 1.7B, 4 threads, compact prompt/bounded router | 24.916 s | 4.96 tok/s | 2.704 s | 4.96 tok/s |
| Bonsai 1.7B, 3 threads, compact prompt/bounded router | 24.928 s | 4.47 tok/s | 2.688 s | 4.27 tok/s |
| Bonsai 4B, 4 threads, direct complex-request route | 52.442 s | 2.38 tok/s | 6.712 s | 2.32 tok/s |
| Bonsai 1.7B, corrected non-thinking template + compact safety prompt | 23.135 s | 4.96 tok/s | 2.010 s | 4.97 tok/s |

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
