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
