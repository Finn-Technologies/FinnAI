# 0001 — The app decides when to search; the model only answers

**Status.** Accepted and implemented 2026-09-30.

**Context.** The model emits `<tool_call>` text to search. The only loop guard is stopping on an exactly repeated call. A user reported a reply looping on tool calls: a 1.6B model varies the query slightly, or emits calls in the answer turn. The workaround is a system message asking it to stop.

**Decision.** A deterministic `SearchPolicy` (prompt, history, and a composer toggle) decides whether to search. At most one bounded search runs per turn; then one answer pass with sources. The model is never shown tool syntax in chat. Flows use fixed step pipelines.

**Root cause found while implementing.** The base system prompt advertised `browser_search` / `browser_open` / `browser_find` on *every* turn, but only turns classified "advanced" had a loop to execute them. On every other turn the model emitted a call into its answer and the output filters swallowed it, producing a blank reply or a run of calls. Removing the advertisement (`systemPromptVersion` 12) is the actual fix; `test/engine/chat_prompt_has_no_tool_syntax_test.dart` keeps it removed.

**Consequences.** A loop is structurally impossible. Browse recall now depends on the policy and is measured by the eval, which runs the same planner as the app (the eval previously bypassed it, which is why recall read 0.0). The parser, tool executor, decision prompt, decision grammar and `TinyBrowser` are deleted. `BareToolCallFilter` and `ToolTagFilter` stay as a safety net on model output. Device actions still use one model-emitted `<tool_call>` (a single call that becomes a confirm card, never a loop).
