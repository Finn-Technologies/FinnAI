import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/engine/eval/eval_baseline.dart';
import 'package:finn_ai/src/engine/eval/eval_passes.dart';
import 'package:finn_ai/src/engine/eval/eval_prompts.dart';
import 'package:finn_ai/src/engine/eval/harness.dart';

EvalObservation _obs(
  String id, {
  int ttft = 1000,
  bool? passed = true,
  List<String> failed = const [],
}) =>
    EvalObservation(
      caseId: id,
      suite: 'factual',
      turn: 0,
      empty: false,
      ttftMs: ttft,
      tokensPerSecond: ttft / 100,
      checksPassed: passed,
      failedChecks: failed,
    );

/// The eval has to give the same build the same score: fixed seeds per turn,
/// and a median across whole passes.
void main() {
  group('evalTurnSeed', () {
    test('is stable for the same turn', () {
      int seed() => evalTurnSeed(caseId: 'a', turn: 0, repeat: 0, pass: 0);
      expect(seed(), seed());
      expect(seed(), inInclusiveRange(0, 0x7fffffff));
    });

    test('differs by case, follow-up, repeat and pass', () {
      final seeds = {
        evalTurnSeed(caseId: 'a', turn: 0, repeat: 0, pass: 0),
        evalTurnSeed(caseId: 'b', turn: 0, repeat: 0, pass: 0),
        evalTurnSeed(caseId: 'a', turn: 1, repeat: 0, pass: 0),
        evalTurnSeed(caseId: 'a', turn: 0, repeat: 1, pass: 0),
        evalTurnSeed(caseId: 'a', turn: 0, repeat: 0, pass: 1),
      };
      expect(seeds, hasLength(5));
    });
  });

  group('collapsePasses', () {
    test('one pass passes straight through', () {
      final pass = [_obs('a'), _obs('b')];
      expect(collapsePasses([pass]), same(pass));
    });

    test('takes the median of numbers and the majority of checks', () {
      final collapsed = collapsePasses([
        [_obs('a', ttft: 900, passed: true)],
        [
          _obs('a', ttft: 5000, passed: false, failed: const ['short'])
        ],
        [_obs('a', ttft: 1100, passed: true)],
      ]).single;
      expect(collapsed.ttftMs, 1100);
      expect(collapsed.checksPassed, isTrue);
      expect(collapsed.failedChecks, ['short']);
    });

    test('a tie is a failure', () {
      final collapsed = collapsePasses([
        [_obs('a', passed: true)],
        [_obs('a', passed: false)],
      ]).single;
      expect(collapsed.checksPassed, isFalse);
    });

    test('repeats inside a pass stay separate observations', () {
      // The determinism suite asks the same thing five times on purpose;
      // collapsing by case id would turn five samples into one.
      final pass = [_obs('d'), _obs('d'), _obs('d')];
      expect(collapsePasses([pass, pass, pass]), hasLength(3));
    });

    test('passes of different lengths are refused', () {
      expect(
        () => collapsePasses([
          [_obs('a')],
          [_obs('a'), _obs('b')],
        ]),
        throwsStateError,
      );
    });
  });

  test('the harness seeds every turn and folds its passes', () async {
    final seeds = <int>[];
    final harness = EvalHarness(
      generate: (prompt, {required conversationId, required history, trace}) =>
          Stream.value('3 cartons'),
      readEngine: () => const EvalEngineView(searched: false),
      model: 'm',
      contextTokens: 2048,
      device: 'd',
      emit: (_) {},
      seedTurn: seeds.add,
    );
    final entry = EvalPromptCatalog.cases
        .firstWhere((entry) => entry.id == 'recall.milk_amount');
    final run = await harness.run([entry], passes: 3);

    // Two turns (the ask and its follow-up), three passes.
    expect(seeds, hasLength(6));
    expect(seeds.toSet(), hasLength(6));
    expect(run.observations, hasLength(2));
    expect(
      seeds.first,
      evalTurnSeed(caseId: entry.id, turn: 0, repeat: 0, pass: 0),
    );
  });
}
