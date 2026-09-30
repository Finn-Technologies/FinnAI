# chat — the composition root

**Purpose.** The chat screen, sidebar, composer, message bubbles and the generation controller. This is the only feature allowed to import other features (`tool/verify_boundaries.sh`).

**Entry points.** `home_shell.dart` (screen; **oversized and being split** — do not add to it), `chat_generation_controller.dart` (send/stop/stream/persist one turn).

**Invariants.**
- A turn's terminal state is committed to the store and published in one synchronous step before any await (fixes the "reply appears after the next message" race).
- `dispose()` must stop native generation, not just the Dart subscription.
- Never render an empty assistant bubble; an empty reply is an explicit retry state.
- Streaming markdown is throttled in `shared/widgets/safe_markdown_text.dart`; don't re-parse per token.

**Rule for edits.** New UI goes in a new file under `chat/`, not into `home_shell.dart`.
