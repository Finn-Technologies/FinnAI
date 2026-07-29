import 'dart:async';
import 'dart:io';

import 'package:finn_ai/src/conversations/conversation_store.dart';
import 'package:finn_ai/src/generation/chat_generation_controller.dart';
import 'package:finn_ai/src/home/home_shell.dart';
import 'package:finn_ai/src/inference/bonsai_inference.dart';
import 'package:finn_ai/src/inference/prompt_intent.dart';
import 'package:finn_ai/src/theme/flux_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late _MemoryKeyStorage keys;
  late ConversationStore store;
  late _FakeRuntime runtime;
  late ChatGenerationController controller;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_generation_test_');
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
    await controller.flushActive();
    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('tokens remain owned by conversation A while B is active', () async {
    final conversationA = store.startNew();
    await controller.start(
      conversationId: conversationA.id,
      prompt: 'Write a long answer',
      history: const [],
      systemContext: '',
    );
    runtime.emit('Alpha ');

    final conversationB = store.startNew();
    runtime.emit('Beta');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await controller.flushActive();

    expect(store.active?.id, conversationB.id);
    expect(
      store.active!.messages.where((message) => message.text.contains('Alpha')),
      isEmpty,
    );
    final storedA = store.conversationById(conversationA.id)!;
    expect(storedA.messages.last.text, 'Alpha Beta');
    expect(controller.activeJob?.conversationId, conversationA.id);
    expect(controller.activeJob?.responseText, 'Alpha Beta');

    store.activate(conversationA.id);
    expect(controller.activeJob?.responseText, 'Alpha Beta');
    await runtime.finish(GenerationFinishReason.eos);
    await _waitUntil(() => !controller.busy);
    await store.flush();

    final restored = ConversationStore(
      keyStorage: keys,
      directoryProvider: () async => directory,
    );
    await restored.initialize();
    final restoredAnswer = restored
        .conversationById(conversationA.id)!
        .messages
        .last;
    expect(restoredAnswer.text, 'Alpha Beta');
    expect(restoredAnswer.status, ConversationMessageStatus.complete);
  });

  test(
    'Stop invalidates late tokens, preserves partial text, and is idempotent',
    () async {
      final conversation = store.startNew();
      await controller.start(
        conversationId: conversation.id,
        prompt: 'Count slowly',
        history: const [],
        systemContext: '',
      );
      runtime.emit('One two');
      runtime.emitDuringStop = ' LATE';

      final stopping = controller.stop();
      expect(controller.job?.state, ChatGenerationState.stopping);
      expect(runtime.stopRequested, isTrue);
      await stopping;
      await controller.stop();

      final answer = store.conversationById(conversation.id)!.messages.last;
      expect(answer.text, 'One two');
      expect(answer.status, ConversationMessageStatus.stopped);
      expect(controller.busy, isFalse);
      expect(controller.lastCancellationMetrics?.lateTokenCount, 1);

      final nextConversation = store.startNew();
      await controller.start(
        conversationId: nextConversation.id,
        prompt: 'A clean next request',
        history: const [],
        systemContext: '',
      );
      expect(controller.busy, isTrue);
      await controller.stop();
    },
  );

  test(
    'cancellation timeout resets runtime and permits later generation',
    () async {
      runtime.acknowledgeStop = false;
      final conversation = store.startNew();
      await controller.start(
        conversationId: conversation.id,
        prompt: 'Long task',
        history: const [],
        systemContext: '',
      );
      runtime.emit('Safe partial');

      final stopping = controller.stop();
      expect(controller.progressLabel, 'Stopping');
      await stopping;

      expect(runtime.resetCalled, isTrue);
      expect(controller.busy, isFalse);
      expect(controller.lastCancellationMetrics?.engineResetRequired, isTrue);
      expect(
        store.conversationById(conversation.id)!.messages.last.text,
        'Safe partial',
      );

      runtime.acknowledgeStop = true;
      final later = store.startNew();
      await controller.start(
        conversationId: later.id,
        prompt: 'Works after reset',
        history: const [],
        systemContext: '',
      );
      expect(controller.busy, isTrue);
      await controller.stop();
    },
  );

  test(
    'error and explicit flush preserve partial output after reload',
    () async {
      final conversation = store.startNew();
      await controller.start(
        conversationId: conversation.id,
        prompt: 'Fail after a partial',
        history: const [],
        systemContext: '',
      );
      runtime.emit('Persist me');
      await controller.flushActive();
      runtime.fail(StateError('simulated'));
      await _waitUntil(() => !controller.busy);

      final restored = ConversationStore(
        keyStorage: keys,
        directoryProvider: () async => directory,
      );
      await restored.initialize();
      final answer = restored.conversationById(conversation.id)!.messages.last;
      expect(answer.text, 'Persist me');
      expect(answer.status, ConversationMessageStatus.failed);
    },
  );

  test('startup marks abandoned generating response interrupted', () async {
    final conversation = store.startNew();
    final assistant = store.beginExchange(
      'Interrupted prompt',
      generationId: 'abandoned-generation',
    );
    store.updateMessageInConversation(
      conversation.id,
      assistant.id,
      'Recovered partial',
      expectedGenerationId: 'abandoned-generation',
    );
    await store.flush();

    final restored = ConversationStore(
      keyStorage: keys,
      directoryProvider: () async => directory,
    );
    await restored.initialize();
    final message = restored.conversationById(conversation.id)!.messages.last;
    expect(message.text, 'Recovered partial');
    expect(message.status, ConversationMessageStatus.interrupted);
    expect(message.finishReason, 'interrupted');
  });

  test('active-generation conversation cannot be deleted', () async {
    final conversation = store.startNew();
    await controller.start(
      conversationId: conversation.id,
      prompt: 'Still generating',
      history: const [],
      systemContext: '',
    );
    expect(store.deleteConversation(conversation.id), isFalse);
    expect(store.conversationById(conversation.id), isNotNull);
    await controller.stop();
    expect(store.deleteConversation(conversation.id), isTrue);
  });

  test('controller disposal flushes the latest partial response', () async {
    final conversation = store.startNew();
    await controller.start(
      conversationId: conversation.id,
      prompt: 'Dispose while running',
      history: const [],
      systemContext: '',
    );
    runtime.emit('Latest partial');
    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    final restored = ConversationStore(
      keyStorage: keys,
      directoryProvider: () async => directory,
    );
    await restored.initialize();
    expect(
      restored.conversationById(conversation.id)!.messages.last.text,
      'Latest partial',
    );
  });

  test(
    'token-limit continuation stays in original conversation once',
    () async {
      final conversationA = store.startNew();
      await controller.start(
        conversationId: conversationA.id,
        prompt: 'Numbered long answer',
        history: const [],
        systemContext: '',
      );
      runtime.emit('1. First section.');
      await runtime.finish(GenerationFinishReason.tokenLimit);
      await _waitUntil(() => !controller.busy);
      final limited = store.conversationById(conversationA.id)!.messages.last;
      expect(limited.status, ConversationMessageStatus.tokenLimited);

      final conversationB = store.startNew();
      final history = [
        for (final message
            in store.conversationById(conversationA.id)!.messages)
          LocalChatTurn(role: message.role.name, content: message.text),
      ];
      await controller.continueResponse(
        conversationId: conversationA.id,
        assistantMessageId: limited.id,
        originalPrompt: 'Numbered long answer',
        history: history,
        systemContext: '',
      );
      runtime.emit(' 2. Second section.');
      await runtime.finish(GenerationFinishReason.eos);
      await _waitUntil(() => !controller.busy);

      expect(store.active?.id, conversationB.id);
      expect(store.active!.messages, isEmpty);
      final completed = store.conversationById(conversationA.id)!.messages.last;
      expect(completed.text, '1. First section. 2. Second section.');
      expect(completed.continuationCount, 1);
      expect(
        await controller.continueResponse(
          conversationId: conversationA.id,
          assistantMessageId: completed.id,
          originalPrompt: 'Numbered long answer',
          history: history,
          systemContext: '',
        ),
        isNull,
      );
    },
  );

  testWidgets('other-chat notice exposes Open and Stop without answer text', (
    tester,
  ) async {
    var opened = false;
    var stopped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: Scaffold(
          body: OtherChatGenerationNotice(
            title: 'Chat A',
            onOpen: () => opened = true,
            onStop: () => stopped = true,
          ),
        ),
      ),
    );

    expect(find.text('Generating in Chat A'), findsOneWidget);
    expect(find.textContaining('Alpha private answer'), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.tap(find.text('Stop'));
    expect(opened, isTrue);
    expect(stopped, isTrue);
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 500 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

class _FakeRuntime extends ChangeNotifier implements ChatInferenceRuntime {
  InferencePhase _phase = InferencePhase.idle;
  StreamController<String>? _stream;
  GenerationReport? _report;
  bool acknowledgeStop = true;
  bool stopRequested = false;
  bool resetCalled = false;
  String? emitDuringStop;

  @override
  InferencePhase get phase => _phase;
  @override
  String get status =>
      _phase == InferencePhase.error ? 'Simulated error' : 'Ready';
  @override
  String get selectedModelName => 'Finn AI Lite';
  @override
  String get lastGeneratingModelName => 'Finn AI Lite';
  @override
  GenerationReport? get lastGenerationReport => _report;

  @override
  Stream<String> generateReply(
    String prompt, {
    required String conversationId,
    required List<LocalChatTurn> history,
    required String systemContext,
    PromptAnalysis? promptAnalysis,
  }) {
    _stream = StreamController<String>(sync: true);
    _phase = InferencePhase.generating;
    notifyListeners();
    return _stream!.stream;
  }

  void emit(String value) => _stream!.add(value);

  Future<void> finish(GenerationFinishReason reason) async {
    _report = GenerationReport(
      model: bonsaiModels.first,
      intent: PromptIntent.quickQuestion,
      route: BonsaiTier.lite,
      outputBudget: 320,
      finishReason: reason,
      firstTokenLatency: const Duration(milliseconds: 1),
      totalGenerationTime: const Duration(milliseconds: 10),
      outputTokens: 2,
      tokensPerSecond: 5,
    );
    _phase = InferencePhase.idle;
    notifyListeners();
    await _stream!.close();
  }

  void fail(Object error) {
    _phase = InferencePhase.error;
    notifyListeners();
    _stream!.addError(error, StackTrace.current);
  }

  @override
  Future<void> stopGeneration() async {
    stopRequested = true;
    final late = emitDuringStop;
    if (late != null) _stream?.add(late);
    if (!acknowledgeStop) {
      await Completer<void>().future;
    }
    _phase = InferencePhase.idle;
    notifyListeners();
    await _stream?.close();
  }

  @override
  Future<void> resetAfterCancellationTimeout() async {
    resetCalled = true;
    _phase = InferencePhase.idle;
    notifyListeners();
    if (_stream?.isClosed == false) await _stream?.close();
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
