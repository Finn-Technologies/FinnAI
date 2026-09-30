# onboarding — first run and upgrades

**Entry points.** `onboarding_flow.dart` (oversized; split before adding), `context_consent_store.dart`.

**Invariants.**
- Consent has no default. Next is disabled until Yes or No is chosen; skipping must never opt the user in.
- The Yes/No answers stay pinned on screen; only the explanation scrolls.
- Target: the user is never trapped on the download step (pause/skip). Verify current behaviour before relying on it.
