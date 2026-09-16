# Creations

A creation is a **runnable artifact** built by the on-device model from a plain-language brief.
There are three kinds, and they are genuinely different things rather than three labels on the same
document:

| Kind | What it is | Where it runs |
|---|---|---|
| **App** | A sandboxed declarative screen spec | `MiniAppHost`, rendered as real Flutter widgets |
| **Widget** | A small label/value layout | A native Android launcher widget, via `RemoteViews` |
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

### Mini-app vocabulary

`spec/mini_app_spec.dart`: `text`, `button`, `field`, `toggle`, `slider`, `list`, `progress`,
`choice`, `image`, `row`, `column`, `spacer`.

Actions are the only mutation primitives: `set {key, expr}`, `toggle {key}`, `increment {key, by}`,
`append {key, value}`, `reset`.

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

`creation_generator.dart`, driven from `creations_controller.dart`:

1. **Designing** — build a kind-specific, JSON-only prompt (`creation_prompts.dart`) that enumerates
   the closed vocabulary and the caps, with one compact example.
2. **Writing** — one bounded engine call at `temperature ≈ 0.15` with the search-decision pass
   disabled, so the budget is never spent on a tool call.
3. **Parsing** — `json_salvage.dart` strips `<think>` blocks and fences, skips browser tool calls,
   and salvages a reply that was truncated mid-object.
4. **Validating** — `spec_validator.dart` returns `List<SpecIssue>`; nothing throws.
5. **Repairing** — on issues, re-prompt **once** with the concrete error list appended.
6. **Fallback** — still invalid ⇒ a deterministic starter (`creation_fallbacks.dart`) that actually
   works, plus a quiet note in the transcript.

Failure is therefore graceful: the worst case is a working counter instead of a bespoke app.

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

---

## 4. Home-screen widgets (Android only)

The launcher renders `RemoteViews`, which understands text, images, a progress bar and a click
intent — no arbitrary widgets, and no generated code. So the widget spec is deliberately narrow
(`spec/widget_spec.dart`): a title, up to four label/value rows, a footer.

```
Dart                                        Kotlin
────                                        ──────
HomeScreenService.writeWidgetSpec()   ──▶   <filesDir>/creations/home_widgets/<creationId>.json
HomeScreenService.addWidgetToHomeScreen()
  ├── stagePendingWidget(specPath)    ──▶   SharedPreferences: pending spec path
  └── requestPinWidget()              ──▶   AppWidgetManager.requestPinAppWidget
                                            FinnHomeWidgetProvider.onUpdate
                                              └── claims the pending spec for the new id
                                                  FinnHomeWidgetRenderer → RemoteViews
```

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
  injectable `CreationCompletion` so every path (valid, repair, fallback) is reachable without a
  native engine.
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
