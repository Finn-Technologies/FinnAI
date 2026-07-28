# Performance Validation

## Physical device

- OnePlus Nord AC2001
- Qualcomm SM7250 (Snapdragon 765G), 8 CPU cores
- 8 GB RAM
- Android 12
- 4 KB kernel page size
- Flutter profile build, physical USB device

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
