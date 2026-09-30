# actions — device actions (alarm, timer, torch, dial, open app, settings…)

**Purpose.** The closed set of things Finn may do on the phone, and the path from a request to a confirmed, audited action.

**Entry points.** `action_catalog.dart` (the only place an action is declared) → `action_matcher.dart` / `action_parser.dart` (request → invocation) → `device_action_resolver.dart` → `device_action_executor.dart` (Kotlin bridge) → `action_audit_store.dart`.

**Invariants.**
- Nothing here runs without a user tap or an explicit per-flow grant.
- The audit log stores action name, tier, outcome and source. Never prompt text, never arguments (a dialled number is user data).
- Adding an action means: catalog entry, resolver/executor case, `device_action_descriptions.dart` string, tests in `test/features/device_actions_test.dart`.

**Depends on.** Nothing else in `features/`. `flows` reads the catalog.
