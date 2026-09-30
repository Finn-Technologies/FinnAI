import 'dart:convert';
import 'dart:io';

import 'package:finn_ai/src/engine/eval/eval_baseline.dart';
import 'package:finn_ai/src/engine/eval/eval_prompts.dart';
import 'package:finn_ai/src/engine/eval/harness.dart';
import 'package:finn_ai/src/engine/finn_engine_types.dart';
import 'package:flutter_test/flutter_test.dart';

EvalObservation _observation({
  String caseId = 'factual.capital_france',
  String suite = 'factual',
  int turn = 0,
  bool empty = false,
  bool searched = false,
  String? browseExpected = 'mustNot',
  bool? checksPassed,
  int? ttftMs = 1000,
  double? tokensPerSecond = 16.0,
  int? routingMs = 100,
  int? promptEvalMs = 500,
  String? finishReason,
}) =>
    EvalObservation(
      caseId: caseId,
      suite: suite,
      turn: turn,
      empty: empty,
      searched: searched,
      browseExpected: browseExpected,
      checksPassed: checksPassed,
      ttftMs: ttftMs,
      tokensPerSecond: tokensPerSecond,
      routingMs: routingMs,
      promptEvalMs: promptEvalMs,
      finishReason: finishReason,
    );

void main() {
  group('summarize', () {
    test('an empty run reports nothing rather than zeroes', () {
      final summary = summarize(const []);
      expect(summary.observationCount, 0);
      expect(summary.checkPassRate, isNull);
      expect(summary.browseRecall, isNull);
      expect(summary.ttftP50, isNull);
    });

    test('counts empty, searching and failing turns', () {
      final summary = summarize([
        _observation(checksPassed: true),
        _observation(empty: true, checksPassed: true),
        _observation(searched: true, checksPassed: true),
        _observation(checksPassed: false),
      ]);
      expect(summary.observationCount, 4);
      expect(summary.emptyRate, 0.25);
      expect(summary.searchRate, 0.25);
      expect(summary.checkPassRate, 0.75);
    });

    test('browse precision is over must-not-browse turns only', () {
      final summary = summarize([
        // Two must-not-browse turns, one wrongly browsed.
        _observation(browseExpected: 'mustNot'),
        _observation(browseExpected: 'mustNot', searched: true),
        // A must-browse turn that browsed, and one that did not.
        _observation(browseExpected: 'must', searched: true),
        _observation(browseExpected: 'must'),
        // Unspecified turns are scored by neither.
        _observation(browseExpected: null, searched: true),
      ]);
      expect(summary.browsePrecision, 0.5);
      expect(summary.browseRecall, 0.5);
    });

    test('browse recall is null when no case needed the web', () {
      final summary = summarize([_observation(browseExpected: 'mustNot')]);
      expect(summary.browseRecall, isNull);
    });

    test('percentiles use nearest-rank so they match the in-app harness', () {
      final summary = summarize([
        for (var ms = 100; ms <= 1900; ms += 100)
          _observation(
              ttftMs: ms,
              tokensPerSecond: 0,
              promptEvalMs: null,
              routingMs: null),
      ]);
      // 19 samples: index = ceil(18 * .50) = 9 -> the 10th smallest = 1000.
      expect(summary.ttftP50, 1000);
      // index = ceil(18 * .95) = 18 -> 1900.
      expect(summary.ttftP95, 1900);
    });

    test('breaks the pass rate down per suite', () {
      final summary = summarize([
        _observation(suite: 'factual', checksPassed: true),
        _observation(suite: 'factual', checksPassed: false),
        _observation(suite: 'math', checksPassed: true),
        // Unchecked turns must not appear in any suite.
        _observation(suite: 'factual', checksPassed: null),
      ]);
      expect(summary.bySuite['factual'], 0.5);
      expect(summary.bySuite['math'], 1.0);
      expect(summary.bySuite.containsKey('browse'), isFalse);
    });
  });

  group('compareToBaseline', () {
    test('absolute gates apply with no baseline to compare against', () {
      final comparison = compareToBaseline(
        summarize([
          _observation(),
          _observation(checksPassed: true),
        ]),
        const EvalGates(),
      );
      expect(comparison.results.map((gate) => gate.name), [
        'empty_reply_rate',
        'browse_precision',
      ]);
      expect(comparison.passed, isTrue);
    });

    test('an empty turn fails the empty-reply gate', () {
      final comparison = compareToBaseline(
        summarize([_observation(), _observation(empty: true)]),
        const EvalGates(),
      );
      final gate = comparison.failures.single;
      expect(gate.name, 'empty_reply_rate');
      expect(gate.current, 0.5);
    });

    test('browsing a static fact fails browse precision', () {
      final comparison = compareToBaseline(
        summarize([_observation(searched: true)]),
        const EvalGates(),
      );
      expect(comparison.failures.single.name, 'browse_precision');
    });

    test('a must-browse turn that stayed local fails recall', () {
      final comparison = compareToBaseline(
        summarize([_observation(browseExpected: 'must', searched: false)]),
        const EvalGates(),
      );
      expect(comparison.failures.single.name, 'browse_recall');
    });

    test('TTFT regression past the tolerance fails, within it passes', () {
      final baseline = summarize([_observation(ttftMs: 1000)]);
      final tolerance = const EvalGates(ttftP95Tolerance: 0.25);

      final within = compareToBaseline(
        summarize([_observation(ttftMs: 1200)]),
        tolerance,
        baseline: baseline,
      );
      expect(
        within.results.firstWhere((gate) => gate.name == 'ttft_p95').passed,
        isTrue,
      );

      final beyond = compareToBaseline(
        summarize([_observation(ttftMs: 1300)]),
        tolerance,
        baseline: baseline,
      );
      final gate =
          beyond.failures.firstWhere((gate) => gate.name == 'ttft_p95');
      expect(gate.passed, isFalse);
      expect(gate.baseline, 1000);
      expect(gate.current, 1300);
    });

    test('decode slowdown past the tolerance fails', () {
      final comparison = compareToBaseline(
        summarize([_observation(tokensPerSecond: 8)]),
        const EvalGates(decodeSpeedTolerance: 0.15),
        baseline: summarize([_observation(tokensPerSecond: 16)]),
      );
      final gate =
          comparison.failures.firstWhere((gate) => gate.name == 'decode_speed');
      expect(gate.passed, isFalse);
      expect(gate.current, 8);
    });

    test('relative gates are skipped when the baseline has no such number', () {
      // A baseline recorded before TTFT was instrumented must not read as a
      // pass for a run that is actually slow.
      final comparison = compareToBaseline(
        summarize([_observation(ttftMs: 9000, tokensPerSecond: 1)]),
        const EvalGates(),
        baseline: summarize(const []),
      );
      expect(
        comparison.results.any((gate) => gate.name == 'ttft_p95'),
        isFalse,
      );
    });

    test('a lost check pass rate past the tolerance fails', () {
      final baseline = summarize([
        _observation(checksPassed: true),
        _observation(checksPassed: true),
      ]);
      final comparison = compareToBaseline(
        summarize([_observation(checksPassed: false)]),
        const EvalGates(checkPassRateTolerance: 0.05),
        baseline: baseline,
      );
      expect(
        comparison.failures.map((gate) => gate.name),
        contains('check_pass_rate'),
      );
    });
  });

  group('EvalBaseline', () {
    test('round-trips through JSON without losing a field', () {
      final baseline = EvalBaseline(
        model: 'LFM2.5-VL-1.6B-Q4_0',
        device: 'SD778G/8c/8GiB',
        contextTokens: 4096,
        createdAt: '2026-09-29T22:30:00.000',
        observations: [
          _observation(),
          _observation(
            empty: true,
            searched: true,
            checksPassed: false,
            ttftMs: 6000,
            tokensPerSecond: 12.4,
            finishReason: 'tokenLimit',
          ),
        ],
        gates: const EvalGates(maxEmptyReplyRate: 0.01),
      );
      final decoded = EvalBaseline.decode(baseline.encode());
      expect(decoded.model, baseline.model);
      expect(decoded.device, baseline.device);
      expect(decoded.contextTokens, 4096);
      expect(decoded.gates.maxEmptyReplyRate, 0.01);
      expect(decoded.observations, hasLength(2));
      expect(decoded.observations[1].empty, isTrue);
      expect(decoded.observations[1].searched, isTrue);
      expect(decoded.observations[1].checksPassed, isFalse);
      expect(decoded.observations[1].tokensPerSecond, 12.4);
      expect(
        decoded.observations[1].finishReason,
        baseline.observations[1].finishReason,
      );
    });

    test('rejects an unknown schema instead of guessing', () {
      expect(
        () => EvalBaseline.decode(jsonEncode({'schema': 99})),
        throwsA(isA<FormatException>()),
      );
    });

    test('never writes prompt or answer text into the file', () {
      final baseline = EvalBaseline(
        model: 'm',
        device: 'd',
        contextTokens: 4096,
        createdAt: 'now',
        observations: [_observation(caseId: 'case-1')],
      );
      final encoded = baseline.encode();
      expect(encoded, isNot(contains('Paris')));
      expect(encoded, isNot(contains('capital')));
    });
  });

  group('EvalPromptCatalog', () {
    test('every built-in case has a unique id', () {
      final ids = EvalPromptCatalog.cases.map((entry) => entry.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate case id');
    });

    test('suites cover the plan and each has at least one case', () {
      for (final suite in EvalSuite.values) {
        expect(
          EvalPromptCatalog.forSuites({suite}),
          isNotEmpty,
          reason: 'suite ${suite.name} has no cases',
        );
      }
    });

    test('a deterministic case repeats, and only that one', () {
      final repeats = {
        for (final entry in EvalPromptCatalog.cases)
          if (entry.repeats > 1) entry.suite: entry.repeats,
      };
      expect(repeats.keys, {EvalSuite.determinism});
      expect(repeats[EvalSuite.determinism], greaterThanOrEqualTo(5));
    });

    test('loads cases from a JSON file, including non-Latin prompts', () {
      final file = _writeTemp(
        jsonEncode([
          {
            'id': 'multilingual.kannada',
            'suite': 'multilingual',
            'prompt': 'ನಮಸ್ಕಾರ ಹೇಳಿ.',
            'browse': 'mustNot',
            'checks': [
              {'check': 'word_count', 'min': 1, 'max': 40},
            ],
          },
        ]),
      );
      final cases = EvalPromptCatalog.loadCasesFromFile(file);
      expect(cases, hasLength(1));
      expect(cases.single.suite, EvalSuite.multilingual);
      expect(cases.single.browse, BrowseExpectation.mustNot);
      expect(cases.single.prompt, 'ನಮಸ್ಕಾರ ಹೇಳಿ.');
      expect(cases.single.checks.single.accepts('ನಮಸ್ಕಾರ'), isTrue);
      expect(
        cases.single.checks.single.accepts(List.filled(41, 'word').join(' ')),
        isFalse,
      );
    });

    test('skips malformed entries rather than failing the whole load', () {
      final file = _writeTemp(
        jsonEncode([
          {'id': 'ok', 'suite': 'factual', 'prompt': 'hi'},
          {'suite': 'factual', 'prompt': 'no id'},
          {'id': 'bad', 'suite': 'nope', 'prompt': 'no suite'},
          'not an object',
        ]),
      );
      final cases = EvalPromptCatalog.loadCasesFromFile(file);
      expect(cases.map((entry) => entry.id), ['ok']);
    });

    test('rejects a file that is not a JSON array', () {
      expect(
        () => EvalPromptCatalog.loadCasesFromFile(_writeTemp('{"a": 1}')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AnswerCheck', () {
    test('contains any / all are case-insensitive by default', () {
      expect(AnswerCheck.containsAny(['Paris']).accepts('the answer is paris.'),
          isTrue);
      expect(AnswerCheck.containsAny(['Paris']).accepts('the answer is Lyon.'),
          isFalse);
      expect(AnswerCheck.containsAll(['a', 'b']).accepts('A and B'), isTrue);
      expect(AnswerCheck.containsAll(['a', 'b']).accepts('only a'), isFalse);
    });

    test('caseSensitive is honoured', () {
      expect(
        AnswerCheck.containsAny(['Paris'], caseSensitive: true)
            .accepts('paris'),
        isFalse,
      );
    });

    test('forbids catches the trap', () {
      expect(
          AnswerCheck.forbids('<|im_start|>').accepts('clean answer'), isTrue);
      expect(
        AnswerCheck.forbids('<|im_start|>')
            .accepts('leaked <|im_start|>system'),
        isFalse,
      );
    });

    test('word count ignores runs of whitespace', () {
      final check = AnswerCheck.wordCount(1, 3);
      expect(check.accepts('  one   two \n\n three '), isTrue);
      expect(check.accepts('one two three four'), isFalse);
      expect(check.accepts(''), isFalse);
    });

    test('has lines counts non-empty lines', () {
      expect(AnswerCheck.hasLines(3).accepts('a\nb\nc'), isTrue);
      expect(AnswerCheck.hasLines(3).accepts('a\n\nb\n  \nc'), isTrue);
      expect(AnswerCheck.hasLines(3).accepts('a\nb'), isFalse);
    });

    test('a predicate that throws is a failed check, not a crashed run', () {
      final check = AnswerCheck.satisfies(
        'always explodes',
        (_) => throw StateError('boom'),
      );
      expect(check.accepts('anything'), isFalse);
    });
  });

  group('parseSuites', () {
    test('an empty specification means every suite', () {
      expect(parseSuites(''), Set<EvalSuite>.from(EvalSuite.values));
      expect(parseSuites('   '), Set<EvalSuite>.from(EvalSuite.values));
    });

    test('parses a comma-separated list and tolerates spaces', () {
      expect(parseSuites('factual, math'), {EvalSuite.factual, EvalSuite.math});
    });

    test('an unknown suite fails loudly instead of evaluating nothing', () {
      expect(
        () => parseSuites('factual,not_a_suite'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('EvalHarness', () {
    test('runs a case, scores it, and prints one line per turn', () async {
      final emitted = <String>[];
      final harness = EvalHarness(
        generate: (prompt,
                {required conversationId, required history, trace}) =>
            Stream.value('The capital is Paris.'),
        readEngine: () => const EvalEngineView(searched: false, intent: 'fact'),
        model: 'LFM2.5-VL-1.6B-Q4_0',
        contextTokens: 4096,
        device: 'SD778G/8c/8GiB',
        emit: emitted.add,
      );

      final entry = EvalPromptCatalog.cases
          .firstWhere((entry) => entry.id == 'factual.capital_france');
      final run = await harness.run([entry]);

      expect(run.summary.observationCount, 1);
      expect(run.summary.emptyRate, 0);
      expect(run.summary.checkPassRate, 1.0);
      expect(emitted.where((line) => line.startsWith('FINN_EVAL_CASE ')),
          hasLength(1));
      expect(emitted.singleWhere((l) => l.startsWith('FINN_EVAL_SUMMARY ')),
          contains('check_pass_rate'));
      expect(emitted.singleWhere((l) => l.startsWith('FINN_EVAL_GATE ')),
          contains('"passed":true'));
    });

    test('a follow-up is answered with the history in front of it', () async {
      final seen = <List<LocalChatTurn>>[];
      final harness = EvalHarness(
        generate: (prompt, {required conversationId, required history, trace}) {
          // Snapshot: the harness keeps appending to the same list between
          // turns, so a captured reference would show the final state twice.
          seen.add(List.of(history));
          return Stream.value('3 cartons');
        },
        readEngine: () => const EvalEngineView(searched: false),
        model: 'm',
        contextTokens: 2048,
        device: 'd',
        emit: (_) {},
      );
      final entry = EvalPromptCatalog.cases
          .firstWhere((entry) => entry.id == 'recall.milk_amount');
      await harness.run([entry]);

      expect(seen, hasLength(2));
      expect(seen.first, isEmpty);
      expect(seen.last, hasLength(2));
      expect(seen.last.first.role, 'user');
      expect(seen.last.last.role, 'assistant');
    });

    test('a case with repeats runs that many times', () async {
      var calls = 0;
      final harness = EvalHarness(
        generate: (prompt, {required conversationId, required history, trace}) {
          calls++;
          return Stream.value('Paris');
        },
        readEngine: () => const EvalEngineView(searched: false),
        model: 'm',
        contextTokens: 4096,
        device: 'd',
        emit: (_) {},
      );
      final entry = EvalPromptCatalog.cases
          .firstWhere((entry) => entry.suite == EvalSuite.determinism);
      final run = await harness.run([entry]);
      expect(calls, entry.repeats);
      expect(run.summary.observationCount, entry.repeats);
    });

    test('an engine that emits nothing is recorded as empty, not thrown',
        () async {
      final harness = EvalHarness(
        generate: (prompt,
                {required conversationId, required history, trace}) =>
            const Stream<String>.empty(),
        readEngine: () => const EvalEngineView(searched: false),
        model: 'm',
        contextTokens: 4096,
        device: 'd',
        emit: (_) {},
      );
      final entry = EvalPromptCatalog.cases
          .firstWhere((entry) => entry.id == 'factual.capital_france');
      final run = await harness.run([entry]);
      expect(run.summary.emptyRate, 1.0);
      // An empty turn has no answer to grade, so it is not counted as a
      // failed check: the empty rate is the number that gates it.
      expect(run.summary.checkPassRate, isNull);
    });

    test(
        'a throw mid-stream becomes a failed observation and the run '
        'continues', () async {
      var calls = 0;
      final harness = EvalHarness(
        generate: (prompt, {required conversationId, required history, trace}) {
          calls++;
          if (calls == 1) {
            return Stream<String>.error(StateError('engine died'));
          }
          return Stream.value('Paris');
        },
        readEngine: () => const EvalEngineView(searched: false),
        model: 'm',
        contextTokens: 4096,
        device: 'd',
        emit: (_) {},
      );
      final cases = EvalPromptCatalog.cases
          .where((entry) => entry.suite == EvalSuite.factual)
          .toList();
      final run = await harness.run(cases);
      expect(calls, cases.length);
      expect(run.observations, hasLength(cases.length));
      expect(run.observations.first.finishReason, 'error');
      expect(run.observations.last.empty, isFalse);
    });

    test('a failing check names itself in the observation', () async {
      final harness = EvalHarness(
        generate: (prompt,
                {required conversationId, required history, trace}) =>
            Stream.value('It is Lyon.'),
        readEngine: () => const EvalEngineView(searched: false),
        model: 'm',
        contextTokens: 4096,
        device: 'd',
        emit: (_) {},
      );
      final entry = EvalPromptCatalog.cases
          .firstWhere((entry) => entry.id == 'factual.capital_france');
      final run = await harness.run([entry]);
      final observation = run.observations.single;
      expect(observation.checksPassed, isFalse);
      expect(observation.failedChecks, isNotEmpty);
      expect(
        observation.failedChecks.any(
          (failure) => failure.contains('Paris'),
        ),
        isTrue,
      );
    });
  });
}

/// Writes [contents] to a scratch file that the caller deletes.
File _writeTemp(String contents) {
  final directory = Directory.systemTemp.createTempSync('finn-eval-test');
  addTearDown(() => directory.deleteSync(recursive: true));
  final file = File('${directory.path}/cases.json')
    ..writeAsStringSync(contents);
  return file;
}
