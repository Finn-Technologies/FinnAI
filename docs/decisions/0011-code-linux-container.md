# 0011 — FinnAI Code runs commands in an emulated Linux container

**Status.** Accepted and implemented 2026-10-05. Supersedes the "workspace shell, not a virtual machine" section of ADR 0010 for every platform that has a WebView (Android, OpenHarmony, iOS, macOS); the workspace shell remains the fallback.

**Context.** ADR 0010 ran the agent's commands in the device's own shell (`/system/bin/sh`, toybox), confined by a policy and a private folder. That has three problems: the tools differ per device (toybox on Android, GNU on Linux, none on iOS), the policy is "defence in depth, not a proof", and iOS cannot spawn a process at all. The user asked for commands to run in a Linux container that works on any OS. ADR 0010 rejected proot over Alpine: it needs a bundled GPL binary, runs only on Android/Linux, and executing downloaded native code from app storage conflicts with Play policy.

**Decision.** Commands run in **v86**, an x86 PC emulator compiled to WebAssembly, booting a small Linux (kernel 6.8 + busybox) inside a hidden WebView. Nothing native is executed: the WebView's JavaScript engine interprets/JITs WebAssembly, which every platform's store allows, and the same machine behaves the same way on Android, iOS and macOS.

| Piece | Where it comes from | Licence |
|---|---|---|
| Emulator (`libv86.js`, `v86.wasm`), page `runtime.html` | bundled in `assets/code_container/` (npm `v86@0.5.470`, commit `6db8b15`) | BSD-2-Clause |
| Linux kernel + busybox (`bzimage.bin`, 10 068 480 B) | downloaded once from `https://i.copy.sh/buildroot-bzimage68.bin` | GPL-2.0 |
| SeaBIOS / VGA BIOS (131 072 B, 36 352 B) | downloaded once from `copy/v86@6db8b15/bios/` on GitHub | LGPL-3.0 |

Downloads are pinned by size and SHA-256 in `ContainerImage` and verified while streaming (`ContainerInstaller`), like the model. The user starts the download from Code settings → Linux container (9.8 MB); until then commands use the device shell as before.

## How a command runs

1. `ContainerHost` starts a loopback HTTP server on a random port; every path sits behind a random 24-character token. It serves only the page, the emulator and the three pinned files.
2. `ContainerView` (in `MaterialApp.builder`, above the navigator so it stays painted under any Code page) loads that page in a 1×1, near-transparent WebView. The page opens a WebSocket back to the host and relays the serial console and the 9p shared folder. All decisions are in Dart.
3. The project folder is packed as a POSIX ustar (`WorkspaceSync`; `package:archive` writes a v7 header busybox refuses) and written to the share; `run.sh` unpacks it over a fresh `/mnt/p`, runs the command through a pipe (no tty, so no colour codes), prints a nonce-framed exit code, and packs the project back. The host applies the result: changed files written, vanished files deleted. Links, special files and paths out of the folder are never brought back. Executable bits are kept in `.tmp/container-modes.json`, because not every device file system stores them.
4. Markers are printed with `printf` and an argument, so the console's echo of the command line can never forge one. A command past its time limit gets Ctrl-C, then a separate pull; if the console does not answer, the machine is restarted and the device folder stays as it was.

The device folder is the truth at every step. The container is disposable: restarting it, removing it, or leaving FinnAI Code (which stops it) loses nothing.

## Consequences

- **Isolation is real.** A command runs on an emulated CPU with only a copy of the project; it cannot reach the device. `CommandPolicy` is not applied inside the container (it still guards the device shell). There is no network in the guest.
- **Same tools everywhere:** busybox ash, sed, awk, grep, vi, tar, gzip, find, sort, diff… The system prompt names them when the container is active (`AgentProtocol.systemPrompt(container: true)`). There is still no python, node, git or compiler — that needs a larger image (see below).
- **Speed.** Boot is ~2 s on a laptop and a few seconds on a phone; a command round trip is ~1 s, most of it the tar copy. The project is capped at 24 MB per copy.
- **Platforms.** Android and OpenHarmony (both verified on emulators, 2026-10-05), iOS and macOS through `webview_flutter`. OpenHarmony uses the SIG's ArkWeb implementation, `webview_flutter_ohos`, as a direct dependency pinned to a commit, with `webview_flutter_platform_interface` overridden to the upstream version (the SIG's app-facing fork cannot be used: its Android side needs the v1 embedding Flutter 3.41 removed). Linux desktop has no WebView plugin, so commands use the device shell there, which is already a real Linux.
- **Warm start.** Code boots the machine in the background when it opens (if installed and enabled), so the first command rarely waits for a cold boot; leaving Code stops it.
- **Android** permits cleartext only to `127.0.0.1` (`res/xml/network_security_config.xml`) so the WebView can reach the host.
- **Hosting risk.** The kernel image is served by the v86 project's own host. If it moves, downloads fail verification-safe (no image, device shell keeps working); mirroring it next to the model on Hugging Face would remove the dependency.

**Growing the image.** A Buildroot image with python/git can be built with v86's own tooling and pinned the same way (`ContainerImage.artifacts`); nothing else changes. The guest has no network by design; adding it would need v86's network relay and a privacy decision of its own.
