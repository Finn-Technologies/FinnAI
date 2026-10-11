# Creations

A creation is a **runnable artifact** built by the on-device model from a plain-language brief.
There are three kinds, and they are genuinely different things rather than three labels on the same
document:

| Kind | What it is | Where it runs |
|---|---|---|
| **App** | A sandboxed declarative screen spec | `MiniAppHost`, a full-screen page (no app bar), its state saved between launches |
| **Widget** | A small layout with a *kind* (display, counter, checklist, tracker) | A native Android launcher widget, via `RemoteViews`; interactive kinds work with the app closed |
| **Presentation** | A slide deck | The in-app deck viewer, and exported as a real `.pptx` |

Everything is local. Nothing a creation does leaves the device.

---

## 1. Why a spec and not code

The model is a 1.6B Q4 GGUF. It cannot be trusted to emit Dart, and the app deliberately ships **no
JavaScript engine and no WebView**. So the model writes a *closed* JSON vocabulary that a validator
understands and an interpreter renders.

The consequence is the important part: **app code never executes generated text**. The only thing
that can compute a value is `SafeExpression`, a recursive-descent parser over integers
(`+ - * / %`, parentheses, literals, state keys). There is no `eval`, no `dart:mirrors`, no
`dart_eval`. An expression the parser cannot read is a *validation error*, not a runtime hazard.

> The component vocabulary below is the model's own language. It writes it directly; the validator
> only decides whether what it wrote can run.

### Mini-app vocabulary

`spec/mini_app_spec.dart`: `text`, `button`, `field`, `toggle`, `slider`, `list`, `progress`,
`choice`, `image`, `row`, `column`, `spacer`.

Actions are the only mutation primitives: `set {key, expr}`, `toggle {key}`, `increment {key, by}`,
`append {key, value, clear?}`, `reset`. An `append` value may contain `{key}` placeholders read when
the button is pressed, and `clear` empties a key afterwards: `{"value":"{draft}","clear":"draft"}`
adds what was typed and clears the field, which is what lets a notes or shopping list exist.

Text nodes interpolate state with `{key}`; expressions are arithmetic only.

### Caps

`spec/spec_limits.dart` holds every limit in one place, because the **prompt and the validator must
agree** — a spec that satisfies the instructions must never be rejected for a limit it was not told
about. 40 nodes, depth 3, 60 characters per label, 4 widget rows, 12 slides, 6 bullets per slide.

### Styling is not in the spec

A spec may choose one accent from a closed set. Colours, radii and text styles come from
`FluxColors`/`FluxRadius`. This is why generated creations look like they belong to Finn, and why
there is no path by which a spec can inject arbitrary styling.

---

## 2. Generation pipeline

The model is the author. One bounded engine call writes the whole artifact in the closed vocabulary
above, and the validator decides whether it can run. Each kind has its own JSON shape, stated in
`creation_prompts.dart`:

| Kind | What the model writes |
|---|---|
| App | `title`, one `accent`, and a tree of nodes wired with actions (`nodes`) |
| Widget | `title`, `accent`, a `kind` (display, counter, checklist, tracker), its `rows`, and `step`/`goal` where the kind uses them |
| Presentation | `title`, `summary`, one `theme`, and `slides` with a `layout` each |

`creation_generator.dart`, driven from `creations_controller.dart`:

1. **Prompting** — `CreationPrompts.build` states the kind's shape, every limit taken from
   `SpecLimits`, and the closed lists the model may choose from (node types, actions, widget kinds,
   deck themes and layouts). The brief closes the prompt, after the format and any repair note,
   because a small model continues from what it read most recently.
2. **Writing** — one engine call at `temperature ≈ 0.7`: creative enough that two different briefs do
   not collapse to the same most-likely output.
3. **Parsing** — `json_salvage.dart` strips `<think>` blocks and fences, skips browser tool calls, and
   salvages a reply truncated mid-object.
4. **Validating** — `SpecValidator` runs on the decoded JSON before any spec object is constructed. It
   returns every problem, not just the first: unknown node types, keys that are read but never
   written, out-of-range numbers, over-long text, and expressions `SafeExpression` cannot parse.
5. **Repairing** — any issues earn one more call that quotes them back and asks for the whole object
   again (stage `repairing`). A second failure throws `CreationUnusable`; the page shows a localized
   "try again", and **nothing generic is substituted**. That is the one deliberate cost of letting the
   model author the creation: a 1.6B model sometimes needs the second try, and when it still does not
   get there the honest answer is a retry, not a stock counter.

### Stages and cancellation

`CreationStage` (`designing → writing → validating → repairing`) drives the progress bubble.
Cancellation is epoch-based and the controller tolerates a load finishing after disposal, because
closing the screen mid-load is normal.

---

## 3. Storage and migration

`creation_store.dart` writes `version: 2` with a sealed `CreationArtifact`
(`MiniAppArtifact` / `WidgetArtifact` / `PresentationArtifact` / `LegacyDocumentArtifact`).

**Version 1 records are migrated, not quarantined.** A v1 creation was only a title, summary and
`{heading, body}` sections, so it becomes a `LegacyDocumentArtifact` — it keeps rendering, and it
keeps the `kind` it was filed under so the gallery filter does not silently move it. `_quarantine`
stays reserved for genuinely corrupt JSON.

Records written during the template era carried an extra `template: {id, slots}` key beside the
artifact. It is ignored on load: the artifact is already the finished creation, so those creations
keep rendering with no migration.

