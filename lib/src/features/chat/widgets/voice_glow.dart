import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// The light of a live voice conversation, at the scale of the whole screen.
///
/// Two parts, both following the conversation — rising with the microphone
/// while you speak and with Finn's voice while it answers, and drifting on
/// their own while Finn thinks:
///
///  * a rim of colour running round the screen's edge, the way Siri lights
///    the edge of the display. It draws itself in from the bottom, up both
///    sides, when voice mode opens, and back down when it closes;
///  * deep, heavily blurred orbs of colour rising from the bottom edge.
///
/// **No blur is ever computed.** A real blur (`ImageFilter.blur`,
/// `MaskFilter.blur`, a `BackdropFilter`) costs an offscreen layer and a
/// multi-tap filter pass over every pixel, every frame. Here the softness is
/// built into the paint itself: each orb is a radial gradient whose stops
/// follow a Gaussian falloff (which is exactly what a blurred disc looks
/// like), and the rim's glow is a few stacked strokes of falling opacity. A
/// frame is a handful of gradient fills: no layers, no filters, no offscreen
/// passes, and the rim's paths are measured once per screen size.
///
/// The level is smoothed frame by frame, quick to rise and slow to fall, so a
/// reading every 60 ms reads as one movement. The ticker only runs while
/// voice mode is open or fading out.
class VoiceGlow extends StatefulWidget {
  const VoiceGlow({super.key, required this.voice, required this.active});

  final VoiceChatController voice;

  /// True while voice mode is open; the light comes and goes with it.
  final bool active;

  @override
  State<VoiceGlow> createState() => _VoiceGlowState();
}

class _VoiceGlowState extends State<VoiceGlow>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  var _frame = const VoiceGlowFrame();
  final _rim = VoiceGlowRim();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    if (widget.active) _ticker.start();
    VoiceGlowShader.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant VoiceGlow oldWidget) {
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
    final f = _frame;
    final state = widget.voice.state;
    final target = switch (state) {
      VoiceChatState.listening ||
      VoiceChatState.speaking =>
        widget.voice.soundLevel,
      _ => 0.0,
    };
    double ease(double from, double to, double rate) =>
        from + (to - from) * (1 - math.exp(-rate * dt));
    final level = ease(f.level, target, target > f.level ? 16 : 3.5);
    // Opening is a gesture worth watching; closing gets out of the way.
    var presence =
        ease(f.presence, widget.active ? 1 : 0, widget.active ? 2.6 : 5);
    final thinking =
        ease(f.thinking, state == VoiceChatState.thinking ? 1 : 0, 3);
    final speaking =
        ease(f.speaking, state == VoiceChatState.speaking ? 1 : 0, 3);
    final phase = f.phase + dt * (.18 + .55 * thinking + .25 * level);
    if (!widget.active && presence < .004) {
      presence = 0;
      _ticker.stop();
    }
    setState(() {
      _frame = VoiceGlowFrame(
        level: level,
        phase: phase,
        presence: presence,
        thinking: thinking,
        speaking: speaking,
      );
    });
  }

  /// A measuring switch (`--dart-define=FINN_GLOW=off|gradient`): draw no
  /// light, or force the gradient painter, to compare frame times against
  /// the shader. Unset in every real build.
  static const _mode = String.fromEnvironment('FINN_GLOW');

  @override
  Widget build(BuildContext context) {
    if (_frame.presence == 0 || _mode == 'off') return const SizedBox.shrink();
    final reduced = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: VoiceGlowPainter(
            frame: reduced ? _frame.still : _frame,
            rim: _rim,
            dark: FluxColors.isDark(context),
            program: _mode == 'gradient' ? null : VoiceGlowShader.program,
          ),
        ),
      ),
    );
  }
}

/// Everything one frame of the glow depends on.
@immutable
class VoiceGlowFrame {
  const VoiceGlowFrame({
    this.level = 0,
    this.phase = 0,
    this.presence = 0,
    this.thinking = 0,
    this.speaking = 0,
  });

  /// 0..1 loudness of whoever is speaking, smoothed.
  final double level;

  /// Free-running time, in turns.
  final double phase;

