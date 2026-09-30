# creations — decks, mini apps, launcher widgets

**Purpose.** Runnable artifacts built from a short brief. Read `docs/architecture/CREATIONS.md` first.

**Entry points.** `templates/` (catalog, slots, prompts), `creation_generator.dart` (brief → template → artifact), `creations_controller.dart`, `spec/` (closed vocabulary + validator), `runtime/` (mini-app renderer), `deck/` (viewer + `.pptx` writer), `home_screen_service.dart` (launcher widgets).

**Invariants.**
- Generated text is never executed. Only `SafeExpression` computes values; there is no JS engine and no WebView.
- `spec_limits.dart` is the single source of caps; the prompt and the validator must agree.
- Template-first (ADR 0003): the app picks a template, the model only fills typed slots (`templates/`), every value is sanitised, and every template is valid by construction. Decks stay free-form with a closed theme and layout list.
