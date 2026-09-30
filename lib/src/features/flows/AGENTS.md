# features/flows — rules for this directory

- A flow that acts on the device requires a grant. The check exists in the shape validator, the manual run and the scheduled run. Do not remove or bypass any of the three; each has a test in `test/features/flow_runner_test.dart`.
- The run log stores counts, step ids and outcomes. Never model text or prompts.
- Steps run through the search policy and engine facade used by chat. Do not add a tool loop or a private model call path here.
- Changing the saved shape means a schema version bump plus a migration test in `test/features/flows_store_test.dart`.
- Scheduling is user-enabled only. No trigger may start work for a flow the user has not enabled.
- `flows/` reaches the engine, search and conversation store only through the ports in `flow_ports.dart`; the real ones are wired in `chat/flow_wiring.dart`. Do not import those features here.
- A prompt step that follows browse steps with no gathered sources must not call the model (it would invent them). The run fails instead. Keep the `no sources` test green.
- A `browse` step's text may start `news:` or `weather:` to use that provider.
- A step that fails, is refused or is declined ends the run: nothing after it (notification, device action) may run.
- Notification permission is requested only when a scheduled flow is enabled, after our own explanation. Never at install.
- Native alarms are inexact on purpose (no SCHEDULE_EXACT_ALARM). `FlowScheduler.kt`'s next-occurrence rule mirrors `FlowSchedule.nextRun`; change both or neither.