  /// 0..1 how far voice mode is open.
  final double presence;
  final double thinking;
  final double speaking;

  /// The same frame with nothing moving, for reduced motion.
  VoiceGlowFrame get still => VoiceGlowFrame(presence: presence);

  @override
  bool operator ==(Object other) =>
      other is VoiceGlowFrame &&
      other.level == level &&
      other.phase == phase &&
      other.presence == presence &&
      other.thinking == thinking &&
      other.speaking == speaking;

  @override
  int get hashCode => Object.hash(level, phase, presence, thinking, speaking);
}

/// The two halves of the screen's rim, from the bottom centre up each side
/// to the top centre, measured once per size so a frame only extracts the
/// length it shows.
class VoiceGlowRim {
  Size? _size;
  List<ui.PathMetric> halves = const [];

  /// Close to a phone display's own corner radius.
  static const double radius = 44;

  void ensure(Size size) {
    if (_size == size) return;
    _size = size;
    final w = size.width, h = size.height;
    final r = math.min(radius, math.min(w, h) / 2);
    final left = Path()
      ..moveTo(w / 2, h)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(w / 2, 0);
    final right = Path()
      ..moveTo(w / 2, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r),
          radius: Radius.circular(r), clockwise: false)
      ..lineTo(w, r)
      ..arcToPoint(Offset(w - r, 0),
          radius: Radius.circular(r), clockwise: false)
      ..lineTo(w / 2, 0);
    halves = [
      left.computeMetrics().first,
      right.computeMetrics().first,
    ];
  }
}

/// Paints one [VoiceGlowFrame]. Public so a golden can draw a fixed frame.
/// The compiled `shaders/voice_glow.frag`, loaded once for the whole app.
///
/// The shader draws the rim and the orbs in one full-screen pass with exact
/// Gaussian falloff. Where it cannot be loaded (an engine without runtime
/// effects, a test host) [VoiceGlowPainter] draws the same light from
/// gradients instead, so the look degrades, never the feature.
abstract final class VoiceGlowShader {
  static ui.FragmentProgram? program;
  static Future<void>? _loading;

  /// One shader for every frame: its uniforms are rewritten in place, the
  /// way the engine expects a per-frame effect to be driven.
  static ui.FragmentShader? _shader;
  static ui.FragmentShader shaderOf(ui.FragmentProgram program) =>
      _shader ??= program.fragmentShader();

  static Future<void> load() => _loading ??= () async {
        try {
          program = await ui.FragmentProgram.fromAsset(
            'shaders/voice_glow.frag',
          );
        } catch (error) {
          debugPrint('FINN_VOICE_GLOW shader unavailable: $error');
          program = null;
        }
      }();
}

class VoiceGlowPainter extends CustomPainter {
  VoiceGlowPainter({
    required this.frame,
    required this.dark,
    VoiceGlowRim? rim,
    this.program,
  }) : rim = rim ?? VoiceGlowRim();

  final VoiceGlowFrame frame;
  final VoiceGlowRim rim;
  final bool dark;

  /// The shader that draws the whole light in one pass, when available.
  final ui.FragmentProgram? program;

  // Siri's warm-to-cool run, in the brand's own hues.
  static const _palette = [
    Color(0xFFFF297A),
    Color(0xFFDB33FF),
    Color(0xFF7829FF),
    Color(0xFF1F6BFF),
    Color(0xFF00E6DB),
    Color(0xFFFF751A),
  ];

