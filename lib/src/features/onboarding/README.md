# onboarding — first run and upgrades

**Entry points.** `onboarding_flow.dart` (oversized; split before adding), `context_consent_store.dart`.

**Invariants.**
- The download step installs the language model and then any `InstallAddon` (today: the speech model) through `model_install.dart`, with one progress value. The language model is required; an add-on failing never blocks the user. Onboarding must not import `voice`; the app layer injects add-ons.
- Consent has no default. Next is disabled until Yes or No is chosen; skipping must never opt the user in.
- The Yes/No answers stay pinned on screen; only the explanation scrolls.
- Target: the user is never trapped on the download step (pause/skip). Verify current behaviour before relying on it.

**Wide windows.** From 720 x 440 up (`wideStepFits`), every step is drawn by `wide_step.dart` instead of the phone card: a rounded artwork pane on the left (title on the image, in the phone card's type), the copy and Back / Next pills on the right, Enter and the arrow keys to move, and a "Get started" button instead of the swipe. `_StepPage` and `ContextChoosePage` hand the same arguments to `WideStepLayout`, so a step does not know which it is. The phone layout is untouched.
