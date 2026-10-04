# FinnAI on desktop Linux

FinnAI runs on Linux (x86-64 and arm64) as a native GTK window. The model, download pipeline,
encrypted history, search, flows, creations and FinnAI Code all run there. The window adapts to its
size: a phone-width window looks like the phone app, a tablet-width one slides the sidebar over the
chat at a fixed width, and anything from 900 px up docks the sidebar beside the chat.

## Build

```bash
# 1. System packages (Fedora; Debian/Ubuntu names in parentheses)
sudo dnf install clang cmake ninja-build pkgconf-pkg-config gtk3-devel libsecret-devel \
  jsoncpp-devel git            # (clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev libjsoncpp-dev git)

# 2. The model runtime (llama.cpp), built once per architecture into linux/native/<arch>/
bash tool/rebuild_llama_linux.sh            # add --vulkan for GPU offload

# 3. The app
flutter config --enable-linux-desktop
flutter pub get
flutter run -d linux                        # or: flutter build linux --release
```

`flutter build linux` still works without step 2 (CMake prints a warning), but the app then cannot
load the model. The bundle lands in `build/linux/<arch>/release/bundle/`; its `lib/` holds the
runtime and `share/` has the `.desktop` file and icon for packagers.

## Where things are on Linux

| What | Where |
|---|---|
| Model and projector | `~/.local/share/com.abhiflex.finnai/models/` (`getApplicationSupportDirectory`) |
| Conversation key | The desktop keyring (libsecret). With no keyring running, a `0600` file in `…/secure/` — see `docs/architecture/SECURITY_AND_PRIVACY_ARCHITECTURE.md` |
| Native runtime | `<bundle>/lib/libllama.so` and siblings, loaded by absolute path (`DeviceProfile.llamaLibraryPath`) |
| Window size, icon, minimum size | `linux/runner/my_application.cc` |

## What works, what does not

| Feature | Linux |
|---|---|
| Chat, streaming, history, search, flows (timer triggers), creations, FinnAI Code | Yes |
| Image attachments | Yes, from a file (`file_picker`/`image_picker` use the desktop file dialog; needs `zenity` or `kdialog`). No camera entry |
| Read aloud | Yes, through `spd-say` (Speech Dispatcher) or `espeak-ng`/`espeak`, whichever is installed |
| Voice mode (speech in, Supertonic speech out) | **No.** `flutter_pcm_sound` and the `libfinn_tts` shim are Android-only. `voiceSupportedOnPlatform` stays false |
| Device actions (call, alarm, …), launcher widgets, share-selected-text, background flows with the app closed | No — these are Android integrations |
| Enter sends, Shift+Enter newline; Ctrl+N new chat, Ctrl+B sidebar, Ctrl+, settings | Yes |

## Window chrome

The native GTK title bar is removed. `FinnWindowFrame` (in `MaterialApp.builder`, so it frames every
screen and pushed page) draws FinnAI's own bar: mark and name on the left, which drag the window and
maximise on double-click, and minimise / maximise / close on the right. The bar has no colour of its
own: the screen runs underneath it (its `MediaQuery` top padding is the bar's height) so the bar is
always the screen's own background. The window has 14 px rounded corners and a hairline
(`FinnWindowFrame.cornerRadius`, which the onboarding artwork shares); that needs a compositing
window manager, otherwise the corners stay square. Invisible 5 px edges resize
it, F11 toggles full screen, and the bar goes black over the black welcome screen. The runner
exposes the window to Dart through the `finn_ai/window` channel
(`linux/runner/my_application.cc`, `lib/src/platform/window_chrome.dart`). Run with
`FINN_NATIVE_TITLEBAR=1` to keep the desktop's own title bar instead.

## Layout rules

`lib/src/shared/layout/finn_layout.dart` is the single source for window classes:
under 600 px is a phone, up to 900 px slides the sidebar over the chat at ≤ 340 px, from 900 px the
sidebar is docked (`FinnSidebarSurface(docked: true)`). Chat columns stay ≤ 760 px, sub-pages
(`FinnPageRoute`) are centred at ≤ 1000 px, and from 900 px the phone design's vertical offsets are capped
at 66% (`FinnLayout.scaleY`; 85% in the sidebars, whose icon row has a fixed height). Right-click opens the same menu as long-press. New screens should use `FinnLayout`, not their own
breakpoints.

## Storage

The model (696 MB) and its image projector (854 MB) are about 1.5 GB, and a download that runs the disk
full leaves a partial file behind that blocks the next attempt. On desktop Linux the app asks `df` how much
room the data directory has (`DesktopProfile.freeBytes`) and refuses a transfer that cannot fit, with a
reserve, before it starts ("Not enough free storage to download this model."). The speech model and voice
add-ons (about 560 MB) are not offered on Linux at all, since voice mode is mobile-only.

## Keyboard

Enter sends and Shift+Enter adds a line; Ctrl+N new chat, Ctrl+B sidebar, Ctrl+, settings; Esc or Alt+Left
closes a page; F11 full screen; in first-run, Enter and the arrow keys move between steps. The composer takes
focus when the app opens, after a reply and after a page closes. Steps and pages listen to the keyboard
directly (`HardwareKeyboard`) instead of relying on focus, which was not reliably inside a page that had just
opened.

## Known limits

- The persisted prompt-prefix cache is off on Linux (`FinnAccelerator._prefixCacheEnabled`). Restoring it from
  disk with the stock llama.cpp build made turns stop after a token or two; recomputing the ~120-token prefix
  each time costs nothing noticeable. Android and OpenHarmony keep it.
- Some flows and device-action strings still say "phone" ("Act on phone", "Phone starts up"): those are Android
  features that do not appear on Linux. The strings a desktop user sees were reworded to "device".
- Dark mode could not be exercised in the live app on the test machine (the app did not pick up a forced
  dark colour scheme); it is covered by the widget tests and rendered previews.

## Verification status

Verified on an aarch64 Fedora VM, in the real release app (headless sway for the rounded window, Xvfb with
xdotool for mouse and keyboard): the full first-run flow including a real model download that resumed after a
full disk, a multi-turn conversation answered by the on-device model, chat history, right-click, the attach
menu, settings and its sub-pages, Creations, Flows, You, FinnAI Code, the docked, slide-over and phone-width
layouts, maximise and restore, F11, and the transparent rounded window. `flutter analyze`, `dart format` and
the boundary checks pass, and `flutter test` shows no failures beyond the 14 golden tests and
`platform_target_test` that already fail on a clean checkout of this arm64 host.

Not verified: x86-64, the `--vulkan` option, dark mode in the live app, and minimise (nothing to see on a
headless display).
