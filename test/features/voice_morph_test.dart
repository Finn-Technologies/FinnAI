import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/src/features/chat/home_shell.dart';
import 'package:finn_ai/src/features/chat/widgets/voice_pill.dart';
import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/platform/platform_target.dart';

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

class _Harness {
  _Harness({bool live = false, bool reduced = false, String text = ''})
      : isLive = ValueNotifier(live),
        reducedMotion = reduced,
        controller = TextEditingController(text: text),
        focusNode = FocusNode(),
        voice = VoiceChatController(speech: FakeSpeechBackend(), tts: _Tts());

  final ValueNotifier<bool> isLive;
  final bool reducedMotion;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoiceChatController voice;
  int endTaps = 0;
  int micTaps = 0;
  int voiceTaps = 0;

  Future<void> pump(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(voice.dispose);
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
          data: MediaQueryData(
            size: Size(width, 844),
            disableAnimations: reducedMotion,
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder<bool>(
                valueListenable: isLive,
                builder: (context, live, _) => ChatComposer(
                  controller: controller,
                  focusNode: focusNode,
                  blocked: false,
                  onSend: () {},
                  onStop: () {},
                  voiceEnabled: true,
                  onMic: () => micTaps++,
                  voiceListening: live,
                  voice: voice,
                  onVoiceToggle: () => endTaps++,
                  onVoiceTap: () => voiceTaps++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }
}

Finder get _pill => find.byKey(const ValueKey('voice-pill'));
Finder get _field => find.byType(TextField);
Finder get _chatMic => find.byKey(const ValueKey('mic-button-surface'));
Finder get _voiceMic => find.byKey(const ValueKey('voice-toggle-surface'));

double _pillWidth(WidgetTester tester) => tester.getSize(_pill).width;

/// The pill's colour. It is its own layer: a gradient on the same decoration
/// as the white would be drawn through the white's alpha, and so would vanish
/// as the white faded (which it did, on a phone, before this was checked).
Finder _gradientLayers(WidgetTester tester) => find.descendant(
      of: _pill,
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient is LinearGradient,
      ),
    );

Future<void> _run(WidgetTester tester, int ms) async {
  for (var elapsed = 0; elapsed < ms; elapsed += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('the keyboard rising keeps the same field, and its focus',
      (tester) async {
    // The row hands over from the voice bar to the fused panel as the
    // keyboard rises. The field used to be rebuilt in the new tree, which
    // closed its input connection and dropped the keyboard at once.
    // A phone: desktops never fuse.
    debugSetFinnPlatformOverride(FinnPlatform.android);
    addTearDown(() => debugSetFinnPlatformOverride(null));
    final h = _Harness();
    await h.pump(tester);
    await tester.tap(_field);
    await tester.pump();
    final before = tester.state<EditableTextState>(find.byType(EditableText));
    expect(h.focusNode.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await _run(tester, 600);

    final after = tester.state<EditableTextState>(find.byType(EditableText));
    expect(identical(before, after), isTrue,
        reason: 'the field must not be remounted by the hand-over');
    expect(h.focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  group('settled in chat', () {
    testWidgets('the field fills the row, as the plain field does',
        (tester) async {
      final h = _Harness();
      await h.pump(tester);

      expect(_field, findsOneWidget);
      expect(_chatMic, findsOneWidget);
      expect(_voiceMic, findsNothing);
      // 390 wide minus two 50 buttons and two 20 gaps.
      expect(_pillWidth(tester), closeTo(390 - 100 - 40, 1));
      // 50, like the plain pill and the circles beside it: the 48dp band
      // plus its 1px hairline on each side (was 52 before the shared
      // FinnComposerFrame dropped the 1px rest padding).
      expect(tester.getSize(_pill).height, closeTo(50, 1));
    });

    testWidgets('it does not redraw sixty times a second while idle',
        (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await tester.pumpAndSettle();

      expect(tester.binding.hasScheduledFrame, isFalse,
          reason: 'a ticker left running would repaint the chat screen '
              'continuously for nothing');
    });

    testWidgets('a long message still grows the field', (tester) async {
      final h = _Harness(text: 'one\ntwo\nthree\nfour');
      await h.pump(tester);

      expect(tester.getSize(_pill).height, greaterThan(80),
          reason: 'the pill follows what is typed; it is not fixed at 50');
    });

    testWidgets('it has the pill corners', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      final decoration =
          tester.widget<Container>(_pill).decoration! as BoxDecoration;
      expect((decoration.borderRadius! as BorderRadius).topLeft.x, 999);
    });
  });

  group('entering voice mode', () {
    testWidgets('the field narrows into the pill and its text fades first',
        (tester) async {
      final h = _Harness();
      await h.pump(tester);
      final full = _pillWidth(tester);

      h.isLive.value = true;
      await tester.pump();
      await _run(tester, 120);
      final earlyWidth = _pillWidth(tester);
      final earlyOpacity = _fieldOpacity(tester);

      await _run(tester, 200);
      final midWidth = _pillWidth(tester);

      await _run(tester, 600);
      final end = _pillWidth(tester);

      expect(earlyWidth, lessThan(full));
      expect(midWidth, lessThan(earlyWidth));
      expect(end, lessThan(midWidth));
      expect(end, lessThanOrEqualTo(VoicePill.maxWidth));
      expect(earlyOpacity, lessThan(1),
          reason: 'the text is already leaving while the pill is still wide');
    });

    testWidgets('the width only ever shrinks on the way in', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      h.isLive.value = true;
      await tester.pump();

      var previous = _pillWidth(tester);
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final width = _pillWidth(tester);
        expect(width, lessThanOrEqualTo(previous + 0.5),
            reason: 'a smooth change does not stutter back at frame $i');
        previous = width;
      }
    });

    testWidgets('the field is gone and the pill is a pill when it lands',
        (tester) async {
      final h = _Harness();
      await h.pump(tester);
      h.isLive.value = true;
      await tester.pump();
      await _run(tester, 900);

      expect(_field, findsNothing);
      expect(_pillWidth(tester), inInclusiveRange(86, 150));
      expect(tester.getSize(_pill).height, inInclusiveRange(50, 57));
      expect(find.text('Listening…'), findsNothing,
          reason: 'the controller is idle in this harness');
      expect(_gradientLayers(tester), findsNothing,
          reason: 'no colour pill: the screen\'s own light is the visual');
    });

    testWidgets('the right-hand button hands over to the microphone',
        (tester) async {
      final h = _Harness();
      await h.pump(tester);
      expect(_chatMic, findsOneWidget);

      h.isLive.value = true;
      await tester.pump();
      await _run(tester, 160);
      // Mid-way both are there, one fading as the other arrives.
      expect(_chatMic, findsOneWidget);
      expect(_voiceMic, findsOneWidget);

      await _run(tester, 800);
      expect(_chatMic, findsNothing);
      expect(_voiceMic, findsOneWidget);
    });

    testWidgets('only the control on the right side of the change is tappable',
        (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(_chatMic);
      expect(h.micTaps, 1);

      h.isLive.value = true;
      await tester.pump();
      await _run(tester, 900);
      await tester.tap(_voiceMic);
      await tester.tap(_pill);

      expect(h.voiceTaps, 2);
      expect(h.micTaps, 1, reason: 'the old button is gone, not just hidden');
    });

    testWidgets('the attach button turns into the cross', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      double turn() {
        final rotate = tester.widget<Transform>(find
            .descendant(
              of: find.byKey(const ValueKey('add-attachment-button')),
              matching: find.byType(Transform),
            )
            .first);
        return rotate.transform.getRotation().entry(0, 1);
      }

      final before = turn();
      h.isLive.value = true;
      await tester.pump();
      await _run(tester, 900);

      expect(before, closeTo(0, 1e-6));
      // A quarter-eighth turn: 45 degrees, the plus becoming a cross.
      expect(turn().abs(), closeTo(0.7071, 0.02));
    });

    testWidgets('the whole row closes in on the centre', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      final left = tester.getTopLeft(
        find.byKey(const ValueKey('add-attachment-button')),
      );

      h.isLive.value = true;
      await tester.pump();
      await _run(tester, 900);

      final after = tester.getTopLeft(
        find.byKey(const ValueKey('add-attachment-button')),
      );
      expect(after.dx, greaterThan(left.dx + 40));
    });

    testWidgets('the caption opens last, where the field was', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await h.voice.startListening();
      await tester.pump();
      h.isLive.value = true;
      await tester.pump();
      await _run(tester, 80);
      final early = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Listening…'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      await _run(tester, 800);
      final late = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Listening…'),
              matching: find.byType(Opacity),
            )
            .first,
      );

      expect(early.opacity, lessThan(.2), reason: 'it waits for the field');
      expect(late.opacity, 1);
      final caption = tester.getCenter(find.text('Listening…'));
      final pill = tester.getCenter(_pill);
      expect(caption.dx, closeTo(pill.dx, 1));
      expect(caption.dy, closeTo(pill.dy, 4),
          reason: 'it sits between the buttons, not above them');
      await h.voice.cancelListening();
    });

    testWidgets('keeps going if it is interrupted half way', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      h.isLive.value = true;
      await tester.pump();
      await _run(tester, 250);
      final half = _pillWidth(tester);

      // The user ends the conversation before it has finished arriving.
      h.isLive.value = false;
      await tester.pump();
      await _run(tester, 100);
      expect(_pillWidth(tester), greaterThan(half - 1),
          reason: 'it turns round from where it is, not from the start');
      await _run(tester, 900);

      expect(_field, findsOneWidget);
      expect(_pillWidth(tester), closeTo(250, 1));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the white and the colour are never on one decoration',
      (tester) async {
    final h = _Harness(live: true);
    await h.pump(tester);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      final decoration =
          tester.widget<Container>(_pill).decoration! as BoxDecoration;
      expect(decoration.gradient, isNull,
          reason: 'a gradient beside a colour is drawn through its alpha');
    }
  });

