import 'package:flutter/material.dart';

import 'package:finn_ai/src/platform/platform_target.dart';

/// Drives a composer's "fused" state: 0 while its controls sit side by side,
/// 1 while the keyboard is up and they have merged into one panel.
///
/// It follows the keyboard rather than focus alone: it fuses as the keyboard
/// starts rising and separates as soon as it starts going down, so the panel
/// never waits for the keyboard to finish. The keyboard is read from the
/// physical view, because a Scaffold that resizes for it hides the inset from
/// its body's MediaQuery. Desktops have no on-screen keyboard and never fuse.
class KeyboardFuse with WidgetsBindingObserver {
  KeyboardFuse(
    this._state, {
    required TickerProvider vsync,
    required this.focusNode,
    bool Function()? allowed,
  }) : _allowed = allowed ?? (() => true) {
    controller = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 300),
    );
    value = CurvedAnimation(
      parent: controller,
      curve: const Cubic(.25, .9, .3, 1.03),
      reverseCurve: Curves.easeInOutCubic,
    );
    focusNode.addListener(sync);
    WidgetsBinding.instance.addObserver(this);
  }

  final State _state;
  final FocusNode focusNode;
  final bool Function() _allowed;

  late final AnimationController controller;

  /// [controller] on the fuse curve, which lands with a hair of overshoot.
  late final CurvedAnimation value;

  double _lastKeyboard = 0;
  double _goal = 0;

  /// True while fused or on the way to it: the composer can lay out for the
  /// fused panel (send in place of mic, say) from the first frame.
  bool get fusing => _goal == 1;

  /// Re-reads the keyboard and focus. Call from `didChangeDependencies` and
  /// whenever [_allowed]'s inputs change.
  void sync() {
    if (!_state.mounted) return;
    final context = _state.context;
    final keyboard = View.of(context).viewInsets.bottom;
    final closing = keyboard < _lastKeyboard - .5;
    _lastKeyboard = keyboard;
    final target = !isDesktop &&
        _allowed() &&
        focusNode.hasFocus &&
        keyboard > 0 &&
        !closing;
    final goal = target ? 1.0 : 0.0;
    if (goal == _goal && (controller.isAnimating || controller.value == goal)) {
      return;
    }
    _goal = goal;
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_state.mounted) controller.value = goal;
      });
    } else if (target) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }

  @override
  void didChangeMetrics() => sync();

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    focusNode.removeListener(sync);
    value.dispose();
    controller.dispose();
  }
}
