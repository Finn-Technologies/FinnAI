# 0013 — Two model tiers, one per device

**Status.** Accepted 2026-10-06. Supersedes ADR 0005.

**Decision.** The catalog holds two tiers of LiquidAI's LFM2.5-VL, each with its own pinned vision projector (they are not interchangeable):

| Tier | Model (Q4_0) | Projector (F16) | Total |
|---|---|---|---|
| `standard` | LFM2.5-VL 1.6B, 696 MB | 854 MB | ≈1.55 GB |
| `plus` | LFM2.5-VL 3B, 1,594 MB | 854 MB | ≈2.45 GB |

`ModelTierPolicy` gives `plus` to a device with at least 7.3 GB of RAM (an "8 GB" phone reports 7.3–7.7) **and** either a chipset on its list (Snapdragon 845/855/865/888/8-series, 778G and newer 7-series, Dimensity 1100/1200/7200/7300/8000+/9000+, Kirin 980/990/8000/9000-series, Exynos 2100+, Tensor) or, for chips it does not name, a CPU score at Snapdragon 845 level (sum of core design weight × clock, from `/proc/cpuinfo` and `cpuinfo_max_freq`; 845 ≈ 13.7, threshold 13.5). Everything else gets `standard`. A device downloads only its selected tier.

The choice is stored (`models/tier`). Without a stored choice a model already on the device keeps its tier, so an app update never starts a surprise 2 GB download; `betterTierAvailable` lets the app offer the upgrade. `chooseTier` switches, the caller installs, then `removeOtherTiers` deletes the old tier.

**Evidence.** On a Snapdragon 778G (the tier's entry point, `eval/RESULTS_2026-10-06_models.md`): the 3B scored 42/49 against 41/49, with 6/6 facts and 13/15 on the hard set, and decodes at 9.4 tok/s against 21.3 (prompts 41 vs 86 tok/s). The DSpark speculative-decoding draft LiquidAI ships for the 3B made it slower on CPU (9.2 tok/s at 3 drafted tokens, 5.8 at 8), so it is not used. On faster chips the gap narrows.

**Consequences.** Every surface that names the model reads `FinnAccelerator.selected`. The context-shift `nKeep` is measured per session, not assumed from the 1.6B's tokenizer. HarmonyOS does not let the app read `/proc/cpuinfo`, so there the chipset name decides.
