# code — FinnAI Code

**Purpose.** A coding agent in FinnAI's design language: a second app inside the app, with its own sessions, settings and providers. It reads, writes and edits files in a private project folder and runs commands there (in a real Alpine Linux on Android: packages, git, builds), answered by the on-device model or by a cloud model the user brings a key for. You switch from the brand row of either sidebar. Decision: `docs/decisions/0010-finnai-code.md`.

**Entry points.**
- `code_shell.dart` — the screen (sliding sidebar, header, transcript, composer). `code_services.dart` — the stores, the agent and the model gateway, wired once.
- `agent/` — `agent_protocol.dart` (the text protocol: system prompt, parser, results back to the model), `code_agent.dart` (the bounded request loop, approvals, stop), `action_runner.dart` (carries an action out).
- `linux/` — the native Linux sandbox (ADR 0012): `linux_sandbox.dart` (proot + Alpine, one `run`), `linux_installer.dart` (pinned rootfs, apt shim). Preferred wherever it runs (Android arm64).
- `container/` — the emulated Linux container (ADR 0011), for platforms where `linux/` cannot run: `container_image.dart` (pinned downloads), `container_installer.dart`, `container_host.dart` (loopback server + socket), `container_view.dart` (the hidden WebView), `container_protocol.dart` (guest scripts, output framing), `workspace_sync.dart` (the project in and out as ustar), `container_shell.dart` (all of it as one `run`).
- `sandbox/` — `workspace.dart` (the project folder, exact path rules), `command_policy.dart` (what a command may not do), `shell_sandbox.dart` (runs it: timeout, size cap, empty environment).
- `providers/` — `code_provider.dart` (the six providers), `code_model.dart` (live model lists, per-provider parsers), `code_wires.dart` + `provider_client.dart` (three request shapes, streaming, fallback, allowance), `provider_store.dart` + `secret_store.dart` (keys in secure storage, model lists, selection), `gateways.dart` (on-device and cloud behind one interface).
- `sessions/` — `code_session.dart`, `code_session_store.dart` (plain JSON, one project folder per session).
- `settings/` — the Code settings pages. `ui/` — transcript, action card, composer, sidebar, models, files and terminal pages.

**Invariants.**
- **Nothing leaves the phone unless the user picked a cloud model.** The on-device model is the default, the first use of each provider shows a disclosure, and a reply from a cloud model carries a byline.
- **API keys live only in `CodeSecretStore`.** Only the last four characters are written to disk; never log a key or put one in an error message.
- **The project folder on the device is the truth.** The container works on a copy and only regular files come back; it can be restarted or removed without losing anything.
- **The file tool never uses the shell**, and every path goes through `CodeWorkspace.normalize`. The shell policy is defence in depth, not a boundary: do not describe it as one.
- **A request is bounded**: step limit, stop on a thrice-repeated action, one action per reply, a cut-off action never runs. Keep all four.
- **One request at a time**, and leaving the screen stops it.
- The agent protocol is plain text on purpose. Do not add function-calling for cloud models: it would fork the loop the on-device model depends on.
- Code imports no other feature (`tool/verify_boundaries.sh`). It reaches the engine only through `lib/src/inference/`.
