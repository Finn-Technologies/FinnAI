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
  });
}
