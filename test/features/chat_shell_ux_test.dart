import 'dart:async';
import 'dart:io';

import 'package:finn_ai/src/features/actions/chat_device_actions.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/chat/chat_generation_controller.dart';
import 'package:finn_ai/src/features/chat/home_shell.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';
import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';
import 'package:finn_ai/src/features/voice/voice_sheet.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/prompt_intent.dart';
import 'package:finn_ai/src/inference/ttft_metrics.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_speech_backend.dart';

/// UX regressions for the chat shell and the voice sheet: touch targets, the
/// busy/preparing control states, the short-window voice layout, and the
/// lifecycle of the generation controller's native stream.
void main() {
  late Directory directory;
  late _MemoryKeyStorage keys;
  late ConversationStore store;
  late _FakeRuntime runtime;
  late ChatGenerationController generation;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_chat_shell_ux_');
    keys = _MemoryKeyStorage();
    store = ConversationStore(
      keyStorage: keys,
      directoryProvider: () async => directory,
    );
    await store.initialize();
    runtime = _FakeRuntime();
    generation = ChatGenerationController(
      conversations: store,
      runtime: runtime,
      persistenceInterval: const Duration(seconds: 1),
      cancellationTimeout: const Duration(milliseconds: 35),
    );
  });

  tearDown(() async {
    generation.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  group('ChatComposer touch targets and control states', () {
    testWidgets('composer controls fill their 50dp touch target', (
      tester,
    ) async {
      _useMobileSize(tester);
      await _pumpComposer(tester, voiceEnabled: true);

      // The design's circles are 50dp.
      expect(
        tester.getSize(find.byKey(const ValueKey('add-attachment-button'))),
        const Size(50, 50),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('mic-button-surface'))),
        const Size(50, 50),
      );

      // The right-hand control becomes send as soon as there is a draft.
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const ValueKey('send-button-hit'))),
        const Size(50, 50),
      );
    });

    // The pill looks like one big input. On device the bare field measured only
    // 20dp tall inside a 56dp pill, so most of the visible input was inert and
    // tapping it did nothing. The band carries the 48dp target instead of the
    // field, because a 48dp field pushes the placeholder off the midline.
    testWidgets('the field band carries a 48dp target', (tester) async {
      _useMobileSize(tester);
      await _pumpComposer(tester, voiceEnabled: true);

      final band = find.byKey(const ValueKey('composer-field-band'));
      expect(tester.getSize(band).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSize(band).width,
        tester.getSize(find.byType(TextField)).width,
        reason: 'the tappable band covers the field, edge to edge',
      );
      // The field itself stays natural-height: the band is the target.
      expect(tester.getSize(find.byType(TextField)).height, lessThan(48));
    });

    // "Ask anything" sits on the pill's midline. Stretching the field to 48dp
    // put it 12dp above that line, because the decorator lays the placeholder
    // out from the top of whatever box it is given.
    testWidgets('the placeholder sits on the pill midline', (tester) async {
      _useMobileSize(tester);
      await _pumpComposer(tester, voiceEnabled: true);

      final pill = find.byKey(const ValueKey('chat-composer-motion'));
      // The field box sits 2dp above the pill's middle on purpose: the typeface
      // has more room above its letters than below, so the box has to be lifted
      // for the *letters* to be centred (see composer_centering_test.dart).
      const lift = 2.0;
      expect(
        tester.getCenter(find.text('Ask anything')).dy,
        closeTo(tester.getCenter(pill).dy - lift, 1.0),
      );

      // The draft the placeholder becomes keeps that line: the field box is
      // centred in the band, so a one-line draft sits on the midline too.
      await tester.enterText(find.byType(TextField), 'Draft a short email');
      await tester.pump();
      expect(
        tester.getCenter(find.byType(TextField)).dy,
        closeTo(tester.getCenter(pill).dy - lift, 1.0),
      );
    });

    // A placeholder long enough to wrap must not inflate the pill — it is one
    // line in every locale, ellipsised when the pill is narrow. The pill is
    // 52 tall: the 50dp field plus its 1px hairline on each side.
    testWidgets('a long hint stays on one line', (tester) async {
      _useMobileSize(tester);
      await _pumpComposer(
        tester,
        hintText: 'Ask Finn anything at all about this phone',
      );

      expect(tester.getSize(find.byType(TextField)).height, lessThan(48));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('chat-composer-motion')))
            .height,
        52,
      );
    });

    testWidgets('tapping the band focuses the field', (tester) async {
      _useMobileSize(tester);
      await _pumpComposer(tester, voiceEnabled: true);

      final band = find.byKey(const ValueKey('composer-field-band'));
      final rect = tester.getRect(band);
      // A point inside the band but clear of the field's own text line.
      await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
      await tester.pump();

      expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
          isTrue);
    });

    testWidgets('a busy composer swaps send and mic for a full-size stop', (
      tester,
    ) async {
      _useMobileSize(tester);
      await _pumpComposer(tester, busy: true, voiceEnabled: true);

      expect(find.byKey(const ValueKey('send-button-hit')), findsNothing);
      expect(find.byKey(const ValueKey('mic-button-surface')), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('stop-button-surface'))),
        const Size(50, 50),
      );
    });

    testWidgets('send stays inert until there is something to send', (
      tester,
    ) async {
      _useMobileSize(tester);
      await _pumpComposer(tester);

      expect(_sendTap(tester), isNull);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      expect(_sendTap(tester), isNotNull);
    });

    testWidgets('a blocked composer disables the field and the send control', (
      tester,
    ) async {
      _useMobileSize(tester);
      await _pumpComposer(tester, blocked: true, text: 'Drafted');

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(_sendTap(tester), isNull);
    });
  });

  group('ChatComposer live voice', () {
    Future<void> pumpLive(
      WidgetTester tester,
      VoiceChatController voice, {
      bool busy = false,
      VoidCallback? onEnd,
      VoidCallback? onTap,
    }) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: FluxTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatComposer(
              controller: controller,
              focusNode: focusNode,
              blocked: false,
              busy: busy,
              onSend: () {},
              onStop: () {},
              voiceEnabled: true,
              voiceListening: true,
              voice: voice,
              onVoiceToggle: onEnd,
              onVoiceTap: onTap,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows the live pill and a caption instead of the field', (
      tester,
    ) async {
      _useMobileSize(tester);
      final voice = VoiceChatController(
        speech: FakeSpeechBackend(),
        tts: _FakeTtsBackend(),
      );
      addTearDown(voice.dispose);
      await voice.startListening();

      await pumpLive(tester, voice);

      expect(find.byKey(const ValueKey('voice-pill')), findsOneWidget);
      expect(find.text('Listening…'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await voice.cancelListening();
    });

    testWidgets('the cross ends the conversation, the mic taps', (
      tester,
    ) async {
      _useMobileSize(tester);
      final voice = VoiceChatController(
        speech: FakeSpeechBackend(),
        tts: _FakeTtsBackend(),
      );
      addTearDown(voice.dispose);
      var ended = 0;
      var tapped = 0;

      await pumpLive(
        tester,
        voice,
        onEnd: () => ended++,
        onTap: () => tapped++,
      );
      await tester.tap(find.byKey(const ValueKey('add-attachment-button')));
      await tester.tap(find.byKey(const ValueKey('voice-toggle-surface')));
      await tester.tap(find.byKey(const ValueKey('voice-pill')));

      expect(ended, 1);
      expect(tapped, 2, reason: 'the pill and the mic do the same thing');
    });

    testWidgets('a reply being written does not swap the mic for Stop', (
      tester,
    ) async {
      _useMobileSize(tester);
      final voice = VoiceChatController(
        speech: FakeSpeechBackend(),
        tts: _FakeTtsBackend(),
      );
      addTearDown(voice.dispose);

      await pumpLive(tester, voice, busy: true);

      // The live controls stay put through the whole turn; tapping the mic is
      // how the user cuts in.
      expect(
          find.byKey(const ValueKey('voice-toggle-surface')), findsOneWidget);
      expect(find.byKey(const ValueKey('stop-button-surface')), findsNothing);
    });

    testWidgets('the live bar fits a narrow phone', (tester) async {
      _useMobileSize(tester, const Size(320, 640));
      final voice = VoiceChatController(
        speech: FakeSpeechBackend(),
        tts: _FakeTtsBackend(),
      );
      addTearDown(voice.dispose);

      await pumpLive(tester, voice);

      expect(tester.takeException(), isNull);
    });
  });

  group('HomeShell composer states', () {
    testWidgets('Stop is reachable from the moment a turn is prepared', (
      tester,
    ) async {
      _useMobileSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: FluxTheme.light,
          home: HomeShell(
            conversationStore: store,
            generationController: generation,
            initializeServices: false,
            // Never resolves, so the turn stays in the preparing phase.
            deviceActions: _HangingDeviceActions(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), 'What is the weather?');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-button-hit')));
      await tester.pump();

      expect(find.byKey(const ValueKey('stop-button-surface')), findsOneWidget);
      expect(find.byKey(const ValueKey('send-button-hit')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('HomeShell touch targets', () {
    testWidgets('menu button and sidebar rows meet the 48dp target', (
      tester,
    ) async {
      _useMobileSize(tester);
      final conversation = store.startNew();
      store.add(ConversationRole.user, 'Hey');

      await _pumpShell(tester, store, generation);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.getSize(find.byKey(const ValueKey('home-menu-button'))),
        const Size(50, 50),
      );

      await tester.tap(find.byKey(const ValueKey('home-menu-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final tile = find.byKey(ValueKey(conversation.id));
      expect(tile, findsOneWidget);
      final tileBox =
          find.descendant(of: tile, matching: find.byType(Container));
      expect(tileBox, findsWidgets);
      expect(tester.getSize(tileBox.first).height, greaterThanOrEqualTo(48));
    });

    // The design sets the reply glyphs on a 40dp pitch (25px artwork, 15px
    // between neighbours), so the touch target follows that pitch rather than
    // the usual 48dp: overlapping targets would steal each other's taps.
    testWidgets('reply actions sit on the design\'s 40dp pitch', (
      tester,
    ) async {
      _useMobileSize(tester);
      store
        ..startNew()
        ..add(ConversationRole.user, 'Hello')
        ..add(ConversationRole.assistant, 'Hi there');

      await _pumpShell(tester, store, generation);
      await tester.pump(const Duration(milliseconds: 300));

      final copy = find.byTooltip('Copy');
      expect(copy, findsWidgets);
      expect(tester.getSize(copy.first), const Size(40, 40));
      expect(
        tester.getSize(find.byTooltip('Report').first),
        const Size(40, 40),
      );
      // Regenerate moved into the overflow, which shares the same pitch.
      expect(
        tester.getSize(find.byTooltip('More actions').first),
        const Size(40, 40),
      );
    });

    testWidgets('a failed turn offers a full-size Retry target', (
      tester,
    ) async {
      _useMobileSize(tester);
      final conversation = store.startNew();
      // The failed turn touches encryption and disk, so it runs on the real
      // event loop rather than the widget test's fake one.
      await tester.runAsync(() async {
        await generation.start(
          conversationId: conversation.id,
          prompt: 'Fail please',
          history: const [],
          systemContext: '',
        );
        runtime.emit('Partial answer');
        runtime.fail(StateError('simulated'));
        await _waitUntil(() => !generation.busy);
      });

      await _pumpShell(tester, store, generation);
      await tester.pump(const Duration(milliseconds: 300));

      final retry = find.widgetWithText(TextButton, 'Retry');
      expect(retry, findsOneWidget);
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    });
  });

  group('HomeShell token and copy adoption', () {
    testWidgets('the empty slate carries no suggestion chips', (tester) async {
      _useMobileSize(tester);
      await _pumpShell(tester, store, generation);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ActionChip), findsNothing);
      expect(find.text("Hi, what's on your mind?"), findsOneWidget);
    });

    testWidgets('article photo counter is locale-neutral', (tester) async {
      _useMobileSize(tester);
      final assistant = store.beginExchange('Show me pictures');
      store.updateMessageInConversation(
        store.active!.id,
        assistant.id,
        'Here you go.',
        sources: [
          WebSource(
            title: 'First',
            url: Uri.parse('https://one.example.com'),
            snippet: 'First excerpt.',
            imageUrl: 'https://one.example.com/one.jpg',
          ),
          WebSource(
            title: 'Second',
            url: Uri.parse('https://two.example.com'),
            snippet: 'Second excerpt.',
            imageUrl: 'https://two.example.com/two.jpg',
          ),
        ],
      );

      await _pumpShell(tester, store, generation);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1/2'), findsOneWidget);
      expect(find.textContaining(' of '), findsNothing);
    });
  });

  group('VoiceSheet', () {
    testWidgets('close control meets the 48dp target', (tester) async {
      _useMobileSize(tester, const Size(390, 844));
      final controller = await _pumpVoiceSheet(tester);

      expect(
        tester.getSize(find.byKey(const ValueKey('voice-close-button'))),
        const Size(48, 48),
      );
      unawaited(controller.cancelListening());
    });

    testWidgets('an error state shows the tap hint only once', (tester) async {
      _useMobileSize(tester, const Size(390, 844));
      await _pumpVoiceSheet(
        tester,
        speech: FakeSpeechBackend()..initResult = SpeechInit.micDenied,
      );
      await tester.pump();

      final error = find.textContaining('Microphone access is off');
      expect(error, findsOneWidget);
      expect(
        tester.widget<Text>(error).style?.color,
        FluxColors.destructiveOf(tester.element(error)),
      );
      // The status line no longer repeats the bottom hint, so "Tap the mic
      // and speak" appears exactly once above the error.
      expect(find.text('Tap the mic and speak'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a missing speech model offers the download, not an error',
        (tester) async {
      _useMobileSize(tester, const Size(390, 844));
      final speech = FakeSpeechBackend()..initResult = SpeechInit.needsModel;
      await _pumpVoiceSheet(tester, speech: speech);
      await tester.pump();

      expect(find.textContaining('one-time'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('voice-model-download')), findsOneWidget);
      expect(find.textContaining('Microphone access is off'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('voice-model-download')));
      await tester.pump();
      await tester.pump();

      expect(speech.downloadCalls, 1);
      expect(find.byKey(const ValueKey('voice-model-download')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the download shows its progress', (tester) async {
      _useMobileSize(tester, const Size(390, 844));
      final speech = FakeSpeechBackend()..initResult = SpeechInit.needsModel;
      await _pumpVoiceSheet(tester, speech: speech);
      await tester.pump();

      speech.modelStatus.value = const SpeechModelStatus(
        SpeechModelPhase.downloading,
        progress: 0.4,
        totalBytes: 161000000,
      );
      await tester.pump();

      expect(find.textContaining('40%'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('voice-model-progress')), findsOneWidget);
    });

    testWidgets('a failed download can be retried', (tester) async {
      _useMobileSize(tester, const Size(390, 844));
      final speech = FakeSpeechBackend()..initResult = SpeechInit.needsModel;
      await _pumpVoiceSheet(tester, speech: speech);
      await tester.pump();

      speech.modelStatus.value =
          const SpeechModelStatus(SpeechModelPhase.failed);
      await tester.pump();

      expect(find.textContaining("didn't finish"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a short window scrolls instead of overflowing',
        (tester) async {
      _useMobileSize(tester, const Size(320, 280));
      final speech = FakeSpeechBackend();
      final controller = await _pumpVoiceSheet(tester, speech: speech);

      speech.emitResult(
        'This is a fairly long spoken transcript that wraps onto more than a '
        'single line inside the narrow sheet.',
        finalResult: false,
      );
      await tester.pump();

      expect(find.text('Tap the mic and speak'), findsOneWidget);
      expect(tester.takeException(), isNull);
      unawaited(controller.cancelListening());
    });
  });
}

void _useMobileSize(WidgetTester tester, [Size size = const Size(390, 844)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpShell(
  WidgetTester tester,
  ConversationStore store,
  ChatGenerationController generation,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: FluxTheme.light,
      home: HomeShell(
        conversationStore: store,
        generationController: generation,
        initializeServices: false,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpComposer(
  WidgetTester tester, {
  bool blocked = false,
  bool busy = false,
  bool voiceEnabled = false,
  String? hintText,
  String text = '',
}) async {
  final controller = TextEditingController(text: text);
  final focusNode = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focusNode.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: FluxTheme.light,
      home: Scaffold(
        body: ChatComposer(
          controller: controller,
          focusNode: focusNode,
          blocked: blocked,
          busy: busy,
          onSend: () {},
          onStop: () {},
          onMic: () {},
          voiceEnabled: voiceEnabled,
          hintText: hintText,
        ),
      ),
    ),
  );
  await tester.pump();
}

VoidCallback? _sendTap(WidgetTester tester) {
  final hit = find.byKey(const ValueKey('send-button-hit'));
  if (hit.evaluate().isEmpty) return null;
  return tester
      .widget<InkWell>(
        find.descendant(of: hit, matching: find.byType(InkWell)),
      )
      .onTap;
}

Future<VoiceChatController> _pumpVoiceSheet(
  WidgetTester tester, {
  FakeSpeechBackend? speech,
}) async {
  final controller = VoiceChatController(
    speech: speech ?? FakeSpeechBackend(),
    tts: _FakeTtsBackend(),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: FluxTheme.light,
      home: VoiceSheet(
        voice: controller,
        onSendTranscript: (_) async {},
        onStopGeneration: () {},
      ),
    ),
  );
  await tester.pump();
  return controller;
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

/// A device-action resolver that never answers, holding a turn in the shell's
/// "preparing" phase so its busy controls can be observed.
class _HangingDeviceActions extends ChatDeviceActions {
  _HangingDeviceActions();

  @override
  Future<DeviceActionInvocation?> resolve(String prompt) =>
      Completer<DeviceActionInvocation?>().future;
}

class _FakeRuntime extends ChangeNotifier implements ChatInferenceRuntime {
  final StreamController<String> _stream = StreamController<String>(sync: true);
  GenerationReport? _report;
  InferencePhase _phase = InferencePhase.idle;

  @override
  InferencePhase get phase => _phase;
  @override
  String get status =>
      _phase == InferencePhase.error ? 'Simulated error' : 'Ready';
  @override
  String get selectedModelName => 'LFM2.5-VL 1.6B';
  @override
  String get lastGeneratingModelName => 'LFM2.5-VL 1.6B';
  @override
  GenerationReport? get lastGenerationReport => _report;

  @override
  Stream<String> generateReply(
    String prompt, {
    required String conversationId,
    required List<LocalChatTurn> history,
    required String systemContext,
    PromptAnalysis? promptAnalysis,
    TtftTrace? trace,
  }) {
    _phase = InferencePhase.generating;
    notifyListeners();
    return _stream.stream;
  }

  void emit(String value) => _stream.add(value);

  void fail(Object error) {
    _phase = InferencePhase.error;
    notifyListeners();
    _stream.addError(error, StackTrace.current);
  }

  @override
  Future<void> stopGeneration() async {
    _phase = InferencePhase.idle;
    notifyListeners();
    if (!_stream.isClosed) await _stream.close();
  }

  @override
  Future<void> resetAfterCancellationTimeout() async {
    _phase = InferencePhase.idle;
    notifyListeners();
    if (!_stream.isClosed) await _stream.close();
  }
}

class _MemoryKeyStorage implements SecureKeyStorage {
  Uint8List? value;

  @override
  Future<void> deleteKey(String alias) async => value = null;

  @override
  Future<Uint8List?> readKey(String alias) async => value;

  @override
  Future<void> writeKey(String alias, Uint8List key) async {
    value = Uint8List.fromList(key);
  }
}

class _FakeTtsBackend implements TtsBackend {
  @override
  final ValueNotifier<double> level = ValueNotifier(0);

  String? language;
  int prepareCalls = 0;
  int releaseCalls = 0;

  @override
  Future<void> setLanguage(String? language) async => this.language = language;

  @override
  Future<void> prepare() async => prepareCalls++;

  @override
  Future<void> release() async => releaseCalls++;
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
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
