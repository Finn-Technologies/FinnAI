import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/engine/eval/eval_baseline.dart';
import 'package:finn_ai/src/engine/eval/eval_prompts.dart';
import 'package:finn_ai/src/engine/eval/evaluation.dart';
import 'package:finn_ai/src/engine/finn_accelerator.dart';
import 'package:finn_ai/src/engine/metrics/ttft_metrics.dart';
import 'package:finn_ai/src/engine/profiler/device_profile.dart';
import 'package:finn_ai/src/engine/prompt/prompt_intent.dart';

/// Streams one answer. Matches `FinnAccelerator.generateReply` without
/// naming it, so the harness can be unit-tested against a fake and so the
/// evaluator does not have to be rebuilt when the engine signature grows a
/// parameter.
typedef EvalGeneration = Stream<String> Function(
  String prompt, {
  required String conversationId,
  required List<LocalChatTurn> history,
  TtftTrace? trace,
});

/// The bits of the engine the harness reads back after a turn.
@immutable
class EvalEngineView {
  const EvalEngineView({
    required this.searched,
    this.intent,
    this.route,
    this.finishReason,
    this.outputTokens,
    this.tokensPerSecond,
  });

  final bool searched;
  final String? intent;
  final String? route;
  final String? finishReason;
  final int? outputTokens;
  final double? tokensPerSecond;

  static const EvalEngineView none = EvalEngineView(searched: false);
}

/// One harness run: every observation plus the identity of what produced it.
@immutable
class EvalRun {
  const EvalRun({
    required this.observations,
    required this.model,
    required this.contextTokens,
    required this.device,
    required this.startedAt,
  });

  final List<EvalObservation> observations;
  final String model;
  final int contextTokens;
  final String device;
  final String startedAt;

  EvalSummary get summary => summarize(observations);

  EvalBaseline toBaseline({EvalGates gates = const EvalGates()}) =>
      EvalBaseline(
        model: model,
        device: device,
        contextTokens: contextTokens,
        createdAt: startedAt,
        observations: observations,
        gates: gates,
      );
}

/// Runs the evaluation catalog on a real device and prints one JSON line per
/// turn so `adb logcat` can be turned into a committed baseline.
///
/// The harness lives here rather than in `main.dart` so the production entry
/// point keeps no benchmark code, and so the aggregation and gating above can
/// be tested on the host with no device attached.
class EvalHarness {
  EvalHarness({
    required this.generate,
    required this.readEngine,
    required this.model,
    required this.contextTokens,
    required this.device,
    this.emit = _debugEmit,
    this.clock = DateTime.now,
  });

  /// Produces the answer for one turn.
  final EvalGeneration generate;

  /// Reads the engine's per-turn telemetry back. Called immediately after the
  /// stream closes, before the next turn starts.
  final EvalEngineView Function() readEngine;

  final String model;
  final int contextTokens;
  final String device;

  /// Sink for the machine-readable lines. Injectable so tests capture them.
  final void Function(String line) emit;

  final DateTime Function() clock;

