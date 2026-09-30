import 'dart:async';
import 'dart:io';

import 'package:finn_ai/src/features/chat/chat_generation_controller.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/prompt_intent.dart';
import 'package:finn_ai/src/inference/ttft_metrics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late _MemoryKeyStorage keys;
  late _GatedStore store;
  late _StreamRuntime runtime;
  late ChatGenerationController controller;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_stream_ctrl_');
    keys = _MemoryKeyStorage();
    store = _GatedStore(
      keyStorage: keys,
      directoryProvider: () async => directory,
    );
    await store.initialize();
    runtime = _StreamRuntime();
    controller = ChatGenerationController(
      conversations: store,
      runtime: runtime,
      persistenceInterval: const Duration(seconds: 30),
      cancellationTimeout: const Duration(milliseconds: 50),
    );
  });

  tearDown(() async {
    store.releaseFlushes();
    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  group('O(n^2) token path', () {
    test(
      'a 500-token burst is materialised a handful of times, not once a token',
      () async {
        final conversation = store.startNew();
        await controller.start(
          conversationId: conversation.id,
          prompt: 'Write a long answer',
          history: const [],
          systemContext: '',
        );

        // The native decode loop delivers a burst: llama.cpp hands the Dart
        // side a batch of tokens per tick, not one token per frame.
        const tokenCount = 500;
        final tokens = [for (var i = 0; i < tokenCount; i++) 'word$i '];
        for (final token in tokens) {
          runtime.emit(token);
        }

        // What the old path did: one StringBuffer.toString() per token, each
        // copying the whole answer as it stood at that moment.
        final quadraticChars = _cumulativeLengths(tokens);
        // ignore: avoid_print
        print('old per-token path would copy $quadraticChars chars');

        final afterBurst = controller.responseMaterializedChars;
        expect(controller.responseMaterializationCount, lessThan(20),
            reason: 'the burst must not re-copy the answer per token');
        // ignore: avoid_print
        print('after burst: $afterBurst chars in '
            '${controller.responseMaterializationCount} snapshots');

        await runtime.finish(GenerationFinishReason.eos);
        await _waitUntil(() => !controller.busy);

        final finalChars = controller.responseMaterializedChars;
        expect(
          finalChars,
          lessThan(quadraticChars ~/ 100),
          reason:
              'copied $finalChars chars vs $quadraticChars for the old path',
        );
        // ignore: avoid_print
        print(
          'materialisations: $tokenCount tokens -> '
          '${controller.responseMaterializationCount} snapshots, '
          '$quadraticChars chars (old per-token) -> $finalChars chars',
        );

        final answer = store.conversationById(conversation.id)!.messages.last;
        expect(answer.text, tokens.join());
        expect(answer.text, endsWith('word499 '));
        expect(answer.status, ConversationMessageStatus.complete);
      },
    );

    test('every notify publishes the complete accumulated text', () async {
      final conversation = store.startNew();
      await controller.start(
        conversationId: conversation.id,
        prompt: 'Notify coherence',
        history: const [],
        systemContext: '',
      );
      var notifications = 0;
      final seen = <String>[];
      controller.addListener(() {
        notifications++;
        seen.add(controller.job?.responseText ?? '<null>');
      });

      var buffer = '';
      for (var i = 0; i < 40; i++) {
        buffer += 't$i ';
        runtime.emit('t$i ');
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }

      expect(notifications, greaterThan(0));
      // Every observed snapshot must be a prefix of the final text: the UI can
      // never see a partial, truncated or stale snapshot.
      for (final snapshot in seen) {
        expect(
          buffer.startsWith(snapshot),
          isTrue,
          reason: 'snapshot "$snapshot" is not a prefix of the streamed text',
        );
      }
      // The final publish happens on finish, and it is complete.
      await runtime.finish(GenerationFinishReason.eos);
      await _waitUntil(() => !controller.busy);
      expect(controller.job?.responseText, buffer);
      expect(
        store.conversationById(conversation.id)!.messages.last.text,
        buffer,
      );
    });

    test('a partial checkpoint sees text the last paint batch never showed',
        () async {
      final conversation = store.startNew();
      await controller.start(
        conversationId: conversation.id,
        prompt: 'Checkpoint completeness',
        history: const [],
        systemContext: '',
      );
      runtime.emit('Visible ');
      // Well inside the 50 ms paint gap, so nothing has been notified since the
      // first token.
      for (var i = 0; i < 20; i++) {
        runtime.emit('hidden$i ');
      }
      await controller.flushActive();

      expect(
        store.conversationById(conversation.id)!.messages.last.text,
        contains('hidden19'),
        reason: 'a partial checkpoint must not truncate the answer',
      );
      await controller.stop();
    });
  });

  group('message ordering', () {
    test(
      'a finished answer is committed before the next turn can touch the store',
      () async {
        // Hold the encrypted flush open. The store write itself is
        // synchronous, so the answer must already be in the transcript even
        // though the disk write has not started.
        store.gateFlushes();

        final conversation = store.startNew();
        await controller.start(
          conversationId: conversation.id,
          prompt: 'Reply with only the word blue',
          history: const [],
          systemContext: '',
        );
        runtime.emit('blue');
        await runtime.finish(GenerationFinishReason.eos);
        await Future<void>.delayed(const Duration(milliseconds: 5));

        final committed = store.conversationById(conversation.id)!.messages;
        expect(committed.length, 2);
        expect(committed.last.text, 'blue');
        expect(committed.last.status, ConversationMessageStatus.complete);
        expect(
          controller.job?.state,
          ChatGenerationState.complete,
          reason: 'the terminal job must be published before the flush awaits',
        );

        // Everything the shell fires unawaited on navigation, lifecycle pause
        // and disposal, while the flush is still pending. None of them may
        // overwrite or downgrade the answer that is already committed.
        unawaited(controller.flushActive());
        unawaited(controller.stop());
        runtime.emit(' LATE');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final afterRaces = store.conversationById(conversation.id)!.messages;
        expect(afterRaces.length, 2);
        expect(afterRaces.last.text, 'blue');
        expect(afterRaces.last.status, ConversationMessageStatus.complete);

        // The next user turn is refused while the answer is still being
        // committed, so it can never be reordered behind it.
        expect(
          await controller.start(
            conversationId: conversation.id,
            prompt: 'A follow-up',
            history: const [],
            systemContext: '',
          ),
          isNull,
        );

        store.releaseFlushes();
        await _waitUntil(() => !controller.busy);

        final transcript = store.conversationById(conversation.id)!.messages;
        expect(transcript.length, 2);
        expect(transcript[0].text, 'Reply with only the word blue');
        expect(transcript[1].text, 'blue');
        expect(transcript[1].status, ConversationMessageStatus.complete);

        // And the second turn appends after the first answer.
        await controller.start(
          conversationId: conversation.id,
          prompt: 'A follow-up',
          history: const [],
          systemContext: '',
        );
        runtime.emit('green');
        await runtime.finish(GenerationFinishReason.eos);
        await _waitUntil(() => !controller.busy);

        final ordered = store.conversationById(conversation.id)!.messages;
        expect(
          ordered.map((message) => message.text).toList(),
          ['Reply with only the word blue', 'blue', 'A follow-up', 'green'],
        );
      },
    );

    test('a stop during the terminal flush cannot relabel a finished answer',
        () async {
      store.gateFlushes();
      final conversation = store.startNew();
      await controller.start(
        conversationId: conversation.id,
        prompt: 'Short answer',
        history: const [],
        systemContext: '',
      );
      runtime.emit('blue');
      await runtime.finish(GenerationFinishReason.eos);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      unawaited(controller.stop());
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final answer = store.conversationById(conversation.id)!.messages.last;
      expect(answer.text, 'blue');
      expect(answer.status, ConversationMessageStatus.complete);
      expect(answer.finishReason, GenerationFinishReason.eos.name);
      store.releaseFlushes();
      await _waitUntil(() => !controller.busy);
    });

    test('an ordinary stop still lands the partial as stopped', () async {
      final conversation = store.startNew();
      await controller.start(
        conversationId: conversation.id,
        prompt: 'Long answer',
        history: const [],
        systemContext: '',
      );
      runtime.emit('half a th');
      await controller.stop();

      final answer = store.conversationById(conversation.id)!.messages.last;
      expect(answer.text, 'half a th');
      expect(answer.status, ConversationMessageStatus.stopped);
      expect(answer.finishReason, GenerationFinishReason.userCancellation.name);
    });
  });

  group('dispose', () {
    test('stops the native generation and persists the decoded partial',
        () async {
      final conversation = store.startNew();
      await controller.start(
        conversationId: conversation.id,
        prompt: 'Dispose mid-stream',
        history: const [],
        systemContext: '',
      );
      runtime.emit('decoded so far');
      controller.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(runtime.stopRequested, isTrue,
          reason: 'dispose must ask the runtime to stop decoding');
      expect(
        store.conversationById(conversation.id)!.messages.last.text,
        'decoded so far',
      );
    });

    test('never notifies after disposal and counts late tokens', () async {
      final conversation = store.startNew();
      await controller.start(
        conversationId: conversation.id,
        prompt: 'Dispose then keep talking',
        history: const [],
        systemContext: '',
      );
      runtime.emit('Kept');
      var notifications = 0;
      controller.addListener(() => notifications++);
      // The runtime hands over a batch it had already decoded when the stop
      // reached it. It must be counted, never applied.
      runtime.emitDuringStop = ' LATE';

      controller.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final afterDispose = notifications;

      // Anything delivered after that must not throw either, must not be
      // applied, and must not re-notify.
      runtime.emitDuringStop = null;
      runtime.emit(' MORE');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await controller.flushActive();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifications, afterDispose,
          reason: 'a disposed controller must not notifyListeners()');
      expect(controller.lateTokenCount, 1,
          reason: 'a token that lands during the stop is a late token');
      expect(
        store.conversationById(conversation.id)!.messages.last.text,
        'Kept',
      );
    });
  });
}

