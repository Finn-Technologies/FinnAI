# features/creations — rules for this directory

- Read `docs/architecture/CREATIONS.md` before editing.
- Generated text is never executed. No JS engine, no WebView, no `eval`. Values come from `SafeExpression` only.
- Caps live in `spec/spec_limits.dart`; the prompt and validator both read them.
- The model authors the whole creation. There are no templates: `creation_prompts.dart` describes the closed vocabulary (mini-app nodes and actions, widget kinds, deck themes and layouts) and the model writes the artifact itself. `creation_generator.dart` validates its JSON and gives it one repair round.
- A reply the validator rejects is re-prompted once with the exact problems. A second failure throws `CreationUnusable` and the user is asked to try again — never swap in a generic stand-in.
- Every limit in the prompt comes from `spec/spec_limits.dart`. Never hard-code a limit in prompt text.
- Prompts must not name a node type, action or widget kind that the parser does not accept; a test keeps the prompt and the enums in step.
- `creations_page.dart` is oversized and may only shrink. New screens are new files.
- Saved artifacts are versioned; a shape change needs a migration and a test in `test/features/creations/`.
- Widget state lives in native `SharedPreferences` and is changed only by `FinnHomeWidgetActions`. A new widget kind needs the Dart spec, the Kotlin kind, a layout, and a test on each side (`test/features/creations/interactive_widget_test.dart`).
- A mini app's saved state is sanitised on load (`MiniAppState.restore`: keys the spec declares, types coerced, size capped). Never trust the file.
