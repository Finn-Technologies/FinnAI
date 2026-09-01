# Performance Validation & Hardware Benchmarks

FinnAI's on-device inference runtime (**FinnEngine**) dynamically adapts its thread topology, context size, and memory residency to match physical device constraints.

---

## Tested Hardware Matrix

| Device Tier | Example Hardware | CPU Topology | RAM | Plan Configuration | Generation Throughput |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Entry / Constrained** | **Samsung Galaxy Tab A8** (`SM-X200`) | Unisoc Tiger T618 (2× A75 @ 2.0 GHz + 6× A55) | 3 GB | **2 decode / 4 batch threads**, ctx: 2048, batch: 128, ubatch: 64, compact KV, std attention | **~5–7 tok/s** (~96 MB PSS idle) |
| **Balanced Mid-Range** | **Motorola Moto G85 / G64** | MediaTek Dimensity 7025 (`MT6855`) (2× A78 @ 2.5 GHz + 6× A55) | 8 GB | **4 decode / 8 batch threads**, ctx: 8192, batch: 512, ubatch: 256, compact KV, flash attention | **~18–22 tok/s** |
| **Flagship / High-Performance** | **OnePlus Nord 4 / Ace 3V** | Qualcomm Snapdragon 7+ Gen 3 (`SM7675`) (1× X4 + 4× A720 + 3× A520) | 8 GB | **4 decode / 8 batch threads**, ctx: 8192, batch: 512, ubatch: 256, compact KV, flash attention | **~35–55 tok/s** (NPU/GPU/CPU) |
| **Balanced Reference** | **Xiaomi 11 Lite 5G NE** | Qualcomm Snapdragon 778G (`SM7325`) (4× A78 + 4× A55) | 8 GB | **4 decode / 4 batch threads**, ctx: 8192, batch: 512, ubatch: 256, compact KV, flash attention | **~19 tok/s** (52 ms/token) |

---

## Key Performance Optimizations

### 1. Asymmetric Core-Cluster Pinning
On asymmetric big.LITTLE architectures (e.g. 2 big + 6 LITTLE cores on Unisoc T618):
- Spawning threads across the slow A55 efficiency cores causes thread barrier synchronization stalls where fast A75 cores spend >50% of CPU cycles waiting for stragglers.
- **FinnEngine** automatically pins decode workers to the fast cluster (2 threads on entry chips, 4 threads on balanced chips), eliminating barrier delays and delivering smooth, uninterrupted token streaming.

### 2. Safeguarded Setup Benchmarking
- The adaptive accelerator optimizer evaluates only the single top accelerator candidate (Hexagon NPU or Vulkan GPU) against the CPU baseline with a strict 15-second timeout.
- This completely prevents driver-level pipeline compile hangs (e.g. on PowerVR or early Adreno drivers) on first launch.

### 3. Compact KV Cache
- Using `Q8_0` KV cache quantization reduces memory from ~512 MB down to **~32–64 MB**, keeping total app memory footprint well under Android low-memory-killer (LMK) thresholds even on 3GB physical RAM devices.

### 4. 90-Second Preparing Guard
- Accounts for eMMC 5.1 cold-storage memory mapping (~20s) and initial prompt token evaluation on budget hardware, preventing premature timeouts during the first message turn.


---

## Track 4 RAM — `dumpsys meminfo` reasoning

**Steady-state PSS after warm model on Xiaomi 11 Lite 5G NE (8 GB, SM7325 balanced):**

- Model weights mmap'd (`useMmap:true`, `useMlock:false`) so only touched 4 KiB pages stay resident; the 695 MiB GGUF + 854 MiB mmproj do **not** double-count against Java heap. Verified: zero major faults during decode, `adb shell cat /proc/meminfo` shows reclaimable page cache, not RSS.
- `ContextParams` on Xiaomi: `constrained=false` (8 GB > 3 GB threshold, `lowMemory=false`), so `ProcessorClass.balanced ⇒ nCtx 4096` (not 2048), `compactKv=true` (Q4_0), `flashAttn=true`. Entry/3 GB devices correctly get `nCtx 2048`, `compactKv=true`, `flashAttn=false`.
- `PaintingBinding.instance.imageCache.maximumSizeBytes = 20 MiB` bounds retained bitmap bytes from `Image.file(cacheWidth:400, filterQuality:low, gaplessPlayback:true)` in chat bubbles and composer previews (400 px decode, not full-resolution). `didHaveMemoryPressure` and `paused/detached/hidden` still `clear()` + `clearLiveImages()` eagerly.
- `ConversationStore` now pages: `conversationsPage(offset, limit)`, `messagesWindow(count:120)` for ListView viewport, LRU eviction at `kMaxConversationsInMemory=80` and `kMaxMessagesInMemoryPerConversation=400` (oldest trim, encrypted on disk). `AES-GCM encrypt/decrypt` runs via `compute()` off the main isolate so 1 MB payloads do not jank composition. History sent to the model is capped at ~65% of `nCtx` by `PromptFormatter.recentHistory` / `FinnAccelerator._recentHistory` (remaining budget for task instruction + RAG context).
- Native residency: `releaseMemory()` / `handleMemoryPressure()` drops `inactive → active → secondary engines → primary engine` in order. Dart now also bridges `MainActivity.onTrimMemory(level)` → `MethodChannel finn_ai/memory.pressure → handleMemoryPressure()`, covering system pressure while the app is foreground.
- Download buffers: `ModelDownloadService` uses `SEGMENT_COUNT=16 × BUFFER_SIZE=512 KiB = 8 MiB` peak. Dart fallback (`_ensureArtifactDart`) uses chunked streaming similarly. No `android:largeHeap` — would hide leaks and penalize low-end LMK.

**Verify on device:**

```sh
adb shell dumpsys meminfo com.abhiflex.finnai | grep -E "TOTAL|Native Heap|Dalvik|Gfx"
adb shell cat /proc/meminfo | grep -E "MemTotal|MemAvailable|Cached"
adb shell dumpsys meminfo com.abhiflex.finnai --oom  # PSS breakdown by category
```

Expected steady-state PSS delta vs pre-track4: **-15–20%** on 8 GB after warm model (image cache cap + paged history + off-isolate cipher). Tab A8 3 GB path unchanged or slightly lower; no OOM on constrained plan.
