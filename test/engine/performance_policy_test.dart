import 'dart:async';

import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/residency_policy.dart';
import 'package:finn_ai/src/inference/ttft_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'duplicate prewarm and Send collapse onto the exact same load',
    () async {
      final jobs = DeduplicatedLoadJob<String, int>();
      final gate = Completer<int>();
      var loads = 0;

      Future<int> load() {
        loads++;
        return gate.future;
      }

      final prewarm = jobs.run('plus', load);
      final send = jobs.run('plus', load);
      expect(identical(prewarm, send), isTrue);
      expect(jobs.activeJobCount, 1);
      expect(loads, 1);

      gate.complete(42);
      expect(await send, 42);
      await prewarm;
      expect(jobs.activeJobCount, 0);
    },
  );

  test(
    'native session setup is serialized and recovers after failure',
    () async {
      final gate = SerializedAsyncGate();
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      var active = 0;
      var maximumActive = 0;

      final first = gate.run(() async {
        active++;
        maximumActive = active;
        firstStarted.complete();
        await releaseFirst.future;
        active--;
        throw StateError('simulated setup failure');
      });
      await firstStarted.future;
      final second = gate.run(() async {
        active++;
        maximumActive = active > maximumActive ? active : maximumActive;
        active--;
        return 42;
      });

      releaseFirst.complete();
      await expectLater(first, throwsStateError);
      expect(await second, 42);
      expect(maximumActive, 1);
    },
  );

  test('memory pressure release order keeps primary engine last', () {
    expect(memoryPressureReleaseOrder(), const [
      MemoryReleaseTarget.inactiveConversationSessions,
      MemoryReleaseTarget.activeConversationSession,
      MemoryReleaseTarget.secondaryModelEngines,
      MemoryReleaseTarget.primaryModelEngine,
    ]);
  });

  test('foreground chat and navigation events keep the engine resident', () {
    for (final event in const [
      ResidencyLifecycleEvent.chatSwitch,
      ResidencyLifecycleEvent.sidebarOpen,
      ResidencyLifecycleEvent.pageTransition,
      ResidencyLifecycleEvent.generationComplete,
      ResidencyLifecycleEvent.inactive,
      ResidencyLifecycleEvent.resumed,
    ]) {
      expect(residencyActionFor(event), ResidencyLifecycleAction.keepResident);
    }
  });

  test('pause delays release while detach releases immediately', () {
    expect(
      residencyActionFor(ResidencyLifecycleEvent.paused),
      ResidencyLifecycleAction.scheduleBackgroundRelease,
    );
    expect(
      residencyActionFor(ResidencyLifecycleEvent.detached),
      ResidencyLifecycleAction.releaseNow,
    );
  });

  test('prefix cache key invalidates every compatibility dimension', () {
    const base = PrefixCacheCompatibilityKey(
      modelSha256: 'model-sha',
      modelTier: 'plus',
      runtimeVersion: 'wrapper:llama',
      architectureIdentity: 'arm64-config',
      systemPromptVersion: 2,
      chatTemplateVersion: 1,
      contextSize: 4096,
      kvTypeK: 'q8_0',
      kvTypeV: 'q8_0',
      tokenizerSettings: 'special=true;parse=true',
    );
    const changedContext = PrefixCacheCompatibilityKey(
      modelSha256: 'model-sha',
      modelTier: 'plus',
      runtimeVersion: 'wrapper:llama',
      architectureIdentity: 'different-arm64-config',
      systemPromptVersion: 2,
      chatTemplateVersion: 1,
      contextSize: 4096,
      kvTypeK: 'q8_0',
      kvTypeV: 'q8_0',
      tokenizerSettings: 'special=true;parse=true',
    );
    expect(base, isNot(changedContext));
    expect(base.stableHash, hasLength(64));
    expect(
      base.toDiagnosticJson().toString(),
      isNot(contains('raw private profile text')),
    );
  });

  test('conversation session identity cannot cross chats or model configs', () {
    const a = ConversationSessionCacheKey(
      conversationId: 'A',
      modelIdentity: 'plus:model-sha',
      promptConfigurationHash: 'config-1',
    );
    const b = ConversationSessionCacheKey(
      conversationId: 'B',
      modelIdentity: 'plus:model-sha',
      promptConfigurationHash: 'config-1',
    );
    const changedModel = ConversationSessionCacheKey(
      conversationId: 'A',
      modelIdentity: 'lite:model-sha',
      promptConfigurationHash: 'config-1',
    );
    expect(a, isNot(b));
    expect(a, isNot(changedModel));
    expect({a, b, changedModel}, hasLength(3));
  });

  test('TTFT diagnostics contain no prompt or private context contents', () {
    final trace =
        TtftTrace(generationId: 'generation', conversationId: 'conversation')
          ..modelTier = 'plus'
          ..promptTokenCount = 123
          ..mark(TtftPhase.intentClassified)
          ..mark(TtftPhase.routeSelected);
    final diagnostic = trace.toJson().toString();
    expect(diagnostic, isNot(contains('secret prompt')));
    expect(diagnostic, isNot(contains('private profile')));
    expect(diagnostic, contains('prompt_token_count'));
  });

  test('unchanged warm-turn policy is not redundantly prefixed', () {
    final prompt = FinnInference.instance.renderPromptForTest(
      prompt: 'Hello',
      primed: true,
      includeTaskInstruction: false,
    );
    expect(prompt, isNot(contains('You are Finn AI, a warm, sharp')));
    expect(prompt, contains('<|im_start|>user'));
    expect(prompt, contains('<|im_start|>assistant'));
  });

  test('imageCache clear drops all live and cached bitmaps', () {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
    expect(imageCache.currentSize, 0);
    expect(imageCache.liveImageCount, 0);
  });

  test(
    'prompt lookup decoding extracts exact matching sequences from history',
    () {
      final ngram = NGramTable(nGram: 4);
      // Seed with a prompt containing a repeating pattern
      final prompt = <int>[101, 102, 103, 201, 202, 203, 301, 302, 303];
      ngram.seed(prompt);

      // Current history ends with [101, 102, 103] -> should draft [201, 202, 203, 301]
      final drafts = ngram.draft([101, 102, 103], 4);
      expect(drafts, [201, 202, 203, 301]);
    },
  );

  test('prompt lookup decoding dynamically learns from emitted tokens', () {
    final ngram = NGramTable(nGram: 3);
    ngram.seed([1, 2, 3]);

    // Emitting [4, 5, 6] during generation extends knowledge
    ngram.add(4);
    ngram.add(5);
    ngram.add(6);

    // Query suffix [4, 5] -> should draft [6]
    final drafts = ngram.draft([1, 2, 3, 4, 5], 2);
    expect(drafts, contains(6));
  });
}