  /// A Gaussian falloff sampled into gradient stops: the profile of a disc
  /// put through a heavy blur, without running one.
  static final List<double> _stops = [for (var i = 0; i <= 7; i++) i / 7];
  static final List<double> _falloff = [
    for (final t in _stops)
      (math.exp(-4.2 * t * t) - math.exp(-4.2)) / (1 - math.exp(-4.2)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Curves.easeOutCubic.transform(frame.presence.clamp(0.0, 1.0));
    if (p <= 0) return;
    final program = this.program;
    if (program != null) {
      final f = frame;
      final shader = VoiceGlowShader.shaderOf(program)
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, f.phase)
        ..setFloat(3, p)
        ..setFloat(4, f.level.clamp(0.0, 1.0))
        ..setFloat(5, f.thinking)
        ..setFloat(6, dark ? 1 : 0)
        ..setFloat(7, VoiceGlowRim.radius);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = shader
          ..blendMode = dark ? BlendMode.plus : BlendMode.srcOver,
      );
      return;
    }
    _orbs(canvas, size, p);
    _edge(canvas, size, p);
  }

  void _orbs(Canvas canvas, Size size, double p) {
    final f = frame;
    final w = size.width, h = size.height;
    final level = f.level.clamp(0.0, 1.0);
    // How far up the screen the light reaches: low at rest, rising with the
    // voice; thinking keeps it low and lets it sway.
    final reach = h * (.16 + .30 * level + .04 * f.speaking) * p;
    final strength = (dark ? .62 : .5) * p;
    final blend = dark ? BlendMode.plus : BlendMode.srcOver;
    const count = 5;
    final shift = f.phase * .6;
    for (var i = 0; i < count; i++) {
      final o = i / count;
      // Colours hand over slowly, so the light never pops between hues.
      final hue = Color.lerp(
        _palette[(i + shift.floor()) % _palette.length],
        _palette[(i + 1 + shift.floor()) % _palette.length],
        shift % 1,
      )!;
      final drift = math.sin((f.phase + o) * 2 * math.pi) * .16;
      final sweep = math.sin(f.phase * 2.2 * math.pi + o * 6) * .3 * f.thinking;
      final x = w * (.1 + .8 * o + drift + sweep);
      final bob = math.cos((f.phase * 1.3 + o) * 2 * math.pi);
      final radius = w * (.5 + .14 * level + .05 * bob);
      final cy = h + radius * .35 - reach * (.55 + .12 * bob);
      final stretch = math.max(1.0, (radius + reach) / (radius * 1.6));
      final alpha = strength * (.75 + .25 * math.sin(f.phase * 3 + i));
      canvas
        ..save()
        ..translate(x, cy)
        ..scale(1, stretch)
        ..drawCircle(
          Offset.zero,
          radius,
          Paint()
            ..blendMode = blend
            ..shader = ui.Gradient.radial(
              Offset.zero,
              radius,
              [for (final a in _falloff) hue.withValues(alpha: alpha * a)],
              _stops,
            ),
        )
        ..restore();
    }
  }

  void _edge(Canvas canvas, Size size, double p) {
    final f = frame;
    rim.ensure(size);
    // Draws itself in from the bottom, up both sides, meeting at the top.
    final reveal = Curves.easeInOutCubic.transform(p);
    final level = f.level.clamp(0.0, 1.0);
    final intensity = p * (.55 + .45 * level + .15 * f.thinking);
    final turn = f.phase * 2 * math.pi * .35;
    final shader = ui.Gradient.sweep(
      size.center(Offset.zero),
      [..._palette, _palette.first],
      [for (var i = 0; i <= _palette.length; i++) i / _palette.length],
      TileMode.clamp,
      0,
      2 * math.pi,
      (Matrix4.identity()
            ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
            ..rotateZ(turn)
            ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1))
          .storage,
    );
    // The glow: wide faint strokes under a narrow bright one, centred on the
    // screen edge so only their inner halves show — light spilling inward.
    // Many thin steps of a Gaussian, so no step is visible as a band.
    final spread = 34 + 30 * level;
    final layers = <(double, double)>[
      for (var k = 9; k >= 0; k--)
        (3 + spread * k / 9 * 2, math.exp(-3.0 * k / 9) * (k == 0 ? 1 : .18)),
    ];
    final blend = dark ? BlendMode.plus : BlendMode.srcOver;
    final strength = dark ? 1.0 : .85;
    for (final metric in rim.halves) {
      final shown = metric.extractPath(0, metric.length * reveal);
      for (final (width, alpha) in layers) {
        canvas.drawPath(
          shown,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..shader = shader
            ..color = Color.fromRGBO(
              255,
              255,
              255,
              (alpha * intensity * strength).clamp(0.0, 1.0),
            )
            ..blendMode = blend,
        );
      }
    }
  }

  @override
  bool shouldRepaint(VoiceGlowPainter old) =>
      old.frame != frame || old.dark != dark || old.program != program;
}
