import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:finn_ai/src/features/chat/widgets/voice_pill.dart';
import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';

/// The composer's bottom row, changing between chatting and a live voice
/// conversation as one continuous motion.
///
/// [progress] runs 0 (chat) to 1 (voice). Over it:
///  * the message field narrows into the colour pill — the same shape, so the
///    field's white gives way to the gradient while its text fades out first;
///  * the row closes in on its centre, the two gaps tightening;
///  * the attach button turns into the cross (its own rotation, driven by
///    [leading]);
///  * the dark voice button becomes the light microphone, one circle's colour
///    and glyph handing over to the other's with a small pulse between;
///  * there is no colour pill: the field dissolves into the screen's own
///    light (VoiceGlow), and the caption fades up where it was, last.
class VoiceMorphBar extends StatelessWidget {
  const VoiceMorphBar({
    super.key,
    required this.progress,
    required this.voice,
    required this.leading,
    required this.chatTrailing,
    required this.voiceTrailing,
    required this.field,
    required this.fieldRadius,
    required this.onVoiceTap,
  });

  /// 0 = chat, 1 = voice. Already curved by the owner.
  final Animation<double> progress;
  final VoiceChatController voice;

  /// The attach / cross button for a given progress.
  final Widget Function(double progress) leading;

  /// The right-hand control in chat (mic, send or stop) and in voice (mic).
  final Widget chatTrailing;
  final Widget voiceTrailing;

  /// What goes inside the pill while it is the message field.
  final Widget field;
  final double fieldRadius;
  final VoidCallback? onVoiceTap;

  static const double _side = 50;
  static const double _chatGap = 20;
  static const double _voiceGap = 8;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : 2 * _side + 2 * _chatGap + 240;
          return AnimatedBuilder(
            animation: progress,
            builder: (context, _) => _build(context, width, progress.value),
          );
        },
      );

  Widget _build(BuildContext context, double width, double c) {
    final gap = lerpDouble(_chatGap, _voiceGap, c)!;
    final chatSlot = width - 2 * _side - 2 * _chatGap;
    final slot = lerpDouble(chatSlot, VoicePill.maxWidth, c)!;

    // Staggered phases of the one motion.
    double phase(double from, double to, [Curve curve = Curves.easeInOut]) =>
        Interval(from, to, curve: curve).transform(c.clamp(0.0, 1.0));
    final fieldText = 1 - phase(0, .32, Curves.easeOut);
    final chatGlyph = 1 - phase(.08, .55);
    final voiceGlyph = phase(.3, .8);
    final pulse = 1 - 0.14 * math.sin(math.pi * phase(.08, .9));
    final caption = phase(.55, 1, Curves.easeOut);
    final voiceSide = c > .5;

    final trailing = SizedBox.square(
      dimension: _side,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (c < 1)
            IgnorePointer(
              ignoring: voiceSide,
              child: ExcludeSemantics(
                excluding: voiceSide,
                child: Opacity(
                  opacity: chatGlyph,
                  child: Transform.scale(scale: pulse, child: chatTrailing),
                ),
              ),
            ),
          if (c > 0)
            IgnorePointer(
              ignoring: !voiceSide,
              child: ExcludeSemantics(
                excluding: !voiceSide,
                child: Opacity(
                  opacity: voiceGlyph,
                  child: Transform.scale(scale: pulse, child: voiceTrailing),
                ),
              ),
            ),
        ],
      ),
    );

    // No pill of its own: the screen's light (VoiceGlow) is the voice
    // visual. The field narrows and dissolves into it, and the line saying
    // what the conversation is doing takes its place between the buttons.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(dimension: _side, child: leading(c)),
        SizedBox(width: gap),
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            VoicePill(
              voice: voice,
              onTap: onVoiceTap,
              expand: 1 - c,
              slotWidth: slot,
              field: field,
              fieldOpacity: fieldText,
              fieldRadius: fieldRadius,
              ghost: true,
            ),
            if (c > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: OverflowBox(
                    maxWidth: slot + 2 * gap + 40,
                    child: Opacity(
                      opacity: caption,
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - caption)),
                        child: VoiceCaption(voice: voice),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: gap),
        trailing,
      ],
    );
  }
}
