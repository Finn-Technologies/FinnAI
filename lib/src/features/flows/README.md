# flows — local automations

**Purpose.** A flow is a tree of blocks run by a trigger: ask the model, search the web, notify, speak, run a device action, wait, branch (yes / otherwise), save to chat, stop. Triggers are time (daily, weekly) and device events (charger, battery low, headset, Wi-Fi), with optional "only if" conditions. Runs are logged. Decision: `docs/decisions/0009-flows-v3.md`.

**Entry points.** `flow_model.dart` + `flow_blocks.dart` + `flow_triggers.dart` + `flow_conditions.dart` (data), `flows_store.dart` + `flows_codec.dart` (persistence, migrations), `flow_runner.dart` (runs blocks through the ports in `flow_ports.dart`), `flow_scheduler.dart` + `flow_schedule.dart` + `flow_environment.dart` (arming triggers, device state), `flow_phrases.dart` / `flow_script.dart` / `flow_author.dart` (a flow from a sentence), `flow_editor_page.dart` + `flow_chart.dart` (the flowchart editor), `flows_page.dart`.

Every flow is an automation: a tree of blocks with (usually) triggers. A flow's prompts are for its own runs and never reach chat.

**Invariants.**
- A flow cannot act on the device without a grant. Enforced in three places (shape check, user-started run, automatic run), each with a test. Keep all three.
- User-started runs may ask for permission; automatic runs use only the stored standing grant. Background runs (app closed) stop at an action that needs the screen.
- The run log holds no model text.
- Nothing runs unless the user enabled the flow. Blocks use the same search policy and engine facade as chat; a flow has no tool loop of its own.
