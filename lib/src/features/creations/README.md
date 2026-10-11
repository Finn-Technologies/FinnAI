# creations — decks, mini apps, launcher widgets

**Purpose.** Runnable artifacts built from a short brief. Read `docs/architecture/CREATIONS.md` first.

**Entry points.** `creation_prompts.dart` (what the model is told to write), `creation_generator.dart` (brief → model-authored artifact, validated and repaired), `creations_controller.dart`, `spec/` (closed vocabulary + validator), `runtime/` (mini-app renderer), `deck/` (viewer + `.pptx` writer), `home_screen_service.dart` (launcher widgets and shortcuts), `creation_launcher.dart` (open / add to home / export), `creation_request.dart` ("make me an app" typed in chat).

**Invariants.**
- Generated text is never executed. Only `SafeExpression` computes values; there is no JS engine and no WebView.
- `spec_limits.dart` is the single source of caps; the prompt and the validator must agree.
- The model authors the whole creation: it writes the mini-app nodes and behaviour, the widget rows and kind, or the slides. There are no templates and no slot filling. `creation_generator.dart` validates the model's JSON and gives it one repair round; if that still fails the user is asked to try again, and nothing generic is substituted.
- A mini app opens full screen with no app bar (`runtime/mini_app_host.dart`) and its state is saved per app (`runtime/mini_app_persistence.dart`, under `CreationStore.appStateDirectory()`); deleting a creation or all data deletes that state.
- An interactive home-screen widget changes through fixed taps handled natively (`FinnHomeWidgetActions.kt`); it never calls into Dart, so new widget behaviour means a new `HomeWidgetKind` on both sides.
- Creations can be made from chat: `creation_request.dart` recognises the request, the chat shows a card (`conversations/message_card.dart`) that opens the result. Questions about making things are never intercepted.