  Future<EvalRun> run(
    List<EvalCase> cases, {
    EvalGates gates = const EvalGates(),
    EvalBaseline? baseline,
    String? writeBaselineTo,
  }) async {
    final observations = <EvalObservation>[];
    final startedAt = clock().toIso8601String();

    emit('FINN_EVAL_START ${jsonEncode({
          'model': model,
          'device': device,
          'context_tokens': contextTokens,
          'cases': cases.length,
          'baseline': baseline == null
              ? null
              : '${baseline.model} on ${baseline.device} '
                  '@${baseline.contextTokens}',
        })}');

    for (final entry in cases) {
      for (var repeat = 0; repeat < entry.repeats; repeat++) {
        final history = <LocalChatTurn>[];
        final first = await _runTurn(
          caseId: entry.id,
          suite: entry.suite.name,
          prompt: entry.prompt,
          history: history,
          browse: entry.browse,
          checks: entry.checks,
        );
        observations.add(first.observation);

        for (var followUpIndex = 0;
            followUpIndex < entry.followUps.length;
            followUpIndex++) {
          // The follow-up shares the conversation, and the history carries the
          // real answer: "what did I ask first?" must be answerable from the
          // transcript, which is the whole point of these cases.
          history
            ..add(LocalChatTurn(role: 'user', content: entry.prompt))
            ..add(LocalChatTurn(role: 'assistant', content: first.answer));
          final followUp = await _runTurn(
            caseId: entry.id,
            suite: entry.suite.name,
            prompt: entry.followUps[followUpIndex],
            history: history,
            browse: entry.browse,
            turn: followUpIndex + 1,
            // The last follow-up carries the parent case's checks: that is
            // the turn whose answer has to come out of the history.
            checks: followUpIndex == entry.followUps.length - 1
                ? entry.checks
                : const [],
          );
          observations.add(followUp.observation);
        }
      }
    }

    final run = EvalRun(
      observations: observations,
      model: model,
      contextTokens: contextTokens,
      device: device,
      startedAt: startedAt,
    );

    for (final observation in observations) {
      emit('FINN_EVAL_CASE ${jsonEncode(observation.toJson())}');
    }
    emit('FINN_EVAL_SUMMARY ${jsonEncode(run.summary.toJson())}');

    final comparison = compareToBaseline(
      run.summary,
      gates,
      baseline: baseline?.summary,
    );
    emit('FINN_EVAL_GATE ${jsonEncode(comparison.toJson())}');

    if (writeBaselineTo != null) {
      final file = File(writeBaselineTo);
      await file.parent.create(recursive: true);
      await file.writeAsString(run.toBaseline(gates: gates).encode());
      emit('FINN_EVAL_BASELINE_WRITTEN ${file.path}');
    }
    return run;
  }

  Future<_TurnResult> _runTurn({
    required String caseId,
    required String suite,
    required String prompt,
    required List<LocalChatTurn> history,
    required BrowseExpectation browse,
    int turn = 0,
    List<AnswerCheck> checks = const [],
  }) async {
    final trace = TtftTrace(
      generationId: 'eval-$caseId-$turn',
      conversationId: 'eval-$caseId',
    );
    final answer = StringBuffer();
    var firstToken = false;
    Object? failure;
    try {
      await for (final token in generate(
        prompt,
        conversationId: 'eval-$caseId',
        history: history,
        trace: trace,
      )) {
        if (!firstToken && token.isNotEmpty) {
          firstToken = true;
          trace
            ..mark(TtftPhase.uiPaintScheduled)
            ..mark(TtftPhase.uiPaintCompleted);
        }
        answer.write(token);
      }
    } catch (error) {
      // A crashed turn is an observation, not a crashed run: losing the rest
      // of the suite because one prompt threw would hide exactly the bug
      // worth seeing.
      failure = error;
    }
    // The engine reports the trace itself as part of the turn; the harness
    // only reads it back, so forcing a second report here would double every
    // line in the log and drown the eval output.
    final metrics = trace.toJson();
    final view = readEngine();
    final text = answer.toString().trim();
    final failed = <String>[];
    if (failure == null && text.isNotEmpty) {
      for (final check in checks) {
        if (!check.accepts(text)) failed.add(check.description);
      }
    }

    return _TurnResult(
      answer: text,
      observation: EvalObservation(
        caseId: caseId,
        suite: suite,
        turn: turn,
        empty: text.isEmpty,
        intent: view.intent,
        route: view.route,
        searched: view.searched,
        browseExpected:
            browse == BrowseExpectation.unspecified ? null : browse.name,
        outputTokens: view.outputTokens,
        tokensPerSecond: view.tokensPerSecond,
        ttftMs: metrics['total_ttft_ms'] as int?,
        routingMs: metrics['routing_ms'] as int?,
        promptEvalMs: metrics['prompt_eval_ms'] as int?,
        sessionCacheHit: metrics['conversation_session_cache_hit'] as bool?,
        finishReason: view.finishReason ?? (failure == null ? null : 'error'),
        checksPassed: checks.isEmpty || failure != null || text.isEmpty
            ? null
            : failed.isEmpty,
        failedChecks: failed,
      ),
    );
  }
}

class _TurnResult {
  const _TurnResult({required this.answer, required this.observation});

  final String answer;
  final EvalObservation observation;
}

void _debugEmit(String line) => debugPrint(line);

