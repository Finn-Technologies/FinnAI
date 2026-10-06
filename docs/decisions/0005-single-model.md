# 0005 — One model, pinned

**Status.** Superseded by ADR 0013 (two tiers, one per device), 2026-10-06.

**Decision.** Exactly one catalog entry (`finnModels.single`). Download, verification, storage, settings and deletion key off one artifact identity. Changing `downloadUrl`, `expectedBytes` or `sha256Digest` requires verification against Hugging Face LFS metadata.

**Consequences.** No model picker on mobile. A quantisation change needs measured proof it keeps speed, RAM and heat.
