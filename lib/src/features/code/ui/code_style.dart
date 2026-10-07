import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// FinnAI Code's own measures, for what only Code has: monospace code and
/// output, tool rows, diffs. Everything the two apps share (the composer, the
/// header, messages, the greeting) uses FinnAI's components at FinnAI's
/// sizes; tool rows stay tight so a run of actions reads as a log.
abstract final class CodeStyle {
  /// Monospace for code, commands and output.
  static const String mono = 'JetBrainsMono';
  static const String sans = 'Geist';

  // Type.
  static const double proseSize = 14;
  static const double monoSize = 12;
  static const double labelSize = 12.5;
  static const double metaSize = 11;

  // Rows and controls.
  static const double rowHeight = 30;
  static const double control = 36;
  static const double gutter = 14;
  static const double gap = 8;
  static const double radius = 10;

  // Motion: faster and subtler than the app's (FluxMotion), so a stream of
  // tool rows never feels like it is waiting on an animation.
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 180);
  static const Curve curve = Curves.easeOutCubic;

  static Duration motion(BuildContext context, [Duration value = base]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;

  static TextStyle code(BuildContext context, {Color? color}) => TextStyle(
        fontFamily: mono,
        fontSize: monoSize,
        height: 1.45,
        color: color ?? FluxColors.inkOf(context),
        // JetBrains Mono's ligatures turn `->` and `!=` into glyphs that are
        // not what the file holds.
        fontFeatures: const [FontFeature.disable('calt')],
      );

  static TextStyle prose(BuildContext context) => TextStyle(
        fontFamily: sans,
        fontSize: proseSize,
        height: 1.4,
        color: FluxColors.inkOf(context),
      );

  static TextStyle label(BuildContext context, {Color? color}) => TextStyle(
        fontFamily: sans,
        fontSize: labelSize,
        height: 1.2,
        color: color ?? FluxColors.inkOf(context),
      );

  static TextStyle meta(BuildContext context, {Color? color}) => TextStyle(
        fontFamily: mono,
        fontSize: metaSize,
        height: 1.2,
        color: color ?? FluxColors.mutedOf(context),
        fontFeatures: const [FontFeature.disable('calt')],
      );

  /// The well code sits in: a step darker (lighter in dark) than the canvas.
  static Color wellOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C22)
          : const Color(0xFFEDEDED);

  /// Diff line backgrounds and their sign colours. Measured so the text on
  /// them keeps 4.5:1 in both themes; the hue carries meaning only together
  /// with the + / − sign.
  static Color addedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF15301F)
          : const Color(0xFFDDF3E3);
  static Color removedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF3A1A1C)
          : const Color(0xFFF8DEDD);
  static Color addedSignOf(BuildContext context) =>
      FluxColors.successOf(context);
  static Color removedSignOf(BuildContext context) =>
      FluxColors.destructiveOf(context);
}
