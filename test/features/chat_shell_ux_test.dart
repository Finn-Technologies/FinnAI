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
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

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
    testWidgets('composer controls fill a 48dp touch target', (tester) async {
      _useMobileSize(tester);
      await _pumpComposer(tester, voiceEnabled: true, browse: true);

      expect(
        tester.getSize(find.byKey(const ValueKey('add-attachment-button'))),
        const Size(48, 48),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('browse-toggle-surface'))),
        const Size(48, 48),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('mic-button-surface'))),
        const Size(48, 48),
      );
      // The send glyph keeps its compact visual inside the enlarged target.
      expect(
        tester.getSize(find.byKey(const ValueKey('send-button-hit'))),
        const Size(48, 48),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('send-button-surface'))),
        const Size(36, 36),
      );
    });

    // The pill looks like one big input. On device the bare field measured only
    // 20dp tall inside a 56dp pill, so most of the visible input was inert and
    // tapping it did nothing — the field itself has to carry the target.
    testWidgets('the text field is at least 48dp tall', (tester) async {
      _useMobileSize(tester);
      await _pumpComposer(tester, voiceEnabled: true, browse: true);

      expect(tester.getSize(find.byType(TextField)).height,
          greaterThanOrEqualTo(48));
    });

    // The opening prompt is centred, the way Gemini and ChatGPT place theirs,
    // and the draft it becomes is left-aligned. Asserting the rendered position
    // of the hint — not just the property — is what proves it.
    testWidgets('the placeholder is centred until there is a draft', (
      tester,
    ) async {
      _useMobileSize(tester);
      await _pumpComposer(tester);

      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).textAlign, TextAlign.center);
      expect(
        tester.widget<Text>(find.text('Ask anything')).textAlign,
        TextAlign.center,
      );
      expect(
        tester.getCenter(find.text('Ask anything')).dx,
        closeTo(tester.getCenter(field).dx, 1.0),
      );

      await tester.enterText(field, 'Draft a short email');
      await tester.pump();

      // The editable's own box spans the field, so its geometry cannot show the
      // alignment; the field's alignment is the contract that matters here.
      expect(tester.widget<TextField>(field).textAlign, TextAlign.start);
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
        const Size(48, 48),
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
        const Size(48, 48),
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

    testWidgets('reply actions meet the 48dp target', (tester) async {
      _useMobileSize(tester);
      store
        ..startNew()
        ..add(ConversationRole.user, 'Hello')
        ..add(ConversationRole.assistant, 'Hi there');

      await _pumpShell(tester, store, generation);
      await tester.pump(const Duration(milliseconds: 300));

      final copy = find.byTooltip('Copy');
      expect(copy, findsWidgets);
      expect(tester.getSize(copy.first), const Size(48, 48));
      expect(
        tester.getSize(find.byTooltip('Regenerate').first),
        const Size(48, 48),
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
    testWidgets('welcome suggestion chips use the disclosure token', (
      tester,
    ) async {
      _useMobileSize(tester);
      await _pumpShell(tester, store, generation);
      await tester.pump(const Duration(milliseconds: 300));

      final chipFinder = find.byType(ActionChip).first;
      final chip = tester.widget<ActionChip>(chipFinder);
      expect(
        chip.backgroundColor,
        FluxColors.disclosureOf(tester.element(chipFinder)),
      );
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
        speech: _FakeSpeechBackend()
          ..initializeResult = false
          ..permissionResult = false,
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

    testWidgets('a short window scrolls instead of overflowing',
        (tester) async {
      _useMobileSize(tester, const Size(320, 280));
      final speech = _FakeSpeechBackend();
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
  bool browse = false,
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
          onToggleBrowse: browse ? () {} : null,
        ),
      ),
    ),
  );
  await tester.pump();
}

VoidCallback? _sendTap(WidgetTester tester) => tester
    .widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('send-button-hit')),
        matching: find.byType(InkWell),
      ),
    )
    .onTap;

Future<VoiceChatController> _pumpVoiceSheet(
  WidgetTester tester, {
  _FakeSpeechBackend? speech,
}) async {
  final controller = VoiceChatController(
    speech: speech ?? _FakeSpeechBackend(),
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

class _FakeSpeechBackend implements SpeechBackend {
  bool initializeResult = true;
  bool permissionResult = true;
  bool listening = false;
  void Function(SpeechRecognitionResult result)? onResult;

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError error)? onError,
    void Function(String status)? onStatus,
  }) async =>
      initializeResult;

  @override
  Future<bool> get hasPermission async => permissionResult;

  @override
  bool get isListening => listening;

  @override
  Future<void> listen({
    void Function(SpeechRecognitionResult result)? onResult,
    void Function(double level)? onSoundLevelChange,
    bool preferOnDevice = false,
  }) async {
    this.onResult = onResult;
    listening = true;
  }

  @override
  Future<void> stop() async => listening = false;

  @override
  Future<void> cancel() async => listening = false;

  void emitResult(String words, {required bool finalResult}) {
    onResult?.call(
      SpeechRecognitionResult(
        [SpeechRecognitionWords(words, const [], 0.9)],
        finalResult ? ResultType.finalResult.value : ResultType.partial.value,
      ),
    );
  }
}

class _FakeTtsBackend implements TtsBackend {
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
