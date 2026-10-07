import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/layout/finn_layout.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';

/// The composer row of both apps, FinnAI's chat and FinnAI Code.
///
/// At [t] = 0 it is three controls: a 50dp [leading] circle, the field pill,
/// a 50dp [trailing] circle, 20dp apart. At [t] = 1 (the keyboard is up on a
/// phone, see `KeyboardFuse`) it is one panel: text on top, [leading]
/// bottom-left, [extra] and [trailing] bottom-right. Every value is
/// interpolated, so the curve's overshoot carries through; only transforms
/// and the pill's own box change, the controls are never rebuilt.
class FinnComposerFrame extends StatelessWidget {
  const FinnComposerFrame({
    super.key,
    required this.t,
    required this.field,
    required this.trailing,
    this.leading,
    this.extra,
    this.frameKey,
    this.tall = false,
  });

  /// 0 = three controls, 1 = one fused panel.
  final double t;

  /// What sits inside the pill: an attachment, then the text field.
  final Widget field;
  final Widget? leading;
  final Widget trailing;

  /// Shown beside [trailing] only once fused (the chat's mic).
  final Widget? extra;
  final Key? frameKey;

  /// The pill holds more than a line (an attachment): sheet corners.
  final bool tall;

  static const double circle = FinnCircleButton.dimension;
  static const double gap = 20;

  /// The panel's extra height once fused: the row the controls sit in.
  static const double fusedBar = 50;

  @override
  Widget build(BuildContext context) {
    double lerp(double a, double b) => a + (b - a) * t;
    final u = t.clamp(0.0, 1.0);
    final side = lerp(circle + gap, 0).clamp(0.0, circle + gap);
    final bar = lerp(0, fusedBar).clamp(0.0, 60.0);
    final radius = tall ? FluxRadius.sheet : lerp(circle / 2, 28);
    final extra = this.extra;
    final leading = this.leading;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: leading == null ? 0 : side,
            right: side,
          ),
          child: Container(
            key: frameKey,
            decoration: BoxDecoration(
              color: FluxColors.controlOf(context),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: FluxColors.lineOf(context), width: 1),
            ),
            constraints: BoxConstraints(
              minHeight: circle + bar,
              maxHeight: 220 + bar,
            ),
            // At rest the 48dp text band and the 1px border make the pill
            // exactly the circles' 50dp.
            padding: EdgeInsets.fromLTRB(
              lerp(17, 18),
              lerp(0, 8),
              lerp(4, 14),
              bar,
            ),
            child: field,
          ),
        ),
        // The leading circle travels into the panel's bottom-left corner; its
        // fill is the panel's, so once inside it reads as a bare glyph.
        if (leading != null)
          Positioned(
            left: lerp(0, 3),
            bottom: lerp(0, 3),
            child: Transform.scale(
              scale: lerp(1, .9),
              alignment: Alignment.bottomLeft,
              child: leading,
            ),
          ),
        if (extra != null && u > 0)
          Positioned(
            right: 52,
            bottom: 5,
            child: Opacity(
              opacity: Curves.easeOut.transform(((u - .45) / .55).clamp(0, 1)),
              child: Transform.translate(
                offset: Offset(12 * (1 - u), 0),
                child: extra,
              ),
            ),
          ),
        // Trailing keeps its fill and settles into the bottom-right corner.
        Positioned(
          right: lerp(0, 6),
          bottom: lerp(0, 6),
          child: Transform.scale(
            scale: lerp(1, .8),
            alignment: Alignment.bottomRight,
            child: trailing,
          ),
        ),
      ],
    );
  }
}

/// The text inside a composer pill: 16sp Geist, its hint at 55% ink, and a
/// band the full height of the pill that focuses the field, so the whole
/// visible field is a target and not only the 20dp line.
abstract final class FinnComposerText {
  static TextStyle style(BuildContext context) => TextStyle(
        fontFamily: 'Geist',
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w400,
        color: FluxColors.inkOf(context),
      );

  static TextStyle hintStyle(BuildContext context) => style(context).copyWith(
        color: FluxColors.inkOf(context).withValues(alpha: .55),
      );

  /// A container, and nothing more, for screen readers: it used to carry a
  /// label and the text-field flag without being one, so both merged into the
  /// full-screen node above it, and TalkBack read the empty chat as one
  /// screen-sized field whose label was the greeting. The field inside is the
  /// one text field ("Ask anything").
  static Widget band({
    Key? key,
    required FocusNode focusNode,
    required Widget field,
  }) =>
      Semantics(
        container: true,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          // The band is a touch target, not a second control: the field
          // keeps its own semantics, so a screen reader reads one field.
          excludeFromSemantics: true,
          onTap: focusNode.requestFocus,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            // Sized by the text, never by the pill's maximum.
            child: Center(
              heightFactor: 1,
              child: Padding(
                // Geist carries more space above its letters than below; see
                // FinnLayout.fieldTextLift.
                padding: EdgeInsets.only(bottom: FinnLayout.fieldTextLift),
                child: field,
              ),
            ),
          ),
        ),
      );
}