/// Resolves the suite selection for a run from a comma-separated list.
///
/// An unknown name is a hard error: silently evaluating nothing and calling it
/// a pass is how a quality gate stops meaning anything.
Set<EvalSuite> parseSuites(String specification) {
  if (specification.trim().isEmpty) {
    return Set<EvalSuite>.from(EvalSuite.values);
  }
  final selected = <EvalSuite>{};
  for (final raw in specification.split(',')) {
    final name = raw.trim();
    if (name.isEmpty) continue;
    final suite = EvalSuite.values.where((s) => s.name == name);
    if (suite.isEmpty) {
      throw FormatException(
        'unknown eval suite "$name"; known: '
        '${EvalSuite.values.map((s) => s.name).join(', ')}',
      );
    }
    selected.add(suite.first);
  }
  return selected;
}

/// Entry point for the on-device quality run, driven by dart-defines and
/// driven from `tool/run_eval.sh`.
///
/// Deductions, in order of precedence:
/// - `FINN_EVAL_SUITES` selects suites (default: all).
/// - `FINN_EVAL_PROMPT_FILE` adds cases from a JSON file on the device, which
///   is the only way to run non-Latin prompts today.
/// - `FINN_EVAL_BASELINE` names a committed baseline to gate against.
/// - `FINN_EVAL_WRITE_BASELINE` writes the run out as a new baseline.
/// - `FINN_EVAL_MAX_CASES` caps the run, for a quick smoke pass.
Future<void> runEvalHarness() async {
  const suiteSpec = String.fromEnvironment('FINN_EVAL_SUITES');
  const promptFile = String.fromEnvironment('FINN_EVAL_PROMPT_FILE');
  const baselinePath = String.fromEnvironment('FINN_EVAL_BASELINE');
  const writeBaseline = String.fromEnvironment('FINN_EVAL_WRITE_BASELINE');
  const maxCases = int.fromEnvironment('FINN_EVAL_MAX_CASES', defaultValue: 0);

  final Set<EvalSuite> suites;
  try {
    suites = parseSuites(suiteSpec);
  } on FormatException catch (error) {
    // ignore: avoid_print
    print('FINN_EVAL_ERROR ${error.message}');
    return;
  }

  var cases = EvalPromptCatalog.forSuites(suites);
  if (promptFile.trim().isNotEmpty) {
    final file = File(promptFile);
    if (!file.existsSync()) {
      // ignore: avoid_print
      print('FINN_EVAL_ERROR prompt file not found: $promptFile');
      return;
    }
    try {
      cases = [...cases, ...EvalPromptCatalog.loadCasesFromFile(file)];
    } catch (error) {
      // ignore: avoid_print
      print('FINN_EVAL_ERROR prompt file rejected: $error');
      return;
    }
  }
  if (maxCases > 0 && cases.length > maxCases) {
    cases = cases.take(maxCases).toList(growable: false);
  }

  EvalBaseline? baseline;
  if (baselinePath.trim().isNotEmpty) {
    final file = File(baselinePath);
    if (file.existsSync()) {
      try {
        baseline = EvalBaseline.decode(file.readAsStringSync());
      } catch (error) {
        // ignore: avoid_print
        print('FINN_EVAL_ERROR baseline rejected: $error');
      }
    }
  }

  final engine = FinnAccelerator.instance;
  final profile = await DeviceProfiler.read();
  // Warm the model first so the cold load lands outside the measured turns
  // instead of being charged to whichever case happens to run first. A device
  // that has not downloaded the model yet simply reports the cold number.
  try {
    await engine.prewarm();
  } catch (error) {
    // ignore: avoid_print
    print('FINN_EVAL_WARN prewarm failed, first turn carries the load: $error');
  }
  final harness = EvalHarness(
    generate: (
      prompt, {
      required conversationId,
      required history,
      trace,
    }) =>
        engine.generateReply(
      prompt,
      conversationId: conversationId,
      history: history,
      trace: trace,
    ),
    readEngine: () {
      final report = engine.lastGenerationReport;
      return EvalEngineView(
        searched: engine.searchRanForCurrentTurn,
        intent: report?.intent.toString(),
        route: report?.route.name,
        finishReason: report?.finishReason.name,
        outputTokens: report?.outputTokens,
        tokensPerSecond: report?.tokensPerSecond,
      );
    },
    model: engine.lastGeneratingModel.name,
    contextTokens: engine.contextSize,
    device: '${profile.soc.isEmpty ? 'unknown-soc' : profile.soc}/'
        '${profile.cores}c/${(profile.totalRamBytes ?? 0) ~/ (1 << 30)}GiB',
  );
  await harness.run(
    cases,
    gates: baseline?.gates ?? const EvalGates(),
    baseline: baseline,
    writeBaselineTo: writeBaseline.trim().isEmpty ? null : writeBaseline.trim(),
  );
  await engine.releaseMemory();
}

