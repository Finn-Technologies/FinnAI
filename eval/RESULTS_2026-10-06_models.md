# Which on-device vision model? — 2026-10-06

Device: Xiaomi Mi 11 Lite 5G NE (Snapdragon 778G, 7.4 GB RAM), CPU only, 4 threads — how FinnAI runs inference on Android. Upstream llama.cpp `65840ed` built for arm64 (`llama-completion`, `llama-mtmd-cli`, `llama-bench`). Greedy decoding. 49 auto-scored cases (`model_comparison/cases.json`): facts, math, reasoning, instruction following, code, FinnAI Code's file-action format, German/Spanish, 4 image questions (`eval/images/`), and 15 harder items. Scoring is keyword-based and lenient: read it as a ranking, not a benchmark. Raw outputs per case: `model_comparison/res_*.json`.

| Model (Q4) | Size + projector | Score | Prompt tok/s | Decode tok/s | Notes |
|---|---|---|---|---|---|
| **LFM2.5-VL 1.6B** (current) | 0.70 + 0.58 GB | 41/49 | **86** | **21.3** | concise (24 words/answer) |
| LFM2.5-VL 3B | 1.59 + 0.58 GB | 42/49 | 41 | 9.4 | same family; +1 |
| Qwen3-VL 2B Instruct | 1.11 + 0.45 GB | **44/49** | 51 | 13.0 | wordy (39 words/answer): 17 s/case |
| Qwen3.5 2B (thinking off) | 1.21 + 0.67 GB | 36/45 text | 48 | 10.5 | below the current model on text |
| Gemma 4 E2B | 2.84 + 0.56 GB | 44/49 | — | 8.2 | thinks by default (46 s/case); only model to follow the Code file format unaided (3/3) |
| Qwen3.5 4B | 2.58 GB | 38/45 text | — | 4.0 | thinks; 99 s/case |

**Decision: keep LFM2.5-VL 1.6B.** The best candidates gain 1–3 cases of 49 and cost half the decode speed and half the prompt speed, which doubles the first-token wait of every chat turn and every FinnAI Code step on this class of phone. No candidate is a better balance of intelligence, speed and size here. If intelligence matters more than speed, Qwen3-VL 2B is the pick (its architecture is already in the bundled llama.cpp; the engine's ChatML prompt fits it; nKeep is now measured, not hard-coded).

Revisit when Android inference leaves the CPU (GPU/NPU offload is disabled, see `device_optimizer.dart`) or for a high-end-only tier, where Gemma 4 E2B's agent-format adherence would be worth its size.