  group('leaving voice mode', () {
    testWidgets('it goes back to exactly what it was', (tester) async {
      final h = _Harness(live: true);
      await h.pump(tester);
      expect(_field, findsNothing);

      h.isLive.value = false;
      await tester.pump();
      await _run(tester, 800);

      expect(_field, findsOneWidget);
      expect(_chatMic, findsOneWidget);
      expect(_voiceMic, findsNothing);
      expect(_pillWidth(tester), closeTo(390 - 100 - 40, 1));
      expect(_gradientLayers(tester), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the text field is usable again', (tester) async {
      final h = _Harness(live: true);
      await h.pump(tester);
      h.isLive.value = false;
      await tester.pump();
      await _run(tester, 800);

      await tester.enterText(_field, 'hello');
      expect(h.controller.text, 'hello');
    });
  });

  group('reduced motion', () {
    testWidgets('it changes at once, without the in-between', (tester) async {
      final h = _Harness(reduced: true);
      await h.pump(tester);

      h.isLive.value = true;
      await tester.pump();
      await tester.pump();

      expect(_field, findsNothing);
      expect(_voiceMic, findsOneWidget);
      expect(_pillWidth(tester), inInclusiveRange(86, 150));
    });
  });

  testWidgets('it fits a narrow phone in every state', (tester) async {
    final h = _Harness();
    await h.pump(tester, width: 320);

    h.isLive.value = true;
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: 'frame $i overflowed');
    }
    h.isLive.value = false;
    await tester.pump();
    await _run(tester, 700);
    expect(tester.takeException(), isNull);
  });
}

/// The opacity the message field is drawn with right now.
double _fieldOpacity(WidgetTester tester) {
  if (_field.evaluate().isEmpty) return 0;
  final opacity = tester.widget<Opacity>(
    find.ancestor(of: _field, matching: find.byType(Opacity)).first,
  );
  return opacity.opacity;
}
