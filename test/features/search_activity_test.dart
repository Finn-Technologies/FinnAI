import 'dart:async';
import 'dart:io';

import 'package:finn_ai/src/features/chat/chat_generation_controller.dart';
import 'package:finn_ai/src/features/chat/tool_activity_indicator.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/prompt_intent.dart';
import 'package:finn_ai/src/inference/ttft_metrics.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The browser steps of a turn belong to the reply that produced them: they
/// stream inline while the turn runs and stay attached to the message
/// afterwards, instead of floating over the whole conversation.
void main() {
  late Directory directory;
  late _MemoryKeyStorage keys;
  late ConversationStore store;
  late _FakeRuntime runtime;
  late ChatGenerationController controller;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_search_activity_');
    keys = _MemoryKeyStorage();
    store = ConversationStore(
      keyStorage: keys,
      directoryProvider: () async => directory,
    );
    await store.initialize();
    runtime = _FakeRuntime();
    controller = ChatGenerationController(
      conversations: store,
      runtime: runtime,
      persistenceInterval: const Duration(seconds: 1),
      cancellationTimeout: const Duration(milliseconds: 35),
    );
  });

  tearDown(() async {
    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  const searchStep = ToolActivity(
    kind: ToolActivityKind.search,
    label: 'weather in Lisbon',
  );
  const openStep = ToolActivity(
    kind: ToolActivityKind.open,
    label: 'Lisbon forecast',
    detail: 'https://example.com/lisbon',
  );

  test('steps recorded during a turn land on the finished message', () async {
    final conversation = store.startNew();
    await controller.start(
      conversationId: conversation.id,
      prompt: 'What is the weather like today?',
      history: const [],
      systemContext: '',
    );

    controller.noteToolActivity(searchStep);
    expect(controller.toolActivities, [searchStep]);
    // The streaming reply reads the live list off the active job.
    expect(controller.activeJob?.toolActivities, [searchStep]);

    controller.noteToolActivity(openStep);
    runtime.emit('It is sunny.');
    await runtime.finish(GenerationFinishReason.eos);
    await _waitUntil(() => !controller.busy);
    await store.flush();

    final answer = store.conversationById(conversation.id)!.messages.last;
    expect(answer.toolActivities, [searchStep, openStep]);
    // The live list is released once the turn ends; the message keeps them.
    expect(controller.toolActivities, isEmpty);
  });

  test('steps survive an encrypted reload', () async {
    final conversation = store.startNew();
    await controller.start(
      conversationId: conversation.id,
      prompt: 'Anything recent?',
      history: const [],
      systemContext: '',
    );
    controller.noteToolActivity(searchStep);
    runtime.emit('Sure.');
    await runtime.finish(GenerationFinishReason.eos);
    await _waitUntil(() => !controller.busy);
    await store.flush();

    final restored = ConversationStore(
      keyStorage: keys,
      directoryProvider: () async => directory,
    );
    await restored.initialize();

    final answer = restored.conversationById(conversation.id)!.messages.last;
    expect(answer.toolActivities.length, 1);
    expect(answer.toolActivities.single.kind, ToolActivityKind.search);
    expect(answer.toolActivities.single.label, 'weather in Lisbon');
  });

  test('a search recorded before the turn starts still reaches the message',
      () async {
    final conversation = store.startNew();
    // The policy path searches before it asks the model, so the step exists
    // before the job does.
    controller.noteToolActivity(searchStep);
    expect(controller.toolActivities, [searchStep]);

    await controller.start(
      conversationId: conversation.id,
      prompt: 'Summarise today',
      history: const [],
      systemContext: '',
    );
    expect(controller.activeJob?.toolActivities, [searchStep]);

    runtime.emit('Here it is.');
    await runtime.finish(GenerationFinishReason.eos);
    await _waitUntil(() => !controller.busy);
    await store.flush();

    final answer = store.conversationById(conversation.id)!.messages.last;
    expect(answer.toolActivities, [searchStep]);
  });

  test('a turn with no browser work records nothing', () async {
    final conversation = store.startNew();
    await controller.start(
      conversationId: conversation.id,
      prompt: 'Say hello',
      history: const [],
      systemContext: '',
    );
    runtime.emit('Hello.');
    await runtime.finish(GenerationFinishReason.eos);
    await _waitUntil(() => !controller.busy);
    await store.flush();

    final answer = store.conversationById(conversation.id)!.messages.last;
    expect(answer.toolActivities, isEmpty);
  });

  group('ToolActivityIndicator', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<ToolActivity> activities,
      required bool busy,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FluxTheme.light,
          home: Scaffold(
            body: ToolActivityIndicator(activities: activities, busy: busy),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('running turns say they are searching', (tester) async {
      await pump(tester, activities: const [searchStep], busy: true);
      expect(find.text('Searching the web…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('finished turns collapse to a summary and stay expandable', (
      tester,
    ) async {
      await pump(
        tester,
        activities: const [searchStep, openStep],
        busy: false,
      );

      expect(find.text('Searched the web'), findsOneWidget);
      expect(find.text('2 steps'), findsOneWidget);
      expect(
        find.text('Searched the web for “weather in Lisbon”'),
        findsOneWidget,
      );

      await tester.tap(find.text('Searched the web'));
      await tester.pumpAndSettle();

      expect(find.text('Read “Lisbon forecast”'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders nothing without browser work', (tester) async {
      await pump(tester, activities: const [], busy: true);
      expect(find.byType(FluxDisclosure), findsNothing);
      expect(find.text('Searching the web…'), findsNothing);
    });
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

class _FakeRuntime extends ChangeNotifier implements ChatInferenceRuntime {
  StreamController<String>? _stream;
  GenerationReport? _report;

  @override
  InferencePhase get phase => InferencePhase.idle;
  @override
  String get status => 'Ready';
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
    _stream = StreamController<String>();
    return _stream!.stream;
  }

  void emit(String value) => _stream!.add(value);

  Future<void> finish(GenerationFinishReason reason) async {
    _report = GenerationReport(
      model: finnModels.first,
      intent: PromptIntent.quickQuestion,
      route: FinnModelTier.standard,
      outputBudget: 320,
      finishReason: reason,
      firstTokenLatency: const Duration(milliseconds: 1),
      totalGenerationTime: const Duration(milliseconds: 10),
      outputTokens: 2,
      tokensPerSecond: 5,
    );
    notifyListeners();
    await _stream!.close();
  }

  @override
  Future<void> stopGeneration() async {}

  @override
  Future<void> resetAfterCancellationTimeout() async {}
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
