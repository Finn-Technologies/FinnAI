import 'dart:convert';

import 'package:flutter/foundation.dart';

/// What one generated turn measured.
///
/// Deliberately carries no prompt or answer text: baselines are committed to
/// the repository, so they must not become a store of what users typed. The
/// answer text is reduced to booleans ([empty], [checksPassed]) and counts at
/// the point the observation is built.
@immutable
class EvalObservation {
  const EvalObservation({
    required this.caseId,
    required this.suite,
    required this.turn,
    required this.empty,
    this.intent,
    this.route,
    this.searched = false,
    this.browseExpected,
    this.outputTokens,
    this.tokensPerSecond,
    this.ttftMs,
    this.routingMs,
    this.promptEvalMs,
    this.sessionCacheHit,
    this.finishReason,
    this.checksPassed,
    this.failedChecks = const [],
  });

  final String caseId;
  final String suite;

  /// 0 for the case's own prompt, 1+ for follow-up turns.
  final int turn;

  /// The engine produced no visible text for this turn. This is the bug the
  /// device run caught twice in 21 prompts, so it gets a first-class field
  /// rather than being inferred from a token count.
  final bool empty;

  final String? intent;
  final String? route;
  final bool searched;

  /// `must` / `mustNot` / `unspecified`, copied from the case so a summary can
  /// score browse precision without re-reading the catalog.
  final String? browseExpected;

  final int? outputTokens;
  final double? tokensPerSecond;
  final int? ttftMs;
  final int? routingMs;
  final int? promptEvalMs;
  final bool? sessionCacheHit;
  final String? finishReason;

  /// Null when the case declared no machine checks; then this turn is scored
  /// on latency and emptiness only.
  final bool? checksPassed;
  final List<String> failedChecks;

  Map<String, Object?> toJson() => {
        'case': caseId,
        'suite': suite,
        'turn': turn,
        'empty': empty,
        'intent': intent,
        'route': route,
        'searched': searched,
        if (browseExpected != null) 'browse_expected': browseExpected,
        'output_tokens': outputTokens,
        'tokens_per_second': tokensPerSecond,
        'ttft_ms': ttftMs,
        'routing_ms': routingMs,
        'prompt_eval_ms': promptEvalMs,
        'session_cache_hit': sessionCacheHit,
        'finish_reason': finishReason,
        'checks_passed': checksPassed,
        if (failedChecks.isNotEmpty) 'failed_checks': failedChecks,
      };

