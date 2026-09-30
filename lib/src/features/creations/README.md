# creations — decks, mini apps, launcher widgets

**Purpose.** Runnable artifacts built from a short brief. Read `docs/architecture/CREATIONS.md` first.

**Entry points.** `creation_generator.dart` (brief → validated spec), `creations_controller.dart`, `spec/` (closed vocabulary + validator), `runtime/` (mini-app renderer), `deck/` (viewer + `.pptx` writer), `home_screen_service.dart` (launcher widgets).

**Invariants.**
- Generated text is never executed. Only `SafeExpression` computes values; there is no JS engine and no WebView.
- `spec_limits.dart` is the single source of caps; the prompt and the validator must agree.
- Direction (ADR 0003): template-first. The model picks a template and fills typed slots.
