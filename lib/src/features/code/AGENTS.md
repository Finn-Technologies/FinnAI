# features/code — rules for this directory

Read the root `AGENTS.md` and `docs/decisions/0010-finnai-code.md` first.

- **Adding a provider:** a `CodeProvider` value (name, base URL, key and billing pages), a parser in `CodeModelParsers`, a row in the ADR table. Verify the `/models` response and the error shape against the live endpoint, and record what you could not verify.
- **Changing the agent protocol** (`agent_protocol.dart`) changes what a 1.6B model sees: keep the system prompt under about 400 tokens (a test pins 1500 characters) and run the on-device model against it before and after. A parser change needs a test in `test/features/code/agent_protocol_test.dart`.
- **Anything that runs a command** goes through `CodeActionRunner` → `ShellSandbox` → `CommandPolicy`. Adding a program to `CommandPolicy.blockedPrograms` is cheap and safe; removing one is a security decision, write it up.
- **Strings** go through `L10n.of(context)` and the five ARB files. Brand names (`OpenRouter`, `Command Code`, `OpenCode Zen`) are not translated.
- **Tests that touch the shell** run `/bin/sh` on the host; keep them hermetic (temp directories, no network).
- Files stay under 600 lines. No ICU plurals in new ARB entries (the parity test cannot compare them); use a separate key per form.
- Focused tests: `flutter test --no-pub test/features/code/`.
