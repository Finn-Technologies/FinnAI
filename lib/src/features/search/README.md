# search — web grounding

**Purpose.** Fetch and shape web results so the model can answer with sources.

**Entry points.** `web_search_service.dart`, `tiny_browser.dart`, `search_agent.dart`, `shared_http_client.dart`.

**Invariants.**
- Keyless and on-device by default; no query goes to a server we operate (ADR 0002).
- One shared HTTP client and bounded caches. Don't create a per-call client.
- Direction: the app decides whether to search and runs one bounded search per turn; the model never emits tool calls in chat (ADR 0001). The current tool loop is being removed.
