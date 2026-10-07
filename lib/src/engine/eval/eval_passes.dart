import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:finn_ai/src/engine/eval/eval_baseline.dart';

/// Making an evaluation run repeatable.
///
/// The same build's score used to swing ~10% between runs (84-87.5% on the
/// Mi 11 Lite in one afternoon; 56-87% on the emulator), wider than any change
/// worth gating on. Two causes, two fixes:
///
/// - Every turn drew a fresh random sampler seed. [evalTurnSeed] gives each
///   turn a seed derived from what it is, so two runs of one build sample the
///   same tokens and a difference between builds is the builds'.
/// - One unlucky turn (a thermal dip, one bad draw) moved the whole gate. A run
///   can now make several passes over the suite ([collapsePasses]) and gate on
///   the per-turn median.

/// The sampler seed for one turn: stable across runs and builds, different for
/// each case, follow-up, intrinsic repeat and pass. A case that repeats on
/// purpose (the determinism suite) still varies between its repeats, and the
/// passes of a multi-pass run are real samples rather than copies.
int evalTurnSeed({
  required String caseId,
  required int turn,
  required int repeat,
  required int pass,
}) {
  final digest = sha256.convert(utf8.encode('$caseId#$turn#$repeat#$pass'));
  // 31 bits: positive on every platform and inside llama.cpp's uint32 seed.
  return (digest.bytes[0] << 23 |
          digest.bytes[1] << 15 |
          digest.bytes[2] << 7 |
          digest.bytes[3] >> 1) &
      0x7fffffff;
}

/// Folds the passes of a multi-pass run into one median observation per turn.
///
/// Every pass runs the same cases in the same order, so observations are
/// matched by position, not by case id: a case that repeats *within* a pass on
/// purpose (the determinism suite's five identical asks) must stay five
/// observations, not collapse into one. Numbers take the median across passes;
/// booleans take the majority, and a tie counts as a failure so the gate stays
/// strict. A single pass passes straight through.
List<EvalObservation> collapsePasses(List<List<EvalObservation>> passes) {
  if (passes.isEmpty) return const [];
  if (passes.length == 1) return passes.single;
  final length = passes.first.length;
  if (passes.any((pass) => pass.length != length)) {
    throw StateError(
      'passes differ in length: ${passes.map((p) => p.length).join('/')}',
    );
  }
  return [
    for (var index = 0; index < length; index++)
      _median([for (final pass in passes) pass[index]]),
  ];
}

EvalObservation _median(List<EvalObservation> group) {
  final first = group.first;

  bool? majority(bool? Function(EvalObservation) read) {
    var yes = 0;
    var no = 0;
    for (final entry in group) {
      final value = read(entry);
      if (value == true) yes++;
      if (value == false) no++;
    }
    return yes == 0 && no == 0 ? null : yes > no;
  }

  int? medianInt(int? Function(EvalObservation) read) =>
      percentile(group.map(read).whereType<int>().toList(), .5);

  double? medianDouble(double? Function(EvalObservation) read) =>
      percentileDouble(group.map(read).whereType<double>().toList(), .5);

  String? firstNonNull(String? Function(EvalObservation) read) {
    for (final entry in group) {
      final value = read(entry);
      if (value != null) return value;
    }
    return null;
  }

  return EvalObservation(
    caseId: first.caseId,
    suite: first.suite,
    turn: first.turn,
    empty: majority((entry) => entry.empty) ?? false,
    intent: firstNonNull((entry) => entry.intent),
    route: firstNonNull((entry) => entry.route),
    searched: majority((entry) => entry.searched) ?? false,
    browseExpected: first.browseExpected,
    outputTokens: medianInt((entry) => entry.outputTokens),
    tokensPerSecond: medianDouble((entry) => entry.tokensPerSecond),
    ttftMs: medianInt((entry) => entry.ttftMs),
    routingMs: medianInt((entry) => entry.routingMs),
    promptEvalMs: medianInt((entry) => entry.promptEvalMs),
    sessionCacheHit: majority((entry) => entry.sessionCacheHit),
    finishReason: firstNonNull((entry) => entry.finishReason),
    checksPassed: majority((entry) => entry.checksPassed),
    failedChecks: <String>{
      for (final entry in group) ...entry.failedChecks,
    }.toList(growable: false),
  );
}
