# ADR 0012 — FinnAI Code's Linux sandbox: proot + Alpine, native

**Status:** accepted, 2026-10-06. Supersedes ADR 0011 on Android; the v86 container stays for platforms where this cannot run.

## Context

ADR 0011 gave Code an emulated x86 Linux (v86 in a WebView). It worked, but:

- **No network, no packages.** busybox only: no python, git, compiler, `apk`. An agent that cannot install what a project needs cannot do most real tasks.
- **Slow.** A cold boot was 20–60 s; every command copied the project in and out as a tar.
- **Emulated.** x86 interpreted in JavaScript: a build ran 10–50× slower than the phone.

The user asked for package installs (apt/pip/npm), git clone and builds in the sandbox, isolated from the host's files and credentials.

## Decision

Run a real **Alpine Linux aarch64** userland on the phone's own CPU under **proot** (ptrace-based path translation, no root):

- `proot` and its loader are built from pinned sources (`tool/build_proot_android.sh`: termux/proot `a179d3e`, talloc 2.4.2 linked statically, NDK r28, 16 KB pages) and shipped as `jniLibs/arm64-v8a/libproot.so` and `libproot-loader.so`. An app targeting API 29+ may only execute files from its native-library folder; proot's loader then *maps* Alpine's binaries from app storage, which Android allows (checked on a Mi 11 Lite 5G NE, Android 16, inside the app's own process: direct exec of an app file is denied, `linker64`-style mapping works).
- The root filesystem is Alpine's official minirootfs **3.24.2** (3.8 MB), downloaded on demand and pinned by size and SHA-256 like the model; unpacked with the device's `tar` into `rootfs.new` and renamed into place.
- Each command: `proot --kill-on-exit -0 --link2symlink -r rootfs -b /dev -b /proc -b /sys -b <project>:/workspace -w /workspace /usr/bin/env -i <fixed env> /bin/sh -c <command>`. The project folder is **mounted, not copied**; the filesystem (installed packages) persists across commands and sessions.
- Network is the phone's. `/etc/resolv.conf` names public resolvers (Android's DNS is not reachable from a resolv.conf). `apt`/`apt-get` are shims onto `apk`; `PIP_BREAK_SYSTEM_PACKAGES=1` lets `pip install` work.
- Output streams to the transcript and terminal as it arrives. Package managers, clones and builds get a 10-minute limit; everything else keeps the user's setting.

## What it isolates, and what it does not

- The commands see Alpine's `/`, the project at `/workspace`, and the kernel views `/dev`, `/proc`, `/sys`. No other device path is mounted: not shared storage, not other sessions' folders, not FinnAI's own files.
- The app's environment (and so any token or path in it) is not passed in: `env -i` with a fixed list.
- Everything runs as the **app's own unprivileged user**. proot's root is pretend.
- **proot is not a security boundary against a hostile program.** Path translation can be escaped by a program written to do so (for example through `/proc/<pid>/root` of the tracer), and anything that escapes has exactly the app's permissions. API keys are in the Android Keystore-backed secure storage, conversations are AES-GCM with a Keystore key; neither is readable as plain files. The defences that matter stay as before: commands wait for a tap unless the user chose otherwise, and a cloud model's output is the user's to approve.

## Consequences

- **Google Play policy risk.** Play's Device and Network Abuse policy forbids an app from downloading executable code from outside Play; Alpine's binaries (and everything `apk`/`pip`/`npm` installs) are such code. ADR 0010 rejected proot partly for this reason. Termux-style apps are distributed outside Play or under specific review. Before a Play release, decide: ship the sandbox only in non-Play builds (F-Droid, direct APK), gate it behind a build flag, or get the policy question answered. The v86 path (WebAssembly in a WebView) does not have this problem.
- Android arm64 only. OpenHarmony and anything without the binaries fall back to the v86 container (ADR 0011), then to the device shell.
- First command after setup: ~0.2 s (was a 20–60 s boot). `apk add python3 git`: ~10 s on the Mi 11 Lite.
- Licences: proot GPL-2.0 (source pinned in the build script; `THIRD_PARTY_NOTICES.md`), talloc LGPL-3.0 (static, source pinned), Alpine packages under their own licences, downloaded by the user's action.
