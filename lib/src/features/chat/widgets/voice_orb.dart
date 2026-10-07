import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// The one thing on screen while you talk to Finn: a dark glass orb that
/// drops from the top as voice mode opens (the way iOS 27's Siri leaves the
/// Dynamic Island) with strands of the brand's colours moving inside it,
/// following whoever is speaking, and turning slowly while Finn thinks.
///
/// Like the voice light, it computes no blur: the glass is radial gradients,
/// the glow around it a gradient ring, the strands three stroked paths
/// clipped to the sphere. The ticker runs only while voice mode is open or
/// the orb is leaving; under reduced motion it is drawn still, in place.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({
    super.key,
    required this.voice,
    required this.active,
    this.size = 132,
  });

  final VoiceChatController voice;
  final bool active;
  final double size;

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  VoiceOrbFrame _frame = const VoiceOrbFrame();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    if (widget.active) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero
        ? .016
        : ((now - _last).inMicroseconds / 1e6).clamp(0.0, .1);
    _last = now;
    final state = widget.voice.state;
    final target = switch (state) {
      VoiceChatState.listening ||
      VoiceChatState.speaking =>
        widget.voice.soundLevel,
      _ => 0.0,
    };
    double ease(double from, double to, double rate) =>
        from + (to - from) * (1 - math.exp(-rate * dt));
    final f = _frame;
    // A spring-like arrival: quick, with the overshoot left to the curve
    // applied when it is drawn.
    var presence =
        ease(f.presence, widget.active ? 1 : 0, widget.active ? 4.2 : 7);
    final level = ease(f.level, target, target > f.level ? 18 : 4);
    final thinking =
        ease(f.thinking, state == VoiceChatState.thinking ? 1 : 0, 3);
    final phase = f.phase + dt * (.35 + 1.1 * level + .6 * thinking);
    if (!widget.active && presence < .004) {
      presence = 0;
      _ticker.stop();
    }
    setState(() {
      _frame = VoiceOrbFrame(
        presence: presence,
        level: level,
        thinking: thinking,
        phase: phase,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final frame =
        reduced ? VoiceOrbFrame(presence: widget.active ? 1 : 0) : _frame;
    if (frame.presence == 0) return SizedBox.square(dimension: widget.size);
    // Drops from above the screen's top edge and settles with a little
    // overshoot; leaves straight back up.
    final arrive = Curves.easeOutBack.transform(frame.presence.clamp(0, 1));
    final drop = (1 - arrive) * -(widget.size * 1.6);
    final scale = .55 + .45 * arrive + .06 * frame.level;
    return IgnorePointer(
      child: Transform.translate(
        offset: Offset(0, drop),
        child: Transform.scale(
          scale: scale,
          child: RepaintBoundary(
            child: CustomPaint(
              key: const ValueKey('voice-orb'),
              size: Size.square(widget.size),
              painter: VoiceOrbPainter(
                frame: frame,
                dark: FluxColors.isDark(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What one frame of the orb depends on.
@immutable
class VoiceOrbFrame {
  const VoiceOrbFrame({
    this.presence = 0,
    this.level = 0,
    this.thinking = 0,
    this.phase = 0,
  });

  final double presence;
  final double level;
  final double thinking;
  final double phase;

  @override
  bool operator ==(Object other) =>
      other is VoiceOrbFrame &&
      other.presence == presence &&
      other.level == level &&
      other.thinking == thinking &&
      other.phase == phase;

  @override
  int get hashCode => Object.hash(presence, level, thinking, phase);
}

class VoiceOrbPainter extends CustomPainter {
  VoiceOrbPainter({required this.frame, required this.dark});

  final VoiceOrbFrame frame;
  final bool dark;

  static const _strands = [
    Color(0xFFCB6BC6),
    Color(0xFF5D75FF),
    Color(0xFF7DFFCD),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final glow = (.35 + .65 * frame.level) * frame.presence;

    // The glow: a ring of colour fading out from the sphere's edge, with a
    // Gaussian-like falloff in its stops (no blur filter).
    final halo = Rect.fromCircle(center: c, radius: r * 1.45);
    canvas.drawCircle(
      c,
      r * 1.45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF5D75FF).withValues(alpha: .0),
            const Color(0xFF7E0AC6).withValues(alpha: .30 * glow),
            const Color(0xFFCB6BC6).withValues(alpha: .14 * glow),
            const Color(0xFFCB6BC6).withValues(alpha: 0),
          ],
          stops: const [.62, .70, .82, 1],
        ).createShader(halo),
    );

    // The glass: near-black in both themes, as Siri's orb is.
    final sphere = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.2),
          radius: 1,
          colors: [Color(0xFF252528), Color(0xFF0B0B0C)],
        ).createShader(sphere),
    );

    // The strands, clipped to the sphere. Plus-blended so where they cross
    // they brighten, as light does.
    canvas.save();
    canvas.clipPath(Path()..addOval(sphere.deflate(1)));
    final amp = r * (.08 + .42 * frame.level + .12 * frame.thinking);
    final turn = frame.thinking * frame.phase * .9;
    for (var i = 0; i < _strands.length; i++) {
      final path = Path();
      final k = 1.4 + .55 * i;
      final p = frame.phase * (2.1 + .7 * i) + i * 2.1;
      for (var s = 0; s <= 48; s++) {
        final t = s / 48;
        final x = -r + 2 * r * t;
        // An envelope so the strand meets the rim at the middle line.
        final env = math.sin(math.pi * t);
        final y = math.sin(k * math.pi * 2 * t + p) * amp * env;
        final px = c.dx + x * math.cos(turn) - y * math.sin(turn);
        final py = c.dy + x * math.sin(turn) + y * math.cos(turn);
        s == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * .07
          ..blendMode = BlendMode.plus
          ..color = _strands[i].withValues(alpha: .85 * frame.presence),
      );
    }
    canvas.restore();

    // The glass's own light: a soft highlight up and to the left, and a thin
    // rim that is brighter at the top.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.45, -.55),
          radius: .75,
          colors: [
            Colors.white.withValues(alpha: .16),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(sphere),
    );
    canvas.drawCircle(
      c,
      r - .75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: dark ? .32 : .55),
            Colors.white.withValues(alpha: .04),
          ],
        ).createShader(sphere),
    );
  }

  @override
  bool shouldRepaint(covariant VoiceOrbPainter old) =>
      old.frame != frame || old.dark != dark;
}
