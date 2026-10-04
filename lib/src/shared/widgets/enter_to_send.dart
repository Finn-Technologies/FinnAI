import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/platform/platform_target.dart';

/// Makes Enter send and Shift+Enter add a line on a desktop keyboard.
///
/// A multiline [TextField] only ever inserts a newline on Enter, which is right
/// on a phone's on-screen keyboard (it has a send key) and wrong with a
/// physical one, where every chat app sends on Enter. On a phone this widget is
/// transparent: it adds no [Focus] and handles no keys.
class EnterToSend extends StatelessWidget {
  const EnterToSend({
    super.key,
    required this.onSend,
    required this.canSend,
    required this.child,
    bool? enabled,
  }) : _enabled = enabled;

  /// Sends the draft. Called only when [canSend] is true.
  final VoidCallback onSend;

  /// False while the draft is empty or a reply is being written. Enter is then
  /// swallowed rather than inserting a line, so it never half-sends.
  final bool canSend;

  final Widget child;
  final bool? _enabled;

  @override
  Widget build(BuildContext context) {
    if (!(_enabled ?? isDesktop)) return child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final enter = event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter;
        if (!enter) return KeyEventResult.ignored;
        final keyboard = HardwareKeyboard.instance;
        // Shift+Enter is the newline; Ctrl/Alt/Meta+Enter are left to the
        // platform rather than guessed at.
        if (keyboard.isShiftPressed ||
            keyboard.isControlPressed ||
            keyboard.isAltPressed ||
            keyboard.isMetaPressed) {
          return KeyEventResult.ignored;
        }
        if (canSend) onSend();
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
