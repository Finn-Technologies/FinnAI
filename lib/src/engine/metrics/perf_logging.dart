import 'package:flutter/foundation.dart';

/// Decides whether a performance line reaches the log.
///
/// Debug builds emit everything. Release builds emit the first turn and then
/// every [releaseSampleEvery]-th, which is enough to answer "is time-to-first-
/// token getting worse in the field" without turning every generation into a
/// log line.
///
/// The lines this gate covers carry only numbers: latencies, token counts,
/// cache-hit flags, context size, thread counts, engine version. No prompt,
/// no answer, no file name and no user content. That is the whole reason the
/// gate can be opened in production at all — see PLAN.md §9.1.
///
/// Two things stay debug-only regardless:
///
/// - the full prompt breakdown, which is expensive duplicate prefill-side work
///   and contains user text, and
/// - the unverified-weights warning, which is a decision, not a measurement.
///
/// Call [sample] before doing any work that only exists to produce the line: a
/// sampled-out value should cost nothing to skip.
class PerfLogSampler {
  const PerfLogSampler._();

  /// Turns between samples in release builds. Eight keeps a normal session's
  /// samples spread across the run instead of clustering at the start.
  static const int releaseSampleEvery = 8;

  static int _turns = 0;

  /// Turns this process has been asked about. Exposed for tests.
  @visibleForTesting
  static int get seenTurns => _turns;

  @visibleForTesting
  static void reset() => _turns = 0;

  /// True when this turn should be logged, using the current build mode.
  static bool sample() => sampleFor(release: kReleaseMode);

  /// The sampling rule on its own, with the build mode supplied.
  ///
  /// Split out from [sample] so the rule is testable: a test runs in debug
  /// mode, where [kReleaseMode] is false and every turn would be kept.
  @visibleForTesting
  static bool sampleFor({required bool release}) {
    if (!release) return true;
    _turns++;
    return _turns == 1 || _turns % releaseSampleEvery == 0;
  }
}
