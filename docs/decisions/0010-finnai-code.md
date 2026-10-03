# 0010 — FinnAI Code: a second app inside the app

**Status.** Accepted and implemented 2026-10-03.

**Context.** FinnAI is a private assistant. People also want what Codex and Claude Code give: an agent that reads and writes files in a project and runs commands. The on-device model (LFM2.5-VL 1.6B) can do a little of that; a cloud model can do a lot more, but only with the user's own key. Both need one place to live.

**Decision.** FinnAI Code is a separate mode with its own screens, sessions, settings and providers, in the same design language. `lib/src/features/code/` owns it. You switch from the brand row in either sidebar (`FinnBrandSwitcher`); `AppModeHost` shows one of the two and the choice is remembered (`AppModeController`). The two share the on-device model and the shared widgets (`finn_sidebar_surface.dart`, `finn_sidebar_parts.dart`, `finn_edge_fade.dart`) and nothing else: no chat reaches Code, no session reaches chat.

## The sandbox is a workspace shell, not a virtual machine

An app on Android cannot start a VM, and a real Linux userland (proot over Alpine) needs a bundled GPL binary plus a downloaded root filesystem, would not run on iOS or OpenHarmony, and Play Store policy forbids executing downloaded code from app storage. So each session gets a **project folder** and a **shell** confined to it:

- The shell is the phone's own (`/system/bin/sh`, toybox: `ls cat grep sed awk find sort tar gzip bc …`), run as the app's unprivileged user, with `HOME` and the working directory set to the project folder, an empty environment, a time limit (20 s default), and a 32 KB cap on what comes back (`ShellSandbox`).
- A static policy refuses programs that act on the device (`su am pm kill ln mount …`), network programs while network is off, absolute paths outside the folder, and `..` (`CommandPolicy`). It is **defence in depth, not a proof**: a shell can always be talked into something a token scan misses. What actually protects the device is the layers around it: commands wait for the user's tap by default, run unprivileged in a private folder, and the file tool never uses the shell and is exact (`CodeWorkspace`, symlink-checked).
- There is no python, node, git or compiler, and nothing can be installed. The system prompt and the settings say so. This is the honest limit of the approach.
- iOS cannot spawn a shell: file actions work, commands report "cannot run" (`ShellSandbox.supported`).

**What a real VM would take** if it is ever wanted: an `isolatedProcess` service or a bundled, licence-reviewed proot, a verified rootfs download (sha256, like the model), and a `CodeActionRunner` that routes to it. `CodeActionRunner` is the seam; nothing else changes.

## The agent speaks a text protocol, not function calls

The model acts by writing one fenced block (` ```sh ` or ` ```file path `) per reply and stopping; the result comes back as the next user message (`AgentProtocol`). A 1.6B model writes this reliably, every provider carries it with no tool-calling support, and a reply that breaks the format degrades to prose instead of failing. Guards, because a small model left alone loops:

- one action per reply; text after the action is dropped (it is a guess at an unseen result) and reading stops at the closing fence;
- a reply cut off inside its action is never run;
- a step limit per request (8 on device, 20 on a large cloud model; user setting);
- stop after the same action three times running;
- the user's stop button; leaving FinnAI Code stops the request.

This does not contradict ADR 0001. That rule keeps tool syntax out of **chat**, where one model-chosen search per turn was the failure. In Code the loop is the product, it is bounded as above, and its prompt is never used by chat.

## Permissions

`askEveryTime`, `acceptEdits` (the default: files are written as it goes, commands wait for a tap), `autoRun`. Network commands are a separate switch, off by default.

## Providers

OpenRouter, Command Code (GOAT or higher; the Go plan has no API access and is surfaced as such), OpenCode Zen, OpenCode Go, and a custom OpenAI-compatible server. Facts the code depends on, each checked against the live endpoint on 2026-10-03:

| Provider | Base | Models | Allowance |
|---|---|---|---|
| OpenRouter | `https://openrouter.ai/api/v1` | `GET /models` (names, context, prices) | `GET /key` (limit, remaining, usage); `GET /credits` needs a management key and is optional |
| Command Code | `https://api.commandcode.ai/provider/v1` | `GET /models` with `supported_endpoints` per model | no API: link to billing |
| OpenCode Zen | `https://opencode.ai/zen/v1` | `GET /models` (ids only) | no API |
| OpenCode Go | `https://opencode.ai/zen/go/v1` | `GET /models` (ids only) | no API |
| Custom | user's address | `GET /models` | none |

Model lists are public and are fetched live; a key is only proved by a request, so "Test key" sends one token, preferring a free model. Three request shapes are spoken (`/chat/completions`, `/messages`, `/responses`). Command Code states which each model supports; for OpenCode the shape is guessed from the id and, if the provider answers "wrong endpoint" before any text, the next shape is tried and the working one is remembered. **Not verified against a paid account:** no keys were available, so streaming through each provider is covered by recorded-shape tests, not by a live call.

## Privacy

FinnAI says nothing leaves the phone. Code keeps that true by default: the on-device model is selected until the user adds a key and picks a cloud model, and the first use of each provider shows a disclosure that the conversation, file contents and command output go to that provider (`acknowledgedCloud`). API keys live in platform secure storage (`CodeSecretStore`); only the last four characters are on disk. A custom address must be `https`, or `http` only for the user's own network (the key travels in a header). Replies from a cloud model carry a byline.

Sessions and project files are **plain files** in private app storage, not the AES-GCM conversation file: that store belongs to chat and importing it would add a feature-to-feature edge. A project folder is plain files by nature. If encryption at rest is wanted, move `ConversationCipher` to `shared/` and use it in `CodeSessionStore`.

"Delete all data" removes Code's sessions, folders, keys and settings (`CodeServices.deleteAll`).

**Consequences.** Chat is untouched apart from three extractions that Code shares (sidebar surface, sidebar tiles, edge fade) and a tappable brand row. Any new provider is a `CodeProvider` value, a parser in `code_model.dart`, and a row in the table above.
