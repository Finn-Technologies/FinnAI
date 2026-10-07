import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// A small orb of the brand's colours, turning and breathing, for "Finn is
/// working on it". [t] is a 0..1 phase that repeats (a controller on
/// `repeat()`); one turn of colour per cycle.
class FinnThinkingOrb extends StatelessWidget {
  const FinnThinkingOrb({super.key, required this.t, this.size = 14});

  final double t;
  final double size;

  static const _colors = [
    Color(0xFFFF2E8A),
    Color(0xFF8A1CFF),
    Color(0xFF3D5BFF),
    Color(0xFF00F0D0),
    Color(0xFFFF2E8A),
  ];

  @override
  Widget build(BuildContext context) {
    final breathe = .88 + .12 * math.sin(t * 2 * math.pi);
    return SizedBox.square(
      dimension: size,
      child: Transform.scale(
        scale: breathe,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: _colors,
              transform: GradientRotation(t * 2 * math.pi),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC21CFF)
                    .withValues(alpha: FluxColors.isDark(context) ? .6 : .3),
                blurRadius: size * .9,
              ),
            ],
          ),
          child: DecoratedBox(
            // A soft highlight so the orb reads as a sphere, not a disc.
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-.35, -.4),
                radius: .9,
                colors: [
                  Colors.white.withValues(alpha: .55),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [text] with a band of light sweeping across it, left to right, once per
/// cycle of [t] — the "still working" voice for a status line.
class FinnShimmerText extends StatelessWidget {
  const FinnShimmerText({
    super.key,
    required this.text,
    required this.t,
    this.style,
  });

  final String text;
  final double t;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = FluxColors.mutedOf(context);
    final light = FluxColors.inkOf(context);
    // The band travels from off the left edge to off the right edge.
    final x = -1.0 + 3.0 * t;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [base, light, base],
        stops: [
          (x - .35).clamp(0.0, 1.0),
          x.clamp(0.0, 1.0),
          (x + .35).clamp(0.0, 1.0),
        ],
      ).createShader(bounds),
      child: Text(text, style: style),
    );
  }
}
