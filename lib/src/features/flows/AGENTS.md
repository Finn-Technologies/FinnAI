# features/flows — rules for this directory

- A flow that acts on the device requires a grant. The check exists in the shape validator, the manual run and the scheduled run. Do not remove or bypass any of the three; each has a test in `test/features/flow_runner_test.dart`.
- The run log stores counts, step ids and outcomes. Never model text or prompts.
- Steps run through the search policy and engine facade used by chat. Do not add a tool loop or a private model call path here.
- Changing the saved shape means a schema version bump plus a migration test in `test/features/flows_store_test.dart`.
- Scheduling is user-enabled only. No trigger may start work for a flow the user has not enabled.
