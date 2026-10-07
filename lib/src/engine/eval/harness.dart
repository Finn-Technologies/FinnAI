import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/engine/api/web_source.dart';
import 'package:finn_ai/src/engine/eval/eval_baseline.dart';
import 'package:finn_ai/src/engine/eval/eval_passes.dart';
import 'package:finn_ai/src/engine/eval/eval_prompts.dart';
import 'package:finn_ai/src/engine/finn_accelerator.dart';
import 'package:finn_ai/src/engine/metrics/ttft_metrics.dart';

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

/// What the app's search step produced for one eval turn.
@immutable
class EvalGrounding {
  const EvalGrounding({
    this.groundedContext = '',
    this.sources = const [],
    this.searched = false,
  });

  static const EvalGrounding none = EvalGrounding();

  final String groundedContext;
  final List<WebSource> sources;
  final bool searched;
}

/// Runs the app's search decision for an eval prompt. Injected so `engine/`
/// does not depend on `features/`.
typedef EvalGrounder = Future<EvalGrounding> Function(
  String prompt,
  List<LocalChatTurn> history, {
  required bool hasAttachment,
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
    this.imageBytes,
    this.seedTurn,
  });

  /// Pins the sampler seed for the next turn ([evalTurnSeed]); null leaves the
  /// engine's random seed. The device run wires it to
  /// `FinnAccelerator.debugFixedSeed`.
  final void Function(int seed)? seedTurn;

  /// The image an [EvalCase.withImage] turn carries.
  final Uint8List? imageBytes;

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
    int passes = 1,
  }) async {
    final perPass = <List<EvalObservation>>[];
    final startedAt = clock().toIso8601String();

    emit('FINN_EVAL_START ${jsonEncode({
          'model': model,
          'device': device,
          'context_tokens': contextTokens,
          'cases': cases.length,
          'passes': passes,
          'baseline': baseline == null
              ? null
              : '${baseline.model} on ${baseline.device} '
                  '@${baseline.contextTokens}',
        })}');

    for (var pass = 0; pass < passes; pass++) {
      final observations = <EvalObservation>[];
      perPass.add(observations);
      for (final entry in cases) {
        for (var repeat = 0; repeat < entry.repeats; repeat++) {
          void seed(int turn) => seedTurn?.call(evalTurnSeed(
                caseId: entry.id,
                turn: turn,
                repeat: repeat,
                pass: pass,
              ));
          final history = <LocalChatTurn>[];
          seed(0);
          final first = await _runTurn(
            caseId: entry.id,
            suite: entry.suite.name,
            prompt: entry.prompt,
            history: history,
            browse: entry.browse,
            checks: entry.checks,
            withImage: entry.withImage,
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
            seed(followUpIndex + 1);
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
    }
    final observations = collapsePasses(perPass);

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
      try {
        final file = File(writeBaselineTo);
        await file.parent.create(recursive: true);
        await file.writeAsString(run.toBaseline(gates: gates).encode());
        emit('FINN_EVAL_BASELINE_WRITTEN ${file.path}');
      } catch (error) {
        // A failed write must be loud: the numbers above are the run, and a
        // silent failure here once cost a whole baseline.
        emit('FINN_EVAL_BASELINE_FAILED $writeBaselineTo $error');
      }
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
    bool withImage = false,
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
        // An image turn reaches the engine as the app sends it: the newest
        // history entry is the user's turn, with the picture attached.
        history: withImage && imageBytes != null
            ? [
                ...history,
                LocalChatTurn(
                  role: 'user',
                  content: prompt,
                  imagePath: 'eval-image.png',
                  imageBytes: imageBytes,
                ),
              ]
            : history,
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
