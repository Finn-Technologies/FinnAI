import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// The one thing on screen while you talk to Finn: a dark glass orb that
/// drops from the top as voice mode opens (the way iOS 27's Siri leaves the
/// Dynamic Island), filled with the voice light's colours swirling inside
/// it, following whoever is speaking and turning faster while Finn thinks.
///
/// Like the voice light, it computes no blur: the glass, the lights inside
/// and the halo are radial gradients with Gaussian stops. The ticker runs only while voice mode is open or
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

  // The voice light's run of colours (shaders/voice_glow.frag), at the edge
  // of sRGB: on the black canvas saturated light is what reads as vivid.
  static const _lights = [
    Color(0xFFFF297A),
    Color(0xFFDB33FF),
    Color(0xFF7829FF),
    Color(0xFF1F6BFF),
    Color(0xFF00E6DB),
  ];

  /// A soft disc of light: a radial gradient whose stops follow a Gaussian,
  /// which is what a blurred disc looks like, with no blur computed.
  static Paint _light(Offset c, double radius, Color color, double strength) =>
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: strength),
            color.withValues(alpha: strength * .6),
            color.withValues(alpha: strength * .2),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .35, .7, 1],
        ).createShader(Rect.fromCircle(center: c, radius: radius));

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final p = frame.presence;
    final level = frame.level;

    // The halo: the sphere's light spilling onto the black around it.
    canvas.drawCircle(
      c,
      r * 1.6,
      _light(c, r * 1.6, const Color(0xFF8A1CFF), (.22 + .4 * level) * p),
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
          colors: [Color(0xFF16161A), Color(0xFF000000)],
        ).createShader(sphere),
    );

    // The light inside: five soft discs of colour drifting round each other,
    // larger and brighter as the voice rises, turning faster while Finn
    // thinks. Plus-blended, so where they overlap they brighten toward
    // white, the way light adds up.
    canvas.save();
    canvas.clipPath(Path()..addOval(sphere.deflate(1)));
    final spin = frame.phase * (1 + 1.5 * frame.thinking);
    for (var i = 0; i < _lights.length; i++) {
      final a =
          spin * (i.isEven ? 1.0 : -.8) + i * 2 * math.pi / _lights.length;
      final orbit = r * (.46 + .1 * math.sin(frame.phase * 1.7 + i));
      final centre = c + Offset(math.cos(a) * orbit, math.sin(a) * orbit * .8);
      final radius = r * (.78 + .22 * level + .08 * math.sin(frame.phase + i));
      canvas.drawCircle(
        centre,
        radius,
        _light(centre, radius, _lights[i], (.62 + .18 * level) * p),
      );
    }
    // HDR-style: the app renders SDR (no extended range on Android), so
    // light "brighter than its colour" is a white-hot core that grows with
    // the voice.
    canvas.drawCircle(
      c,
      r * (.22 + .25 * level),
      _light(c, r * (.22 + .25 * level), Colors.white, (.05 + .3 * level) * p),
    );
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
            Colors.white.withValues(alpha: .18),
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
            Colors.white.withValues(alpha: dark ? .38 : .6),
            Colors.white.withValues(alpha: .05),
          ],
        ).createShader(sphere),
    );
  }

  @override
  bool shouldRepaint(covariant VoiceOrbPainter old) =>
      old.frame != frame || old.dark != dark;
}
