# 0004 — A Lite tier for 4 GB devices

**Status.** Accepted 2026-09-30. Not yet implemented.

**Context.** The artifacts are about 1.55 GB (model 696 MB, projector 854 MB) plus KV cache. Minimum supported device: 4 GB RAM, about 2019 chip.

**Decision.** `DevicePolicy` tiers Lite / Standard / Full from `device_profile.dart`. Lite loads text-only, loads the projector lazily on the first image and unloads it after, uses 2048 context, no prewarm, fewer replayed turns, and reduced motion.

**Consequences.** Every performance gate is measured per tier. Image chat is slower on Lite; that is accepted.
