import 'package:finn_ai/src/features/flows/flow_model.dart';

/// When a scheduled flow next runs. Pure, so the rule is tested with no clock.
///
/// The native scheduler (WorkManager) needs a concrete instant; the rule that
/// produces it lives here so it is covered by Dart tests, and the Kotlin side
/// only ever converts it to a delay.
abstract final class FlowSchedule {
  /// The first local time strictly after [now] that matches [trigger], or null
  /// for a flow with no schedule.
  ///
  /// Built from calendar fields rather than by adding 24 hours, so a daylight
  /// saving change moves the flow with the wall clock: 7:00 stays 7:00.
  static DateTime? nextRun(FlowTrigger trigger, DateTime now) {
    if (!trigger.isScheduled) return null;
    for (var offset = 0; offset <= 7; offset++) {
      final candidate = DateTime(
        now.year,
        now.month,
        now.day + offset,
        trigger.hour,
        trigger.minute,
      );
      if (!candidate.isAfter(now)) continue;
      if (trigger.daysOfWeek.isEmpty ||
          trigger.daysOfWeek.contains(candidate.weekday)) {
        return candidate;
      }
    }
    return null;
  }
}
