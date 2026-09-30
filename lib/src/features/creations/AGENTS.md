# features/creations — rules for this directory

- Read `docs/architecture/CREATIONS.md` before editing.
- Generated text is never executed. No JS engine, no WebView, no `eval`. Values come from `SafeExpression` only.
- Caps live in `spec/spec_limits.dart`; the prompt and validator both read them.
- The model fills content; templates own layout and style. Colours and radii come from `FluxColors` / `FluxRadius`, not from a spec.
- `creations_page.dart` is oversized and may only shrink. New screens are new files.
- Saved artifacts are versioned; a shape change needs a migration and a test in `test/features/creations/`.
