import 'package:flutter/material.dart';

import 'package:finn_ai/src/features/chat/home_shell.dart';
import 'package:finn_ai/src/features/code/code_shell.dart';
import 'package:finn_ai/src/shared/config/app_mode.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// Shows FinnAI or FinnAI Code, whichever is selected, and swaps between them
/// when the brand switcher in either sidebar changes it.
///
/// Only one of the two exists at a time. The old screen is removed at once and
/// the new one fades in from the canvas, so the two never overlap: each owns
/// platform channel handlers that a late `dispose` would otherwise clear out
/// from under the other.
class AppModeHost extends StatelessWidget {
  const AppModeHost({super.key, this.controller});

  /// Overridable for tests; the real app has one.
  final AppModeController? controller;

  @override
  Widget build(BuildContext context) {
    final modes = controller ?? AppModeController.instance;
    return ListenableBuilder(
      listenable: modes,
      builder: (context, _) => switch (modes.mode) {
        FinnAppMode.chat => const _FadeIn(
            key: ValueKey('mode-chat'),
            child: HomeShell(),
          ),
        FinnAppMode.code => const _FadeIn(
            key: ValueKey('mode-code'),
            child: CodeShell(),
          ),
      },
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: FluxMotion.pageDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}
