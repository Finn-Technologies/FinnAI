# search — web grounding

**Purpose.** Fetch and shape web results so the model can answer with sources.

**Entry points.** `search_turn.dart` (plan + run), `search_policy.dart` (when to search), `web_search_service.dart` (endpoints), `search_agent.dart` (grounded context), `shared_http_client.dart`.

**Invariants.**
- Keyless and on-device by default; no query goes to a server we operate (ADR 0002).
- One shared HTTP client and bounded caches. Don't create a per-call client.
- The app decides whether to search (`SearchPlanner`) and runs one bounded search per turn (`SearchTurn`); the model never emits tool calls in chat (ADR 0001).
