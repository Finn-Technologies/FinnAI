---
name: finn-feature
description: Add or modify a user-facing screen, flow or string in FinnAI following the project's layered structure, theming and localization rules. Use when the task involves UI, a new page, a dialog, a settings row, onboarding copy, or any text the user will read.
when_to_use: Building a feature screen, adding a settings option, wiring navigation, or adding/changing user-visible strings in any of the five supported locales.
---

# Adding a feature to FinnAI

## Where code goes

| Kind of change | Location |
|---|---|
| A new screen/flow | `lib/src/features/<feature>/` (one folder per feature) |
| Shared UI primitives | `lib/src/shared/widgets/` |
| Theme tokens | `lib/src/shared/theme/flux_theme.dart` |
| App-wide state | `lib/src/app/` |
| Anything native/model related | `lib/src/engine/` — see the `finn-engine-seam` skill |

Feature folders currently in use: `chat/`, `onboarding/`, `conversations/`, `search/`, `settings/`,
`skills/`, `you/`, `creations/`, `voice/`, `reporting/`.

## Steps

1. **Read a sibling first.** `lib/src/features/skills/skills_page.dart` is a good template: it shows
   the header, scroll structure, loading/empty/error states, and dialog conventions.

2. **Reuse the shared shell.** Use `FinnPageHeader` for the page title, and `FluxColors`,
   `FluxRadius`, `FluxGlass`, `FluxIconButton`, `FluxPillButton` from
   `lib/src/shared/widgets/flux_controls.dart`. Do not hardcode colors or radii — use the
   `FluxColors.*Of(context)` resolvers so light/dark both work.

3. **Route through the app's page transition.** Sub-pages are pushed with `_FinnPageRoute` from
   `lib/src/features/chat/home_shell.dart`. Entry points for the existing sub-pages live in that
   file's sidebar.

4. **Localize every string.** Add the key to `lib/l10n/app_en.arb` with a description, then add the
   translation to `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_it.arb`. Run `flutter pub get` to
   regenerate `lib/l10n/app_localizations*.dart` — **never edit the generated files.**
   Read strings with `L10n.of(context).yourKey`.

5. **Cover the states.** Every screen needs a loading, empty and error state. Swallowed errors are
   treated as bugs in this codebase — if an operation can fail, tell the user and offer a retry.

6. **Keep long work off the UI isolate and cancellable.** Anything that can take more than a few
   hundred milliseconds (I/O, parsing a large payload, generation) belongs behind a controller or
   the engine, not inline in `build()` or a tap handler.

7. **Test it.** Widget tests go in `test/features/`. If the screen renders in a golden, expect to
   regenerate: see `docs/guides/TESTING.md`.

## House style

- `const` everywhere it compiles.
- Prefer `SelectionArea`/`SelectableText` over custom selection hacks.
- Icon-only buttons need a semantics label or a tooltip; touch targets should reach ~48 dp even if
  the visual is smaller (wrap in padding, don't shrink the hit area).
- Don't add comments that restate the code. Comment the *why* only when it is non-obvious.

## Gates

```bash
dart format .
dart analyze .
flutter test
```
