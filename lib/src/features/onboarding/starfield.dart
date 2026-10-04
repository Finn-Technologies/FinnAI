import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The welcome screen's night sky, drawn rather than shipped as a photo.
///
/// Every platform gets the same sky at any window size: a near-black base with a
/// faint teal and blue cloud, and stars scattered by a fixed seed so the sky is
/// identical on every launch and every device. A fifth of the stars twinkle,
/// slowly; with animations off (the system setting, or a test) the sky holds
/// still.
class Starfield extends StatefulWidget {
  const Starfield({super.key, this.seed = 7});

  /// Different seeds give different, equally stable skies.
  final int seed;

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _twinkle.stop();
    } else if (!_twinkle.isAnimating) {
      _twinkle.repeat();
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: StarfieldPainter(seed: widget.seed, twinkle: _twinkle),
          size: Size.infinite,
        ),
      );
}

/// One star: where it is (as a fraction of the sky, so a resize moves it with
/// the window instead of reshuffling), how big and bright, and its twinkle.
class _Star {
  const _Star(this.x, this.y, this.radius, this.brightness, this.phase,
      this.twinkles, this.tint);

  final double x;
  final double y;
  final double radius;
  final double brightness;
  final double phase;
  final bool twinkles;
  final Color tint;
}

class StarfieldPainter extends CustomPainter {
  StarfieldPainter({required this.seed, required Animation<double> twinkle})
      : _twinkle = twinkle,
        super(repaint: twinkle) {
    final random = math.Random(seed);
    for (var i = 0; i < _count; i++) {
      // Most stars are faint specks; a few are large and bright.
      final big = random.nextDouble();
      final radius = big > .985
          ? 1.6 + random.nextDouble() * .7
          : big > .9
              ? .9 + random.nextDouble() * .5
              : .35 + random.nextDouble() * .45;
      final warm = random.nextDouble();
      _stars.add(_Star(
        random.nextDouble(),
        random.nextDouble(),
        radius,
        .35 + random.nextDouble() * .65,
        random.nextDouble() * math.pi * 2,
        random.nextDouble() < .2,
        warm > .85
            ? const Color(0xFFFFE9C9)
            : warm < .15
                ? const Color(0xFFCFE3FF)
                : Colors.white,
      ));
    }
  }

  final int seed;
  final Animation<double> _twinkle;
  final List<_Star> _stars = [];

  static const _count = 900;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // The base: black, lifting to a deep green-teal toward the bottom, where the
    // welcome screen's glow rises.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const [Color(0xFF000000), Color(0xFF020E0B), Color(0xFF04170F)],
          const [0, .55, 1],
        ),
    );
    // Two faint clouds, so the sky is not a flat gradient.
    _cloud(canvas, size, const Offset(.22, .3), .5, const Color(0x2214306B));
    _cloud(canvas, size, const Offset(.78, .62), .55, const Color(0x1A0B4A3C));
    _cloud(canvas, size, const Offset(.5, .1), .4, const Color(0x140F2A55));

    final paint = Paint()..isAntiAlias = true;
    // Scale by the area so a big window is not sparser than a phone.
    final density = (size.width * size.height / (400 * 850)).clamp(.5, 6.0);
    final shown = (_stars.length * math.min(1.0, density)).round();
    final t = _twinkle.value * math.pi * 2;
    for (var i = 0; i < shown; i++) {
      final star = _stars[i];
      var alpha = star.brightness;
      if (star.twinkles) alpha *= .55 + .45 * math.sin(t + star.phase);
      final center = Offset(star.x * size.width, star.y * size.height);
      paint.color = star.tint.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(center, star.radius, paint);
      if (star.radius > 1.5) {
        // The largest stars get a soft halo.
        canvas.drawCircle(
          center,
          star.radius * 4,
          Paint()
            ..shader = ui.Gradient.radial(
              center,
              star.radius * 4,
              [
                star.tint.withValues(alpha: .28 * alpha),
                star.tint.withValues(alpha: 0),
              ],
            ),
        );
      }
    }
  }

  void _cloud(Canvas canvas, Size size, Offset at, double radius, Color color) {
    final center = Offset(at.dx * size.width, at.dy * size.height);
    final r = radius * math.max(size.width, size.height);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          r,
          [color, color.withValues(alpha: 0)],
        ),
    );
  }

  @override
  bool shouldRepaint(StarfieldPainter old) => old.seed != seed;
}

/// The call-to-action glow at the bottom of the welcome screen: a gradient
/// card with the same radius on every corner.
class WelcomeGlowCard extends StatelessWidget {
  const WelcomeGlowCard({super.key, required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          painter: _GlowCardPainter(),
          size: Size.infinite,
        ),
      );
}

class _GlowCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Dusty rose at the lower left, through magenta, to violet at the top right.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.bottomLeft,
          rect.topRight,
          const [
            Color(0xFFC9A0BE),
            Color(0xFFCB6BC6),
            Color(0xFFB30DBF),
            Color(0xFF7E0AC6),
          ],
          const [0, .38, .72, 1],
        ),
    );
    // A lighter lilac bloom at the lower right, so the card is not a plain
    // diagonal.
    final bloom = Offset(size.width * .9, size.height * 1.05);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          bloom,
          size.width * .38,
          const [Color(0xCCE08AD8), Color(0x00E08AD8)],
        ),
    );
  }

  @override
  bool shouldRepaint(_GlowCardPainter old) => false;
}
