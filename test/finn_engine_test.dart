import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'package:finn_ai/src/engine/finn_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FinnEngine Architecture Tests', () {
    test('FinnEngine singleton is accessible', () {
      final engine = FinnAccelerator.instance;
      expect(engine, isNotNull);
      expect(engine.selected, isNotNull);
      expect(engine.selected.name, contains('LFM2.5-VL'));
    });

    test('FinnEngineConfig supports TurboQuant and compact KV types', () {
      const config = FinnEngineConfig(
        contextSize: 2048,
        threads: 2,
        batchThreads: 4,
        batchSize: 128,
        microBatchSize: 64,
        kvCacheType: FinnKvCacheType.turboQuant2Bit,
        flashAttention: false,
      );

      expect(config.contextSize, 2048);
      expect(config.threads, 2);
      expect(config.batchThreads, 4);
      expect(config.kvCacheType, FinnKvCacheType.turboQuant2Bit);
      expect(config.flashAttention, isFalse);

      final upgraded = config.copyWith(
        kvCacheType: FinnKvCacheType.compactQ8,
        threads: 4,
      );
      expect(upgraded.kvCacheType, FinnKvCacheType.compactQ8);
      expect(upgraded.threads, 4);
      expect(upgraded.contextSize, 2048);
    });

    test('FinnEngine types and finish reasons map properly', () {
      expect(
        finishReasonFromStopReason(const StopEog()),
        GenerationFinishReason.eos,
      );
      expect(
        finishReasonFromStopReason(const StopMaxTokens()),
        GenerationFinishReason.tokenLimit,
      );
      expect(
        finishReasonFromStopReason(const StopUserAbort()),
        GenerationFinishReason.userCancellation,
      );
    });

    test(
      'FinnAccelerator aliases FinnEngine and FinnInference identically',
      () {
        final accelerator = FinnAccelerator.instance;
        final engine = FinnAccelerator.instance;
        final inference = FinnInference.instance;

        expect(identical(accelerator, engine), isTrue);
        expect(identical(engine, inference), isTrue);
        expect(accelerator.selected.name, contains('LFM2.5-VL'));
      },
    );

    test(
      'PromptFormatter properly detects recipe content and formats safety prefix',
      () {
        expect(
          PromptFormatter.isRecipeAnswer(
            'Ingredienti:\n- 200g farina\n- 2 uova',
          ),
          isTrue,
        );
        expect(
          PromptFormatter.isRecipeAnswer(
            'Here is a brief overview of Roman history.',
          ),
          isFalse,
        );
        expect(PromptFormatter.baseSystemPrefix, contains('Finn AI'));
      },
    );

    test('status exposes a machine-readable key alongside the text', () {
      final engine = FinnAccelerator.instance;
      addTearDown(engine.resetDownloadStateForTest);

      expect(engine.status, 'Ready');
      expect(engine.statusKey, FinnStatusKey.ready);

      engine.reportDownloadProgressForTest(0.25, 1000);
      expect(engine.status, 'Downloading test');
      expect(engine.statusKey, FinnStatusKey.downloadingModel);
      expect(engine.downloadProgress, 0.25);

      engine.resetDownloadStateForTest();
      expect(engine.status, 'Ready');
      expect(engine.statusKey, FinnStatusKey.ready);
    });
  });

  group('ReplyTurnGate (queued generations)', () {
    test('busy engine queues callers and runs them FIFO', () async {
      final gate = ReplyTurnGate(capacity: 2);

      // Two callers arrive while the engine is busy: both queue in order.
      final first = gate.waitTurn();
      final second = gate.waitTurn();
      expect(gate.waitingCount, 2);

      var firstRan = false;
      var secondRan = false;
      unawaited(first.then((_) => firstRan = true));
      unawaited(second.then((_) => secondRan = true));
      await Future<void>.delayed(Duration.zero);
      expect(firstRan, isFalse, reason: 'engine is still busy');

      // Chat generation finishes: the oldest queued caller runs first.
      gate.signalNext();
      await first;
      expect(firstRan, isTrue);
      expect(secondRan, isFalse);

      gate.signalNext();
      await second;
      expect(secondRan, isTrue);
      expect(gate.waitingCount, 0);
    });

    test('overflow beyond the bound fails fast and keeps the queue intact', () {
      final gate = ReplyTurnGate(capacity: 2);
      unawaited(gate.waitTurn());
      unawaited(gate.waitTurn());

      expect(
        () => gate.waitTurn(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('queued generations'),
          ),
        ),
      );
      expect(gate.waitingCount, 2, reason: 'rejected caller holds no slot');
    });

    test('abandoned reservations restore capacity and release others',
        () async {
      final gate = ReplyTurnGate(capacity: 2);
      final first = gate.waitTurn();
      final second = gate.waitTurn();

      // The first caller is cancelled while waiting for the engine.
      gate.abandon(first);
      expect(gate.waitingCount, 1);

      // Capacity restored: a new caller can still queue.
      final third = gate.waitTurn();
      expect(gate.waitingCount, 2);

      // Only live waiters get their turn.
      gate.signalNext();
      await second;
      gate.abandon(first);
      gate.abandon(second);
      gate.signalNext();
      await third;
      expect(gate.waitingCount, 0);
    });

    test('signalling an empty queue is a no-op', () {
      final gate = ReplyTurnGate();
      expect(gate.waitingCount, 0);
      gate.signalNext();
      expect(gate.waitingCount, 0);
    });

    test('accelerator queue is bounded at two pending creations', () {
      expect(FinnAccelerator.maxQueuedReplyRequests, 2);
      expect(FinnAccelerator.instance.replyGate.capacity, 2);
    });
  });
}
