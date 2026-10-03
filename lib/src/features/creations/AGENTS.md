# features/creations — rules for this directory

- Read `docs/architecture/CREATIONS.md` before editing.
- Generated text is never executed. No JS engine, no WebView, no `eval`. Values come from `SafeExpression` only.
- Caps live in `spec/spec_limits.dart`; the prompt and validator both read them.
- The model fills content; templates own layout and style. Colours and radii come from `FluxColors` / `FluxRadius`, not from a spec.
- A new template is a class in `templates/` plus an entry in `CreationTemplates.all`, keywords in several locales, l10n keys for its name and slot labels, and it must pass the fuzz test in `test/features/creations/templates_test.dart` (valid from fallbacks, examples and hostile input).
- Every slot limit is stated in the prompt from the same slot definition. Never hard-code a limit in prompt text.
- Slot text must never contain `{` or `}`: a brace would inject a `{key}` placeholder.
- `creations_page.dart` is oversized and may only shrink. New screens are new files.
- Saved artifacts are versioned; a shape change needs a migration and a test in `test/features/creations/`.
- Widget state lives in native `SharedPreferences` and is changed only by `FinnHomeWidgetActions`. A new widget kind needs the Dart spec, the Kotlin kind, a layout, and a test on each side (`test/features/creations/interactive_widget_test.dart`).
- A mini app's saved state is sanitised on load (`MiniAppState.restore`: keys the spec declares, types coerced, size capped). Never trust the file.