/// The original candidate-model comparison kept from the pre-Phase-0 harness:
/// runs a fixed multilingual seed set against semicolon-delimited
/// `label=absolute/path/to/model.gguf` entries from `FINN_EVAL_MODELS`.
///
/// This is the one place a non-shipped GGUF can be measured. It never touches
/// the download catalog, and release builds refuse to load an unverified file.
Future<void> runCandidateModelEvaluation() async {
  const specification = String.fromEnvironment('FINN_EVAL_MODELS');
  if (specification.trim().isEmpty) {
    // ignore: avoid_print
    print('FINN_EVAL_ERROR FINN_EVAL_MODELS is empty');
    return;
  }
  const prompts = [
    'Come fare una torta salata con zucchine per 3 persone?',
    'Come fare una torta di mele?',
    'Come preparare una pizza margherita?',
    'Spiegami come cambiare una lampadina.',
    'Confronta iPhone 14 e Redmi Note 12.',
    'Translate this sentence into Italian: The train leaves at six.',
    'How can I upgrade the RAM in my laptop?',
    'How does the routing in Bridgetown work?',
    'How do living ants know that an ant has died?',
    'Come fare una torta di ricotta e fragole?',
  ];
  const caseSelection = String.fromEnvironment('FINN_EVAL_CASES');
  final selectedCases = caseSelection.trim().isEmpty
      ? List<int>.generate(prompts.length, (index) => index)
      : caseSelection
          .split(',')
          .map((value) => int.tryParse(value.trim()))
          .whereType<int>()
          .where((index) => index >= 0 && index < prompts.length)
          .toSet()
          .toList(growable: false);
  final engine = FinnAccelerator.instance;
  for (final entry in specification.split(';')) {
    final separator = entry.indexOf('=');
    if (separator <= 0) continue;
    final label = entry.substring(0, separator).trim();
    final path = entry.substring(separator + 1).trim();
    for (final index in selectedCases) {
      final prompt = prompts[index];
      final answer = StringBuffer();
      await for (final token in engine.generateEvaluationReply(
        prompt,
        path: path,
        modelLabel: label,
        tier: FinnModelTier.standard,
        conversationId: 'eval-$label-$index',
      )) {
        answer.write(token);
      }
      final analysis = const PromptIntentClassifier().classify(prompt);
      final report = engine.lastGenerationReport;
      final response = answer.toString();
      debugPrint(
        'FINN_EVAL ${jsonEncode({
              'selectedModel': label,
              'intent': analysis.intent.name,
              'route': report?.route.name,
              'outputBudget': report?.outputBudget,
              'finishReason': report?.finishReason.name,
              'firstTokenLatencyMs': report?.firstTokenLatency?.inMilliseconds,
              'totalGenerationTimeMs':
                  report?.totalGenerationTime.inMilliseconds,
              'outputTokens': report?.outputTokens,
              'tokensPerSecond': report?.tokensPerSecond,
              if (prompt == 'Come fare una torta di ricotta e fragole?')
                'recipeAcceptance':
                    assessRicottaStrawberryCake(response).toJson(),
              if (prompt == 'How can I upgrade the RAM in my laptop?')
                'hardwareAcceptance':
                    assessLaptopRamGuidance(response).toJson(),
              if (prompt == 'How does the routing in Bridgetown work?')
                'bridgetownAcceptance':
                    assessBridgetownRouting(response).toJson(),
              if (prompt == 'How do living ants know that an ant has died?')
                'antNecrophoresisAcceptance':
                    assessAntNecrophoresis(response).toJson(),
              'response': response
            })}',
      );
    }
    await engine.releaseMemory();
  }
}
