import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// The design's colour pill for a live voice conversation, made to move.
///
/// It follows what the conversation is doing: while listening it swells with
/// the loudness of the microphone, while Finn speaks it follows the voice, and
/// while Finn thinks it breathes. The level is smoothed here, frame by frame,
/// quick to rise and slow to fall, so a 60 ms stream of readings reads as one
/// continuous movement instead of a flicker.
///
/// It is also the chat field. [expand] is how far it is still the message
/// field (1) rather than the pill (0): the same shape, so entering and leaving
/// voice mode is one object changing, not one thing replaced by another. At 1
/// it draws exactly what the plain field draws and stops its ticker.
class VoicePill extends StatefulWidget {
  const VoicePill({
    super.key,
    required this.voice,
    this.onTap,
    this.expand = 0,
    this.slotWidth = maxWidth,
    this.field,
    this.fieldOpacity = 0,
    this.fieldRadius = FluxRadius.pill,
  });

  final VoiceChatController voice;
  final VoidCallback? onTap;

  /// 1 while it is the message field, 0 when it is the pill.
  final double expand;

  /// The room it has: the pill's own size when settled, the field's width
  /// while expanded.
  final double slotWidth;

  /// The message field's contents, drawn inside while [expand] is high.
  final Widget? field;
  final double fieldOpacity;

  /// The corner radius of the field when it is just the field (it is squarer
  /// with an attachment on it).
  final double fieldRadius;

  /// The most the pill ever grows to, so a parent can reserve the room.
  static const double maxWidth = 164;
  static const double height = 56;

  @override
  State<VoicePill> createState() => _VoicePillState();
}

