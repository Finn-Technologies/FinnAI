# flows — user-controlled automations

**Purpose.** A flow is an ordered list of steps with a trigger (manual now, scheduled next). Runs are logged.

**Entry points.** `flow_model.dart` (data, v2 schema), `flows_store.dart` (persistence + v1→v2 migration), `flow_runner.dart` (runs steps through the ports in `flow_ports.dart`), `flow_templates.dart`, `flow_schedule.dart` + `flow_scheduler.dart` (alarms), `flows_page.dart`.

Two kinds of flow share the store: *skills* (instructions that shape chat, at most four enabled) and *automations* (flows with steps). An automation's prompts are for its own runs and never reach chat.

**Invariants.**
- A flow cannot act on the device without a grant. Enforced in three places (shape check, manual run, scheduled run), each with a test. Keep all three.
- The run log holds no model text.
- Nothing runs unless the user enabled the flow. Steps use the same search policy and engine facade as chat; a flow has no tool loop of its own.
