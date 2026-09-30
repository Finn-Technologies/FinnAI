import 'package:finn_ai/src/engine/metrics/perf_logging.dart';
import 'package:finn_ai/src/engine/metrics/ttft_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(PerfLogSampler.reset);

  group('PerfLogSampler', () {
    test('a debug build keeps every turn', () {
      for (var turn = 0; turn < 50; turn++) {
        expect(
          PerfLogSampler.sampleFor(release: false),
          isTrue,
          reason: 'turn $turn',
        );
      }
      // The counter only advances for sampled runs, so a debug build never
      // accrues state it does not use.
      expect(PerfLogSampler.seenTurns, 0);
    });

    test('a release build keeps the first turn so a session has a data point',
        () {
      expect(PerfLogSampler.sampleFor(release: true), isTrue);
      expect(PerfLogSampler.seenTurns, 1);
    });

    test('a release build samples on a fixed stride, not every turn', () {
      final kept = <bool>[
        for (var turn = 0; turn < PerfLogSampler.releaseSampleEvery; turn++)
          PerfLogSampler.sampleFor(release: true),
      ];
      expect(kept.first, isTrue, reason: 'the leading turn is always kept');
      expect(kept.last, isTrue, reason: 'the stride lands on a multiple');
      expect(
        kept.where((sample) => sample).length,
        2,
        reason: 'exactly one sample per stride',
      );
    });

    test('a long session samples about one turn in eight', () {
      final turns = 800;
      final kept = List.generate(
        turns,
        (_) => PerfLogSampler.sampleFor(release: true),
      ).where((sample) => sample).length;
      expect(kept, turns ~/ PerfLogSampler.releaseSampleEvery + 1);
    });

    test('every sampled payload stays free of prompt and answer text', () {
      // The reason the gate may be open in release at all (PLAN.md §9.1) is
      // that nothing behind it carries user content. TtftTrace.toJson is the
      // widest payload the sampler gates, so assert against it directly.
      final trace = TtftTrace(
        generationId: 'generation-1',
        conversationId: 'conversation-1',
      )
        ..modelTier = 'standard'
        ..mark(TtftPhase.uiPaintScheduled);
      final json = trace.toJson().values.map((value) => '$value').join(' ');

      expect(json, isNot(contains('system')));
      expect(json, isNot(contains('instruction')));
      expect(json, isNot(contains('search the web')));
    });
  });

  group('TtftTrace', () {
    test('reports total TTFT as time to the first scheduled paint', () {
      final trace = TtftTrace(generationId: 'g', conversationId: 'c')
        ..mark(TtftPhase.uiPaintScheduled);

      final json = trace.toJson();
      expect(json['total_ttft_ms'], isA<int>());
      expect(json['routing_ms'], isNull, reason: 'route was never marked');
    });

    test('uses the completed-paint time once the UI reports back', () {
      final trace = TtftTrace(generationId: 'g', conversationId: 'c')
        ..mark(TtftPhase.uiPaintScheduled)
        ..mark(TtftPhase.uiPaintCompleted);
      expect(trace.hasUiPaintCompleted, isTrue);
      expect(trace.toJson()['total_ttft_ms'], isA<int>());
    });

    test('never reports twice for one generation', () {
      // The engine and the UI both call report(); it has to be idempotent or
      // every turn logs twice.
      final trace = TtftTrace(generationId: 'g', conversationId: 'c')
        ..mark(TtftPhase.uiPaintScheduled);
      trace
        ..report()
        ..report()
        ..report(force: true);
    });

    test('stays quiet when no paint was ever scheduled', () {
      final trace = TtftTrace(generationId: 'g', conversationId: 'c');
      expect(trace.hasUiPaintScheduled, isFalse);
      trace.report();
    });

    test('keeps the first mark of a phase and ignores later ones', () {
      final trace = TtftTrace(generationId: 'g', conversationId: 'c');
      trace
        ..mark(TtftPhase.routeSelected)
        ..mark(TtftPhase.routeSelected);
      // Marking twice must not push the recorded phase to a later time, or a
      // repeated mark would silently shorten the measured route.
      expect(trace.toJson()['routing_ms'], 0);
    });

    test('leaves every phase null until something marks it', () {
      final json = TtftTrace(generationId: 'g', conversationId: 'c').toJson();
      for (final key in [
        'total_ttft_ms',
        'routing_ms',
        'model_load_ms',
        'session_prepare_ms',
        'prompt_build_ms',
        'prompt_eval_ms',
        'sanitization_ms',
        'ui_delivery_ms',
      ]) {
        expect(json[key], isNull, reason: '$key should be unmeasured');
      }
    });

    test('is prompt-free by construction', () {
      final trace = TtftTrace(generationId: 'g', conversationId: 'c')
        ..promptTokenCount = 1234;
      final json = trace.toJson();
      expect(json['prompt_token_count'], 1234);
      expect(json.keys, isNot(contains('prompt_text')));
    });
  });
}
