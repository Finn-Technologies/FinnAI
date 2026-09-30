# flows — user-controlled automations

**Purpose.** A flow is an ordered list of steps with a trigger (manual now, scheduled next). Runs are logged.

**Entry points.** `flow_model.dart` (data, v2 schema), `flows_store.dart` (persistence + v1→v2 migration), `flow_runner.dart`, `flows_page.dart`.

**Invariants.**
- A flow cannot act on the device without a grant. Enforced in three places (shape check, manual run, scheduled run), each with a test. Keep all three.
- The run log holds no model text.
- Nothing runs unless the user enabled the flow. Steps use the same search policy and engine facade as chat; a flow has no tool loop of its own.
