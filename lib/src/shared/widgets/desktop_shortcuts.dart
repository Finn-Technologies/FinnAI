import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/platform/platform_target.dart';

/// The window-level keyboard shortcuts of a desktop shell: Ctrl+N for a new
/// chat, Ctrl+B to show or hide the sidebar and Ctrl+, for settings (Cmd on
/// macOS). Transparent on a phone, where there is no hardware keyboard to ask.
class DesktopShortcuts extends StatelessWidget {
  const DesktopShortcuts({
    super.key,
    required this.onNew,
    required this.onToggleSidebar,
    required this.onSettings,
    required this.child,
    bool? enabled,
  }) : _enabled = enabled;

  final VoidCallback onNew;
  final VoidCallback onToggleSidebar;
  final VoidCallback onSettings;
  final Widget child;
  final bool? _enabled;

  @override
  Widget build(BuildContext context) {
    if (!(_enabled ?? isDesktop)) return child;
    final mac = finnPlatform == FinnPlatform.macos;
    SingleActivator key(LogicalKeyboardKey k) =>
        SingleActivator(k, control: !mac, meta: mac);
    return CallbackShortcuts(
      bindings: {
        key(LogicalKeyboardKey.keyN): onNew,
        key(LogicalKeyboardKey.keyB): onToggleSidebar,
        key(LogicalKeyboardKey.comma): onSettings,
      },
      // Keeps focus on the composer: the bindings fire from the focused field
      // upward, and a separate focus scope here would steal it.
      child: child,
    );
  }
}
