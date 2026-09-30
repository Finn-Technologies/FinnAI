# 0001 — The app decides when to search; the model only answers

**Status.** Accepted 2026-09-30. Not yet implemented; the current tool loop is in `lib/src/engine/finn_accelerator.dart` (`while (toolActivities.length < maxToolRounds)`).

**Context.** The model emits `<tool_call>` text to search. The only loop guard is stopping on an exactly repeated call. A user reported a reply looping on tool calls: a 1.6B model varies the query slightly, or emits calls in the answer turn. The workaround is a system message asking it to stop.

**Decision.** A deterministic `SearchPolicy` (prompt, history, and a composer toggle) decides whether to search. At most one bounded search runs per turn; then one answer pass with sources. The model is never shown tool syntax in chat. Flows use fixed step pipelines.

**Consequences.** A loop is structurally impossible. Browse recall now depends on the policy, so it is measured by the eval (Suite D). Tool-call parsing and filtering code is deleted.