---

## 4. Home-screen widgets (Android only)

The launcher renders `RemoteViews`, which understands text, images, a progress bar and a click
intent — no arbitrary widgets, and no generated code. So the widget spec is deliberately narrow
(`spec/widget_spec.dart`): a title, up to four label/value rows, a footer, and a **kind**
(`HomeWidgetKind`: `display`, `counter`, `checklist`, `tracker`).

**Interactive widgets.** `RemoteViews` cannot run our code but it can send a tap to a receiver. Each
interactive control is a `PendingIntent` broadcast (`FinnHomeWidgetActions.ACTION_TAP`, extra
`finn_widget_op`: `OP_MINUS`=1, `OP_PLUS`=2, `OP_RESET`=3, `OP_ROW`+index for a row). The receiver
applies the op to a small state record kept in `SharedPreferences` (`FinnHomeWidgetStore`) and redraws
from it — it never calls into Dart, so it works with the app closed and after the process is killed
(not after the user force-stops the app: Android withholds broadcasts until the next launch). The
rules (a counter never goes below zero, a reset returns to the definition) are pure functions in
`FinnHomeWidgetActions.apply`. Editing a creation bumps a `rev` so a placed widget re-reads its
definition and resets state; `HomeScreenService.updateWidget` refreshes it. Pinning an app uses a
launcher shortcut, which opens the creation through `takeLaunchCreation` / `listenForShortcuts`.

```
Dart                                        Kotlin
────                                        ──────
HomeScreenService.writeWidgetSpec()   ──▶   <documents>/creations/home_widgets/<creationId>.json
HomeScreenService.addWidgetToHomeScreen()
  ├── stagePendingWidget(specPath)    ──▶   SharedPreferences: pending spec path
  └── requestPinWidget()              ──▶   AppWidgetManager.requestPinAppWidget
                                            FinnHomeWidgetProvider.onUpdate
                                              └── claims the pending spec for the new id
                                                  FinnHomeWidgetRenderer → RemoteViews
```

`<documents>` is `getApplicationDocumentsDirectory()`, **not** `filesDir` — the absolute path is
written by Dart and handed to native, so the two sides agree by construction. Native never
reconstructs the path itself: if the `SharedPreferences` mapping is lost, the widget renders its
placeholder rather than guessing.

Key points:

- The provider is created by the **framework**, so it must render with the Flutter engine stopped. It
  reads the JSON from disk on every update and never calls into Dart.
- Android assigns a widget id only *after* the pin is accepted, and `onUpdate` receives no extras
  from the pin request. The hand-off is therefore a single staged "pending" spec, claimed by the
  first widget that appears. The spec filename is the creation id, which a widget id cannot
  reconstruct, so the stored mapping is the only source of truth — if it is lost (app data cleared),
  the widget shows a prompt instead of stale content.
- The accent colour is resolved to ARGB on the Dart side, so Kotlin needs no colour table.
- `requestPinAppWidget`/`requestPinShortcut` both need API 26, which is the app's floor.
- Pinning an **app** uses a launcher shortcut instead, since an app cannot be a widget.
- R8 is enabled in release, and the framework instantiates providers reflectively — hence
  `-keep class com.abhiflex.finnai.FinnHomeWidgetProvider { <init>(); }`.

**OpenHarmony has no `forms`/`ExtensionAbility` equivalent**, so home-screen widgets are Android only:
`HomeScreenService.isSupported()` returns false and the UI hides the affordance rather than failing.

Exported `.pptx` files are shared through a `FileProvider`
(`androidx.core.content.FileProvider`, authority `${applicationId}.fileprovider`) restricted by
`res/xml/file_paths.xml` to `<filesDir>/creations/`.

---

## 5. Presentations and `.pptx`

`deck/pptx_writer.dart` emits a complete OOXML package:

```
[Content_Types].xml, _rels/.rels
docProps/{core,app}.xml
ppt/presentation.xml (+ rels), presProps.xml, theme/theme1.xml
ppt/slideMasters/slideMaster1.xml (+ rels)
ppt/slideLayouts/slideLayout1.xml (+ rels)
ppt/slides/slideN.xml (+ rels)
```

Static boilerplate is held as constants, and every piece of model-authored text is escaped through
`XmlText` — hand-concatenating titles and bullets is how exporters break on an `&`. The output is
verified by unzipping it in tests and by opening it with an independent OOXML reader; the real check
is opening it in PowerPoint.

`DeckExportService` writes to `<documents>/creations/exports/<slug>.pptx` with a collision-safe name,
then hands the file to the system share sheet.

---

## 6. Testing notes

- Spec/validator/expression/pipeline/pptx tests are plain unit tests; the generator takes an
  injectable `CreationCompletion` so every path (valid, repair, and a second failure) is reachable
  without a native engine.
- **`test/features/creations/creations_page_test.dart` runs on `LiveTestWidgetsFlutterBinding`.**
  The page loads its store from disk on open, and real file I/O never completes under the default
  binding's fake clock. Any future widget test for this page must do the same, or inject a
  pre-loaded controller.
- Golden tests are not used here; the page has no golden baseline.

## 7. Known gaps

- Mini-app state is in memory for the lifetime of the screen; it is not persisted per app.
- The home-screen widget mapping in native `SharedPreferences` is not cleared by "delete all data"
  (the spec files are, since they live under the creations folder). An affected widget renders its
  placeholder, which is the correct behaviour for missing content.
- Creations do not yet research the web before writing a spec.
