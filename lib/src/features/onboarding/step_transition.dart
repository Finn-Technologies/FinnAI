import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Turns a [PageView]'s sideways slide into a step change that stays put.
///
/// The steps share their frame — card on top, copy, controls at the bottom —
/// so sliding whole screens past each other moves everything that is about
/// to come back in the same place. Instead each page cancels the slide and
/// fades through: the outgoing step drifts a little toward the way it is
/// leaving and fades, the incoming one drifts in from the other side, settles
/// from a hair smaller, and fades up once the first is mostly gone.
class StepTransition extends StatelessWidget {
  const StepTransition({
    super.key,
    required this.controller,
    required this.index,
    required this.span,
    required this.child,
  });

  final PageController controller;
  final int index;

  /// The step being left and the step being entered while a change runs.
  /// A change can skip a step (consent "No" goes straight to the end); the
  /// steps in between stay hidden rather than flashing past.
  final ValueListenable<(int, int)?> span;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([controller, span]),
        child: child,
        builder: (context, child) {
          if (!controller.hasClients ||
              !controller.position.hasContentDimensions) {
            return child!;
          }
          final page = controller.page ?? index.toDouble();
          final width = controller.position.viewportDimension;
          final cancel = (page - index) * width;
          // Where this step is in the change, -1..1, whatever its distance.
          var delta = page - index;
          final moving = span.value;
          if (moving != null && moving.$1 != moving.$2) {
            final (from, to) = moving;
            if (index != from && index != to) {
              return const SizedBox.shrink();
            }
            final p = ((page - from) / (to - from)).clamp(0.0, 1.0);
            final dir = (to - from).sign.toDouble();
            delta = index == from ? p * dir : (p - 1) * dir;
          }
          if (delta.abs() >= 1) return child!;
          final visible = 1 - delta.abs();
          // Fade through: nothing of either step past the middle third.
          final opacity =
              Curves.easeOut.transform(((visible - .38) / .62).clamp(0, 1));
          final settle = Curves.easeOutCubic.transform(visible);
          return Transform.translate(
            offset: Offset(cancel - delta.sign * 36 * (1 - settle), 0),
            child: Transform.scale(
              scale: .985 + .015 * settle,
              child: Opacity(opacity: math.max(0, opacity), child: child),
            ),
          );
        },
      );
}