/// The characters the old per-token path copied: one `toString()` per token,
/// each copying the whole answer as it stood at that moment.
int _cumulativeLengths(List<String> tokens) {
  var total = 0;
  var running = 0;
  for (final token in tokens) {
    running += token.length;
    total += running;
  }
  return total;
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 500 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

/// A [ConversationStore] whose [flush] can be held open, standing in for the
/// real store's key fetch plus off-isolate encryption. The in-memory write is
/// always synchronous; only the disk write is slow.
class _GatedStore extends ConversationStore {
  _GatedStore({required super.keyStorage, required super.directoryProvider});

  final List<Completer<void>> _gates = [];
  bool _gated = false;

  void gateFlushes() => _gated = true;

  void releaseFlushes() {
    _gated = false;
    for (final gate in List<Completer<void>>.from(_gates)) {
      if (!gate.isCompleted) gate.complete();
    }
    _gates.clear();
  }

  @override
  Future<void> flush() {
    if (!_gated) return super.flush();
    final gate = Completer<void>();
    _gates.add(gate);
    return gate.future.then((_) => super.flush());
  }
}

class _StreamRuntime extends ChangeNotifier implements ChatInferenceRuntime {
  StreamController<String>? _stream;
  InferencePhase _phase = InferencePhase.idle;
  GenerationReport? _report;
  bool stopRequested = false;

  /// Delivered synchronously by [stopGeneration], standing in for a decode
  /// batch the runtime had already produced when the cancel reached it.
  String? emitDuringStop;

  @override
  InferencePhase get phase => _phase;
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
    _stream = StreamController<String>(sync: true);
    _phase = InferencePhase.generating;
    notifyListeners();
    return _stream!.stream;
  }

  void emit(String value) {
    final stream = _stream;
    if (stream == null || stream.isClosed) return;
    stream.add(value);
  }

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
    _phase = InferencePhase.idle;
    notifyListeners();
    final stream = _stream;
    if (stream != null && !stream.isClosed) await stream.close();
  }

  @override
  Future<void> stopGeneration() async {
    stopRequested = true;
    final late = emitDuringStop;
    if (late != null) emit(late);
    _phase = InferencePhase.idle;
    notifyListeners();
  }

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
