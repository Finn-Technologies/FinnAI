import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/src/features/chat/widgets/voice_pill.dart';
import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_speech_backend.dart';

class _Tts extends _BaseTts {}

class _BaseTts implements TtsBackend {
  @override
  final ValueNotifier<double> level = ValueNotifier(0);
  VoidCallback? onStart;

  @override
  Future<void> initialize({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onCancel,
    void Function(dynamic message)? onError,
  }) async =>
      this.onStart = onStart;

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
  Future<void> speak(String text) async => onStart?.call();

  @override
  Future<void> stop() async {}
}

Future<void> pumpPill(
  WidgetTester tester,
  VoiceChatController voice, {
  VoidCallback? onTap,
  bool reducedMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: FluxTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(
          body: Center(child: VoicePill(voice: voice, onTap: onTap)),
        ),
      ),
    ),
  );
}

double pillWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(const ValueKey('voice-pill'))).width;

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  late FakeSpeechBackend speech;
  late _Tts tts;
  late VoiceChatController voice;

  setUp(() {
    speech = FakeSpeechBackend();
    tts = _Tts();
    voice = VoiceChatController(speech: speech, tts: tts);
    addTearDown(voice.dispose);
  });

  testWidgets('idle: a small, quiet pill', (tester) async {
    await pumpPill(tester, voice);
    await settle(tester);

    expect(pillWidth(tester), closeTo(86, 1));
  });

  testWidgets('listening: it swells with what the microphone hears',
      (tester) async {
    await voice.startListening();
    await pumpPill(tester, voice);
    speech.onSoundLevel?.call(0.0);
    await settle(tester);
    final quiet = pillWidth(tester);

    // Past the controller's own 60 ms throttle.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    speech.onSoundLevel?.call(1.0);
    await settle(tester);
    final loud = pillWidth(tester);

    expect(loud, greaterThan(quiet + 40));
    expect(loud, lessThanOrEqualTo(VoicePill.maxWidth));
    // Listening arms a 60 s watchdog; a test must not leave it pending.
    await voice.cancelListening();
  });

  testWidgets('listening: it settles back when the sound stops',
      (tester) async {
    await voice.startListening();
    await pumpPill(tester, voice);
    speech.onSoundLevel?.call(1.0);
    await settle(tester);
    final loud = pillWidth(tester);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    speech.onSoundLevel?.call(0.0);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(pillWidth(tester), lessThan(loud - 40));
    // Listening arms a 60 s watchdog; a test must not leave it pending.
    await voice.cancelListening();
  });

  testWidgets('it rises faster than it falls, so a word registers',
      (tester) async {
    await voice.startListening();
    await pumpPill(tester, voice);
    await settle(tester);
    final start = pillWidth(tester);

    speech.onSoundLevel?.call(1.0);
    await tester.pump(const Duration(milliseconds: 120));
    final risen = pillWidth(tester) - start;
    expect(risen, greaterThan(20), reason: 'most of the way up in 120 ms');
    // Listening arms a 60 s watchdog; a test must not leave it pending.
    await voice.cancelListening();
  });

  testWidgets('thinking: it breathes on its own', (tester) async {
    await voice.startListening();
    speech.emitResult('hello', finalResult: true);
    voice.beginThinking();
    await pumpPill(tester, voice);

    final widths = <double>[];
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      widths.add(pillWidth(tester));
    }

    final spread = widths.reduce((a, b) => a > b ? a : b) -
        widths.reduce((a, b) => a < b ? a : b);
    expect(spread, greaterThan(2), reason: 'the width moves while thinking');
    // Listening arms a 60 s watchdog; a test must not leave it pending.
    await voice.cancelListening();
  });

  testWidgets('speaking: it follows the voice, not the microphone',
      (tester) async {
    await voice.startListening();
    speech.emitResult('hello', finalResult: true);
    voice.beginThinking();
    voice.speakReplyChunk('Hi there. More');
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(voice.state, VoiceChatState.speaking);
    await pumpPill(tester, voice);
    await settle(tester);
    final quiet = pillWidth(tester);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    tts.level.value = 1.0;
    await settle(tester);

    expect(pillWidth(tester), greaterThan(quiet + 40));
    // Listening arms a 60 s watchdog; a test must not leave it pending.
    await voice.cancelListening();
  });

  testWidgets('reduced motion: it does not move with the sound',
      (tester) async {
    await voice.startListening();
    await pumpPill(tester, voice, reducedMotion: true);
    await settle(tester);
    final before = pillWidth(tester);

    speech.onSoundLevel?.call(1.0);
    await settle(tester);

    expect(pillWidth(tester), closeTo(before, 1));
    // Listening arms a 60 s watchdog; a test must not leave it pending.
    await voice.cancelListening();
  });

  testWidgets('a tap goes to the callback', (tester) async {
    var taps = 0;
    await pumpPill(tester, voice, onTap: () => taps++);

    await tester.tap(find.byType(VoicePill));

    expect(taps, 1);
  });

  testWidgets('its semantics say what the conversation is doing',
      (tester) async {
    await voice.startListening();
    await pumpPill(tester, voice);
    await tester.pump();

    expect(find.bySemanticsLabel('Listening…'), findsOneWidget);
    // Listening arms a 60 s watchdog; a test must not leave it pending.
    await voice.cancelListening();
  });

  testWidgets('the caption names the state and changes with it',
      (tester) async {
    await voice.startListening();
    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: VoiceCaption(voice: voice)),
      ),
    );
    expect(find.text('Listening…'), findsOneWidget);

    speech.emitResult('hello', finalResult: true);
    voice.beginThinking();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Finn is thinking…'), findsOneWidget);
    // Listening arms a 60 s watchdog; a test must not leave it pending.
    await voice.cancelListening();
  });
}
