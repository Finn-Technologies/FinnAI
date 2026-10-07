import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The message surface of both apps: the user's solid pill, or the softly
/// cornered card a notice or an error sits on. Flat in both themes: the fill
/// and a 1px hairline separate it from the canvas, never a shadow.
class FinnBubbleBox extends StatelessWidget {
  const FinnBubbleBox({
    super.key,
    required this.user,
    required this.child,
  });

  final bool user;
  final Widget child;

  static BorderRadius radiusFor({required bool user}) => user
      ? BorderRadius.circular(FluxRadius.pill)
      : const BorderRadius.only(
          topLeft: Radius.circular(19),
          topRight: Radius.circular(19),
          bottomLeft: Radius.circular(19),
          bottomRight: Radius.circular(5),
        );

  /// The text of a message: 16sp on a 1.25 line box.
  static TextStyle textStyle(BuildContext context, {bool user = false}) =>
      TextStyle(
        fontFamily: 'Geist',
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w400,
        color: user ? FluxColors.inkOf(context) : null,
      );

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(
          maxWidth: math.min(MediaQuery.sizeOf(context).width * .82, 620),
        ),
        padding: user
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 15)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: user
              ? FluxColors.bubbleUserOf(context)
              : FluxColors.cardOf(context),
          borderRadius: radiusFor(user: user),
          border: Border.all(color: FluxColors.lineOf(context), width: 1),
        ),
        child: child,
      );
}

/// "Retry" (or "Continue") under a failed reply: a 48dp text button.
class FinnRetryButton extends StatelessWidget {
  const FinnRetryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onPressed,
        icon: const FluxIcon(icon: FluxIcons.refresh, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: FluxColors.inkOf(context),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 48),
        ),
      );
}
