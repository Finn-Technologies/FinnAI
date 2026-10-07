import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// iOS-style bouncing with a much lighter touch. Overscroll drags meet about
/// 40% more resistance, and the bounce-back spring is stiffer and more damped,
/// so fast flings no longer throw headings or text far past the top and bottom
/// edges before settling back into view.
class FluxBouncingScrollPhysics extends BouncingScrollPhysics {
  const FluxBouncingScrollPhysics({super.parent});

  @override
  FluxBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      FluxBouncingScrollPhysics(parent: buildParent(ancestor));

  @override
  double frictionFactor(double overscrollFraction) =>
      math.pow(1 - overscrollFraction, 2) * 0.3;

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.5,
        stiffness: 200,
        // Damping ratio 1.8 against the stiffer 200 stiffness.
        damping: 36,
      );
}

/// The heading above a group of related rows. Every page that groups rows uses
/// this one widget, so the same idea does not look like two different things
/// depending on the screen.
class FluxSectionLabel extends StatelessWidget {
  const FluxSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    // The label is rendered exactly as it was translated.
    //
    // This used to call `.toUpperCase()`, which broke three of the five shipped
    // locales: German capitalises only nouns ("Über dich" became "ÜBER DICH",
    // capitalising the accusative pronoun), and the transform cannot know a
    // locale's casing rules from a plain Dart String. The English template
    // already ships these section names in caps ("AI MODEL", "STORAGE & DATA"),
    // so the design language is unchanged in English, and every other locale now
    // shows correctly-cased text with the same weight and tracking.
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: FluxColors.secondaryInkOf(context),
            ),
      ),
    );
  }
}