class _VoicePillState extends State<VoicePill>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _level = 0;
  double _phase = 0;

  /// 0..1 how "awake" the pill is: eased towards 1 while the conversation is
  /// doing something, and towards 0 when it is idle.
  double _awake = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _ticker.muted = widget.expand >= 1;
  }

  @override
  void didUpdateWidget(covariant VoicePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A pill that is just the message field has nothing to animate; leaving
    // the ticker on would redraw the chat screen sixty times a second.
    _ticker.muted = widget.expand >= 1;
    if (_ticker.muted) _last = Duration.zero;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double get _target {
    final voice = widget.voice;
    return switch (voice.state) {
      VoiceChatState.listening || VoiceChatState.speaking => voice.soundLevel,
      _ => 0,
    };
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero
        ? 0.016
        : ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = now;
    final target = _target;
    // Fast attack, slow release: the pill jumps to a word and settles after it.
    final rate = target > _level ? 22.0 : 6.0;
    _level += (target - _level) * (1 - math.exp(-rate * dt));
    final state = widget.voice.state;
    // A live conversation between turns is waiting, not asleep.
    final awakeTarget =
        state == VoiceChatState.idle && !widget.voice.live ? 0.0 : 1.0;
    _awake += (awakeTarget - _awake) * (1 - math.exp(-5.0 * dt));
    _phase += dt * (state == VoiceChatState.thinking ? 1.6 : 0.7);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final voice = widget.voice;
    final state = voice.state;
    final colors = FluxColors.voiceGradientOf(context).colors;
    final expand = widget.expand.clamp(0.0, 1.0);
    // Settled as the message field it must be free to grow with what is typed;
    // only while it changes shape is its size ours to set.
    final settled = expand >= 1;

    final thinking = state == VoiceChatState.thinking;
    // Thinking has no sound to follow, so it breathes on its own.
    final breath = thinking ? (math.sin(_phase * 2.2) + 1) / 2 : 0.0;
    final level = reduced ? 0.0 : _level.clamp(0.0, 1.0);
    final swell = thinking ? breath * 0.18 : level;
    final pillWidth = 86 + 22 * _awake + 56 * swell;
    final pillHeight = 50 + 6 * swell;
    final width = lerpDouble(pillWidth, widget.slotWidth, expand)!;
    final height = lerpDouble(pillHeight, 50, expand)!;
    final angle = _phase * 1.4;
    final glow = reduced ? 0.0 : (0.12 + 0.30 * swell) * _awake;
    final hot = colors.last;
    final isDark = FluxColors.isDark(context);

    final c = 1 - expand;
    final pillFill =
        const Interval(.15, .65, curve: Curves.easeOut).transform(c);
    // The white stays solid under the arriving colour and only then goes, so
    // the shape never thins out half way: two see-through layers would.
    final fieldFill =
        1 - const Interval(.5, 1, curve: Curves.easeIn).transform(c);

    return Semantics(
      button: expand < .5,
      label: expand < .5
          ? voiceStatusLabel(L10n.of(context), state, live: voice.live)
          : null,
      child: GestureDetector(
        onTap: expand < .5 ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: widget.slotWidth,
          height: settled ? null : lerpDouble(VoicePill.height, 50, expand),
          child: Center(
            child: RepaintBoundary(
              child: Opacity(
                opacity: lerpDouble(0.62 + 0.38 * _awake, 1, expand)!,
                child: Container(
                  key: const ValueKey('voice-pill'),
                  width: width,
                  height: settled ? null : height,
                  constraints: settled
                      ? const BoxConstraints(minHeight: 50, maxHeight: 220)
                      : null,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      settled ? widget.fieldRadius : height / 2,
                    ),
                    // Only the white lives here. A gradient on the same decoration
                    // would be drawn through this colour's alpha, and vanish as
                    // the white fades: the colour is its own layer, below.
                    color: FluxColors.controlOf(context)
                        .withValues(alpha: fieldFill),
                    boxShadow: [
                      if (fieldFill > 0)
                        BoxShadow(
                          color: FluxColors.elevationOf(context).withValues(
                            alpha: (isDark ? 0.14 : 0.08) * fieldFill,
                          ),
                          blurRadius: isDark ? 20 : 16,
                          offset: const Offset(0, 4),
                        ),
                      if (glow > 0)
                        BoxShadow(
                          color: hot.withValues(alpha: glow * pillFill),
                          blurRadius: 12 + 26 * swell,
                          spreadRadius: 1 + 5 * swell,
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      settled ? widget.fieldRadius : height / 2,
                    ),
                    child: Stack(
                      children: [
                        if (pillFill > 0)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  // The colours slide across the pill as it
                                  // moves.
                                  begin: Alignment(
                                    math.cos(angle),
                                    math.sin(angle),
                                  ),
                                  end: Alignment(
                                    -math.cos(angle),
                                    -math.sin(angle),
                                  ),
                                  colors: [
                                    for (final color in colors)
                                      color.withValues(
                                        alpha: color.a * pillFill,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        // A soft highlight drifts through the colour, brighter
                        // with level, so it looks like a liquid and not a flat
                        // shape.
                        if (pillFill > 0)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(
                                    math.sin(_phase * 1.3) * 0.7,
                                    -0.2,
                                  ),
                                  radius: 0.9,
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: (0.10 + 0.22 * swell * _awake) *
                                          pillFill,
                                    ),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (widget.field != null && widget.fieldOpacity > 0)
                          IgnorePointer(
                            ignoring: expand < .9,
                            child: Opacity(
                              opacity: widget.fieldOpacity.clamp(0.0, 1.0),
                              // Its text is gone before the pill is narrow
                              // enough for it to matter that it reflows.
                              child: widget.field,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the live conversation is doing, in words.
String voiceStatusLabel(
  AppLocalizations l10n,
  VoiceChatState state, {
  bool live = false,
}) =>
    switch (state) {
      VoiceChatState.listening => l10n.voiceListening,
      VoiceChatState.thinking => l10n.voiceThinking,
      VoiceChatState.speaking => l10n.voiceSpeakingLive,
      // Between turns of a live conversation the microphone is about to open:
      // "tap the mic" would be wrong, and a flash of it was.
      VoiceChatState.idle => live ? l10n.voiceListening : l10n.voiceTapToSpeak,
    };

/// One line saying what the live conversation is doing, fading between states.
class VoiceCaption extends StatelessWidget {
  const VoiceCaption({super.key, required this.voice});

  final VoiceChatController voice;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: voice,
        builder: (context, _) {
          final label = voiceStatusLabel(
            L10n.of(context),
            voice.state,
            live: voice.live,
          );
          return AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: Text(
              label,
              key: ValueKey(label),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'InstrumentSans',
                fontSize: 14,
                height: 1.2,
                color: FluxColors.mutedOf(context),
              ),
            ),
          );
        },
      );
}