  static EvalObservation fromJson(Map<String, Object?> json) {
    final failed = json['failed_checks'];
    return EvalObservation(
      caseId: (json['case'] ?? '').toString(),
      suite: (json['suite'] ?? 'unknown').toString(),
      turn: json['turn'] is int ? json['turn']! as int : 0,
      empty: json['empty'] == true,
      intent: json['intent'] as String?,
      route: json['route'] as String?,
      searched: json['searched'] == true,
      browseExpected: json['browse_expected'] as String?,
      outputTokens: json['output_tokens'] as int?,
      tokensPerSecond: (json['tokens_per_second'] as num?)?.toDouble(),
      ttftMs: json['ttft_ms'] as int?,
      routingMs: json['routing_ms'] as int?,
      promptEvalMs: json['prompt_eval_ms'] as int?,
      sessionCacheHit: json['session_cache_hit'] as bool?,
      finishReason: json['finish_reason'] as String?,
      checksPassed: json['checks_passed'] as bool?,
      failedChecks: failed is List
          ? failed.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}

/// Aggregate view of a run. Every field is nullable rather than defaulted to
/// zero so "nothing measured" is distinguishable from "measured zero".
@immutable
class EvalSummary {
  const EvalSummary({
    required this.observations,
    required this.emptyRate,
    required this.searchRate,
    required this.browsePrecision,
    required this.browseRecall,
    required this.checkPassRate,
    required this.ttftP50,
    required this.ttftP95,
    required this.tokensPerSecondP50,
    required this.routingP50,
    required this.promptEvalP50,
    this.mustNotBrowseTurns = 0,
    this.mustBrowseTurns = 0,
    this.bySuite = const {},
  });

  final List<EvalObservation> observations;

  /// Share of turns that produced no visible text.
  final double emptyRate;

  /// Share of turns that reached the web at all.
  final double searchRate;

  /// Of the turns that were expected NOT to browse, the share that stayed
  /// local. The device run showed the web firing on "capital of France" five
  /// times out of five, so this is the number that has to reach 1.0. Null
  /// when the run contained no must-not-browse turn — a vacuous 0/0 must
  /// never read as a failure.
  final double? browsePrecision;

  /// Of the turns that were expected to browse, the share that actually did.
  /// Null when the run contained no must-browse case.
  final double? browseRecall;

  /// How many turns each browse gate is measured over. A gate is only emitted
  /// when its denominator is non-zero.
  final int mustNotBrowseTurns;
  final int mustBrowseTurns;

  /// Of the turns that declared machine checks, the share that passed.
  final double? checkPassRate;

  final int? ttftP50;
  final int? ttftP95;
  final double? tokensPerSecondP50;
  final int? routingP50;
  final int? promptEvalP50;

  /// Per-suite [checkPassRate], for spotting which kind of prompt regressed.
  final Map<String, double> bySuite;

  int get observationCount => observations.length;

  int get emptyCount => observations.where((entry) => entry.empty).length;

  Map<String, Object?> toJson() => {
        'observations': observationCount,
        'empty_rate': emptyRate,
        'search_rate': searchRate,
        'browse_precision': browsePrecision,
        'browse_recall': browseRecall,
        'check_pass_rate': checkPassRate,
        'ttft_p50_ms': ttftP50,
        'ttft_p95_ms': ttftP95,
        'tokens_per_second_p50': tokensPerSecondP50,
        'routing_p50_ms': routingP50,
        'prompt_eval_p50_ms': promptEvalP50,
        'by_suite': bySuite,
      };

  static EvalSummary fromJson(Map<String, Object?> json) {
    final bySuite = <String, double>{};
    final rawBySuite = json['by_suite'];
    if (rawBySuite is Map) {
      rawBySuite.forEach((key, value) {
        if (value is num) bySuite[key.toString()] = value.toDouble();
      });
    }
    return EvalSummary(
      observations: const [],
      emptyRate: (json['empty_rate'] as num?)?.toDouble() ?? 0,
      searchRate: (json['search_rate'] as num?)?.toDouble() ?? 0,
      browsePrecision: (json['browse_precision'] as num?)?.toDouble() ?? 0,
      browseRecall: (json['browse_recall'] as num?)?.toDouble(),
      checkPassRate: (json['check_pass_rate'] as num?)?.toDouble(),
      ttftP50: json['ttft_p50_ms'] as int?,
      ttftP95: json['ttft_p95_ms'] as int?,
      tokensPerSecondP50: (json['tokens_per_second_p50'] as num?)?.toDouble(),
      routingP50: json['routing_p50_ms'] as int?,
      promptEvalP50: json['prompt_eval_p50_ms'] as int?,
      bySuite: bySuite,
    );
  }
}

/// Percentile over [values] using nearest-rank, the same rule the in-app
/// benchmark summary uses so the two cannot disagree.
int? percentile(List<int> values, double fraction) {
  if (values.isEmpty) return null;
  final sorted = List<int>.of(values)..sort();
  final index = ((sorted.length - 1) * fraction).ceil();
  return sorted[index.clamp(0, sorted.length - 1)];
}

double? percentileDouble(List<double> values, double fraction) {
  if (values.isEmpty) return null;
  final sorted = List<double>.of(values)..sort();
  final index = ((sorted.length - 1) * fraction).ceil();
  return sorted[index.clamp(0, sorted.length - 1)];
}

double _rate(int numerator, int denominator) =>
    denominator == 0 ? 0 : numerator / denominator;

/// Folds observations into the numbers a gate is written against.
EvalSummary summarize(List<EvalObservation> observations) {
  if (observations.isEmpty) {
    return const EvalSummary(
      observations: [],
      emptyRate: 0,
      searchRate: 0,
      browsePrecision: null,
      browseRecall: null,
      checkPassRate: null,
      ttftP50: null,
      ttftP95: null,
      tokensPerSecondP50: null,
      routingP50: null,
      promptEvalP50: null,
    );
  }

  final mustNotSearch = observations
      .where((entry) => entry.browseExpected == 'mustNot')
      .toList(growable: false);
  final mustSearch = observations
      .where((entry) => entry.browseExpected == 'must')
      .toList(growable: false);
  final checked = observations
      .where((entry) => entry.checksPassed != null)
      .toList(growable: false);

  final suiteTotals = <String, int>{};
  final suitePasses = <String, int>{};
  for (final entry in checked) {
    suiteTotals[entry.suite] = (suiteTotals[entry.suite] ?? 0) + 1;
    if (entry.checksPassed!) {
      suitePasses[entry.suite] = (suitePasses[entry.suite] ?? 0) + 1;
    }
  }
  final bySuite = <String, double>{};
  suiteTotals.forEach((suite, total) {
    bySuite[suite] = _rate(suitePasses[suite] ?? 0, total);
  });

  return EvalSummary(
    observations: observations,
    emptyRate: _rate(
      observations.where((entry) => entry.empty).length,
      observations.length,
    ),
    searchRate: _rate(
      observations.where((entry) => entry.searched).length,
      observations.length,
    ),
    browsePrecision: mustNotSearch.isEmpty
        ? null
        : _rate(
            mustNotSearch.where((entry) => !entry.searched).length,
            mustNotSearch.length,
          ),
    browseRecall: mustSearch.isEmpty
        ? null
        : _rate(
            mustSearch.where((entry) => entry.searched).length,
            mustSearch.length,
          ),
    mustNotBrowseTurns: mustNotSearch.length,
    mustBrowseTurns: mustSearch.length,
    checkPassRate: checked.isEmpty
        ? null
        : _rate(checked.where((entry) => entry.checksPassed!).length,
            checked.length),
    ttftP50: percentile(
      observations
          .where((entry) => entry.ttftMs != null)
          .map((entry) => entry.ttftMs!)
          .toList(),
      .50,
    ),
    ttftP95: percentile(
      observations
          .where((entry) => entry.ttftMs != null)
          .map((entry) => entry.ttftMs!)
          .toList(),
      .95,
    ),
    tokensPerSecondP50: percentileDouble(
      observations
          .where((entry) => entry.tokensPerSecond != null)
          .map((entry) => entry.tokensPerSecond!)
          .toList(),
      .50,
    ),
    routingP50: percentile(
      observations
          .where((entry) => entry.routingMs != null)
          .map((entry) => entry.routingMs!)
          .toList(),
      .50,
    ),
    promptEvalP50: percentile(
      observations
          .where((entry) => entry.promptEvalMs != null)
          .map((entry) => entry.promptEvalMs!)
          .toList(),
      .50,
    ),
    bySuite: bySuite,
  );
}

/// The numbers a change is allowed to move before it is a regression.
///
/// Absolute bars come from the Phase 0 baseline on the reference device; the
/// relative tolerances come from PLAN.md §6, which asks for ±10-20% gates
/// rather than invented pass marks. Every default here is a real measured
/// value or a named tolerance — none is a round number picked for looks.
class EvalGates {
  const EvalGates({
    this.maxEmptyReplyRate = 0.02,
    this.minBrowsePrecision = 1.0,
    this.ttftP95Tolerance = 0.25,
    this.decodeSpeedTolerance = 0.15,
    this.checkPassRateTolerance = 0.05,
  });

  /// A turn that renders nothing is a bug, not a style question. The device
  /// run produced 2 of 21; Phase 1 targets 0.
  final double maxEmptyReplyRate;

  /// Everything marked must-not-browse has to stay local. 1.0 is the goal,
  /// not a rounding of it.
  final double minBrowsePrecision;

  /// Allowed slowdown against the committed baseline, as a fraction.
  final double ttftP95Tolerance;

  /// Allowed decode-speed loss against the committed baseline.
  final double decodeSpeedTolerance;

  /// Allowed loss of check pass rate against the committed baseline.
  final double checkPassRateTolerance;

  Map<String, Object?> toJson() => {
        'max_empty_reply_rate': maxEmptyReplyRate,
        'min_browse_precision': minBrowsePrecision,
        'ttft_p95_tolerance': ttftP95Tolerance,
        'decode_speed_tolerance': decodeSpeedTolerance,
        'check_pass_rate_tolerance': checkPassRateTolerance,
      };

  static EvalGates fromJson(Map<String, Object?> json) {
    double read(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    return EvalGates(
      maxEmptyReplyRate: read('max_empty_reply_rate', 0.02),
      minBrowsePrecision: read('min_browse_precision', 1.0),
      ttftP95Tolerance: read('ttft_p95_tolerance', 0.25),
      decodeSpeedTolerance: read('decode_speed_tolerance', 0.15),
      checkPassRateTolerance: read('check_pass_rate_tolerance', 0.05),
    );
  }
}

/// One gate's verdict.
@immutable
class GateResult {
  const GateResult({
    required this.name,
    required this.passed,
    required this.detail,
    this.baseline,
    this.current,
  });

  final String name;
  final bool passed;
  final String detail;
  final double? baseline;
  final double? current;

  Map<String, Object?> toJson() => {
        'gate': name,
        'passed': passed,
        'detail': detail,
        if (baseline != null) 'baseline': baseline,
        if (current != null) 'current': current,
      };
}

/// The result of running the gates against a fresh summary.
@immutable
class EvalComparison {
  const EvalComparison({required this.results});

  final List<GateResult> results;

  bool get passed => results.every((gate) => gate.passed);

  List<GateResult> get failures =>
      results.where((gate) => !gate.passed).toList(growable: false);

  Map<String, Object?> toJson() => {
        'passed': passed,
        'gates': results.map((gate) => gate.toJson()).toList(),
      };
}

/// Checks [current] against [gates], using [baseline] only to detect relative
/// regressions. A null [baseline] still yields the absolute gates, which is
/// what makes a first run (writing a baseline) possible.
EvalComparison compareToBaseline(
  EvalSummary current,
  EvalGates gates, {
  EvalSummary? baseline,
}) {
  final results = <GateResult>[];

  results.add(
    GateResult(
      name: 'empty_reply_rate',
      passed: current.emptyRate <= gates.maxEmptyReplyRate,
      detail: 'empty ${_pct(current.emptyRate)} of turns, '
          'bar ${_pct(gates.maxEmptyReplyRate)}',
      current: current.emptyRate,
      baseline: baseline?.emptyRate,
    ),
  );

  final precision = current.browsePrecision;
  if (precision != null) {
    results.add(
      GateResult(
        name: 'browse_precision',
        passed: precision >= gates.minBrowsePrecision,
        detail: 'stayed local on ${_pct(precision)} of '
            '${current.mustNotBrowseTurns} must-not-browse turns, '
            'bar ${_pct(gates.minBrowsePrecision)}',
        current: precision,
        baseline: baseline?.browsePrecision,
      ),
    );
  }

  final recall = current.browseRecall;
  if (recall != null) {
    results.add(
      GateResult(
        name: 'browse_recall',
        passed: recall >= 1.0,
        detail: 'browsed on ${_pct(recall)} of '
            '${current.mustBrowseTurns} must-browse turns',
        current: recall,
        baseline: baseline?.browseRecall,
      ),
    );
  }

  final baselineTtft = baseline?.ttftP95;
  if (baselineTtft != null && baselineTtft > 0 && current.ttftP95 != null) {
    final allowed = baselineTtft * (1 + gates.ttftP95Tolerance);
    final over = current.ttftP95! > allowed;
    results.add(
      GateResult(
        name: 'ttft_p95',
        passed: !over,
        detail: 'p95 ${current.ttftP95}ms against baseline ${baselineTtft}ms '
            '(+${_pct(gates.ttftP95Tolerance)} = ${allowed.round()}ms)',
        baseline: baselineTtft.toDouble(),
        current: current.ttftP95!.toDouble(),
      ),
    );
  }

  final baselineTps = baseline?.tokensPerSecondP50;
  final currentTps = current.tokensPerSecondP50;
  if (baselineTps != null && baselineTps > 0 && currentTps != null) {
    final allowed = baselineTps * (1 - gates.decodeSpeedTolerance);
    final under = currentTps < allowed;
    results.add(
      GateResult(
        name: 'decode_speed',
        passed: !under,
        detail: 'p50 ${currentTps.toStringAsFixed(1)} tok/s against baseline '
            '${baselineTps.toStringAsFixed(1)} tok/s '
            '(-${_pct(gates.decodeSpeedTolerance)} = '
            '${allowed.toStringAsFixed(1)} tok/s)',
        baseline: baselineTps,
        current: currentTps,
      ),
    );
  }

  final baselinePass = baseline?.checkPassRate;
  final currentPass = current.checkPassRate;
  if (baselinePass != null && currentPass != null) {
    final allowed = baselinePass - gates.checkPassRateTolerance;
    final under = currentPass < allowed;
    results.add(
      GateResult(
        name: 'check_pass_rate',
        passed: !under,
        detail: '${_pct(currentPass)} against baseline ${_pct(baselinePass)} '
            '(floor ${_pct(allowed)})',
        baseline: baselinePass,
        current: currentPass,
      ),
    );
  }

  return EvalComparison(results: results);
}

String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';

/// A committed run: the observations plus the device they were measured on.
///
/// `model` and `contextTokens` are part of the identity. A 2048-token-context
/// run and a 4096-token-context run are different experiments, and comparing
/// them would quietly excuse a quality regression.
@immutable
class EvalBaseline {
  const EvalBaseline({
    required this.model,
    required this.device,
    required this.contextTokens,
    required this.createdAt,
    required this.observations,
    this.gates = const EvalGates(),
  });

  final String model;
  final String device;
  final int contextTokens;
  final String createdAt;
  final List<EvalObservation> observations;
  final EvalGates gates;

  EvalSummary get summary => summarize(observations);

  Map<String, Object?> toJson() => {
        'schema': 1,
        'model': model,
        'device': device,
        'context_tokens': contextTokens,
        'created_at': createdAt,
        'gates': gates.toJson(),
        'summary': summary.toJson(),
        'observations': observations.map((entry) => entry.toJson()).toList(),
      };

  String encode({bool pretty = true}) => pretty
      ? '${const JsonEncoder.withIndent('  ').convert(toJson())}\n'
      : '${jsonEncode(toJson())}\n';

  static EvalBaseline decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('eval baseline must be a JSON object');
    }
    final map = decoded.cast<String, Object?>();
    if (map['schema'] != 1) {
      throw FormatException(
          'unsupported eval baseline schema ${map['schema']}');
    }
    final rawObservations = map['observations'];
    final observations = <EvalObservation>[];
    if (rawObservations is List) {
      for (final entry in rawObservations) {
        if (entry is Map) {
          observations.add(
            EvalObservation.fromJson(entry.cast<String, Object?>()),
          );
        }
      }
    }
    final rawGates = map['gates'];
    return EvalBaseline(
      model: (map['model'] ?? 'unknown').toString(),
      device: (map['device'] ?? 'unknown').toString(),
      contextTokens:
          map['context_tokens'] is int ? map['context_tokens']! as int : 0,
      createdAt: (map['created_at'] ?? 'unknown').toString(),
      observations: observations,
      gates: rawGates is Map
          ? EvalGates.fromJson(rawGates.cast<String, Object?>())
          : const EvalGates(),
    );
  }
}
