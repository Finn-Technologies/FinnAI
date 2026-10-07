import 'package:flutter/material.dart';

/// The hues FinnAI uses to tell destinations apart at a glance.
///
/// The neutral ramp (`FluxColors`) carries text and surfaces; these carry
/// identity: a settings row, a sidebar shortcut, a "+" sheet entry. They are
/// the Flows step colours (`flow_block_picker.dart`), so a hue means the same
/// thing everywhere it appears.
enum FluxHue {
  violet,
  blue,
  sky,
  teal,
  green,
  amber,
  orange,
  pink,
  red,
  indigo,
  graphite
}

/// Gradient pairs for [FluxHue], drawn as a filled well under a white glyph.
///
/// Every stop keeps a white glyph at 3:1 or more (WCAG non-text contrast),
/// checked by `test/shared/flux_vivid_test.dart`; the top stop is the lighter
/// one, so the well reads as lit from above.
abstract final class FluxVivid {
  static List<Color> of(FluxHue hue) => switch (hue) {
        FluxHue.violet => const [Color(0xFF9B6BFF), Color(0xFF7135F0)],
        FluxHue.blue => const [Color(0xFF4F86FF), Color(0xFF2155E8)],
        FluxHue.sky => const [Color(0xFF1C93E0), Color(0xFF0A6FC2)],
        FluxHue.teal => const [Color(0xFF14958F), Color(0xFF0B7A75)],
        FluxHue.green => const [Color(0xFF1F9A50), Color(0xFF13803F)],
        FluxHue.amber => const [Color(0xFFC77F00), Color(0xFFAD6500)],
        FluxHue.orange => const [Color(0xFFEE6216), Color(0xFFD9480C)],
        FluxHue.pink => const [Color(0xFFF0479A), Color(0xFFCF1F78)],
        FluxHue.red => const [Color(0xFFF0534B), Color(0xFFD12C25)],
        FluxHue.indigo => const [Color(0xFF7076FF), Color(0xFF4A47E0)],
        FluxHue.graphite => const [Color(0xFF7C7C84), Color(0xFF5E5E66)],
      };

  /// The hue as one colour, for a glyph or a line on a neutral surface.
  static Color solid(FluxHue hue) => of(hue).last;

  /// The brand's three-stop sweep (violet → blue → pink), for the few places
  /// that speak for FinnAI itself: the greeting and the send button.
  static const brand = <Color>[
    Color(0xFF8B5CFF),
    Color(0xFF4F7BFF),
    Color(0xFFFF5FA8),
  ];

  /// [brand] darkened so a white glyph on it keeps 3:1 (the send button).
  static const brandDeep = <Color>[
    Color(0xFF7A45F5),
    Color(0xFF3E66F0),
    Color(0xFFE83E8C),
  ];
}

/// A round well filled with a [FluxHue] gradient and a white glyph.
class FluxIconWell extends StatelessWidget {
  const FluxIconWell({
    super.key,
    required this.hue,
    this.icon,
    this.child,
    this.size = 44,
    this.iconSize = 22,
  }) : assert(icon != null || child != null);

  final FluxHue hue;
  final IconData? icon;

  /// Drawn instead of [icon], already coloured (e.g. an SVG in white).
  final Widget? child;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = FluxVivid.of(hue);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        // A hairline of light along the rim, so the well reads as glass on
        // pure black instead of a flat disc.
        border: Border.all(
          color: Colors.white.withValues(alpha: .14),
          width: .8,
        ),
      ),
      alignment: Alignment.center,
      child: child ?? Icon(icon, size: iconSize, color: Colors.white),
    );
  }
}
