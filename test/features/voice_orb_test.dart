import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/chat/widgets/voice_orb.dart';
import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

import 'support/fake_speech_backend.dart';

class _Tts implements TtsBackend {
  @override
  final ValueNotifier<double> level = ValueNotifier(0);

  @override
  Future<void> initialize({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onCancel,
    void Function(dynamic message)? onError,
  }) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setQueueAdd() async {}

  @override
  Future<void> setLanguage(String? language) async {}

  @override
  Future<void> prepare() async {}

  @override
  Future<void> release() async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  late VoiceChatController voice;

  setUp(() {
    voice = VoiceChatController(speech: FakeSpeechBackend(), tts: _Tts());
  });
  tearDown(() => voice.dispose());

  Widget host(bool active, {bool reduced = false}) => MaterialApp(
        theme: FluxTheme.dark,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: Center(child: VoiceOrb(voice: voice, active: active)),
          ),
        ),
      );

  testWidgets('closed, it draws nothing and asks for no frames',
      (tester) async {
    await tester.pumpWidget(host(false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('voice-orb')), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('opening drops it in; closing takes it away and stops',
      (tester) async {
    await tester.pumpWidget(host(true));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const ValueKey('voice-orb')), findsOneWidget);

    await tester.pumpWidget(host(false));
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const ValueKey('voice-orb')), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion draws it still, in place', (tester) async {
    await tester.pumpWidget(host(true, reduced: true));
    await tester.pump();
    expect(find.byKey(const ValueKey('voice-orb')), findsOneWidget);
    final moved = tester.widgetList<Transform>(find.ancestor(
      of: find.byKey(const ValueKey('voice-orb')),
      matching: find.byType(Transform),
    ));
    // Translated by zero and scaled to 1: no drop, no swell.
    for (final t in moved) {
      expect(t.transform.getTranslation().y, 0);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('golden: quiet and loud, dark', (tester) async {
    Future<void> shoot(VoiceOrbFrame frame, String name) async {
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('shot'),
        child: ColoredBox(
          color: FluxColors.tileDark,
          child: SizedBox.square(
            dimension: 240,
            child: Center(
              child: CustomPaint(
                size: const Size.square(132),
                painter: VoiceOrbPainter(frame: frame, dark: true),
              ),
            ),
          ),
        ),
      ));
      await expectLater(
        find.byKey(const ValueKey('shot')),
        matchesGoldenFile('goldens/voice_orb_$name.png'),
      );
    }

    await shoot(
        const VoiceOrbFrame(presence: 1, level: .05, phase: .4), 'quiet');
    await shoot(
        const VoiceOrbFrame(presence: 1, level: .8, phase: 1.3), 'loud');
  });
}
