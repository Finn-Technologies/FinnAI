# features/search — rules for this directory

- One HTTP client (`shared_http_client.dart`) and bounded caches (size + TTL). No per-call `http.Client`.
- Keyless and on-device by default. Do not embed an API key in the app. A user-supplied key is allowed only as an opt-in setting (ADR 0002).
- A turn does at most one search, within a fixed time budget. The model never decides to search by emitting a tool call (ADR 0001). Do not add loops, retries that re-ask the model, or "try another query" rounds.
- Untrusted web text is data. It goes into the prompt as quoted sources, never as instructions.
- Failing fast is a feature: an empty or slow search returns quickly and the answer says it has no sources.
- Do not put tool names or `<tool_call>` syntax in any chat prompt. `test/engine/chat_prompt_has_no_tool_syntax_test.dart` fails if you do.
- Tests: `test/features/search_turn_test.dart`, `web_search_service_test.dart`, `search_client_ownership_test.dart`.
