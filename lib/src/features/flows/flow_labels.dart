import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';

/// "Every day at 07:30", "Weekdays at 07:30", "Monday, Friday at 18:00", or
/// the manual wording.
String flowScheduleLabel(BuildContext context, FlowTrigger trigger) {
  final l10n = L10n.of(context);
  if (!trigger.isScheduled) return l10n.flowsOnlyWhenAsked;
  final time = '${trigger.hour.toString().padLeft(2, '0')}:'
      '${trigger.minute.toString().padLeft(2, '0')}';
  final days = trigger.daysOfWeek;
  if (days.isEmpty || days.length == 7) return l10n.flowsScheduleDaily(time);
  if (days.length == 5 && days.containsAll(const {1, 2, 3, 4, 5})) {
    return l10n.flowsScheduleWeekdaysAt(time);
  }
  return l10n.flowsScheduleWeekly(_dayNames(l10n, days, wide: true), time);
}

String _dayNames(AppLocalizations l10n, Set<int> days, {required bool wide}) {
  final sorted = days.toList()..sort();
  try {
    final names = DateFormat.EEEE(l10n.localeName);
    return [
      for (final day in sorted) names.format(DateTime(2026, 1, 5 + day - 1)),
    ].join(', ');
  } on Object {
    const english = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return [for (final day in sorted) english[day - 1]].join(', ');
  }
}

/// One-letter weekday initials, Monday first, in the user's language.
List<String> flowDayInitials(AppLocalizations l10n) {
  try {
    final names = DateFormat.E(l10n.localeName);
    return [
      for (var day = 1; day <= 7; day++)
        names.format(DateTime(2026, 1, 5 + day - 1)).characters.first,
    ];
  } on Object {
    return const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  }
}

/// Full weekday names, Monday first, for screen readers.
List<String> flowDayNames(AppLocalizations l10n) {
  try {
    final names = DateFormat.EEEE(l10n.localeName);
    return [
      for (var day = 1; day <= 7; day++)
        names.format(DateTime(2026, 1, 5 + day - 1)),
    ];
  } on Object {
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
  }
}

/// A step as one human line: what it does, not how it is written.
String flowStepLabel(AppLocalizations l10n, FlowStep step) =>
    switch (step.kind) {
      FlowStepKind.browse => l10n.flowsStepLookUp(
          step.text.replaceFirst(RegExp(r'^\w+:\s*'), '').trim(),
        ),
      FlowStepKind.prompt => l10n.flowsStepWrite,
      FlowStepKind.notify => l10n.flowsStepNotifyMe,
      FlowStepKind.deviceAction => step.text,
    };

String flowRunStatus(AppLocalizations l10n, FlowRunOutcome outcome) =>
    switch (outcome) {
      FlowRunOutcome.completed => l10n.flowsRunStatusDone,
      FlowRunOutcome.failed => l10n.flowsRunStatusFailed,
      FlowRunOutcome.declined => l10n.flowsRunStatusDeclined,
      FlowRunOutcome.needsGrant => l10n.flowsRunStatusNeedsGrant,
      FlowRunOutcome.interrupted => l10n.flowsRunStatusStopped,
    };

/// "today", "yesterday", or a weekday / date.
String flowWhen(
  BuildContext context,
  DateTime time, {
  DateTime? now,
  bool withTime = false,
}) {
  final l10n = L10n.of(context);
  final reference = (now ?? DateTime.now()).toLocal();
  final local = time.toLocal();
  final days = DateTime(reference.year, reference.month, reference.day)
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  String day;
  try {
    day = switch (days) {
      0 => l10n.flowsWhenToday,
      1 => l10n.flowsWhenYesterday,
      < 7 => DateFormat.EEEE(l10n.localeName).format(local),
      _ => DateFormat.MMMd(l10n.localeName).format(local),
    };
  } on Object {
    day = days == 0 ? l10n.flowsWhenToday : '${local.day}/${local.month}';
  }
  if (!withTime) return day;
  day = day.isEmpty ? day : '${day[0].toUpperCase()}${day.substring(1)}';
  final clock = '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '$day, $clock';
}

/// When a scheduled flow next fires after [now].
DateTime? flowNextRun(FlowTrigger trigger, DateTime now) {
  if (!trigger.isScheduled) return null;
  for (var offset = 0; offset < 8; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    final at = DateTime(
      day.year,
      day.month,
      day.day,
      trigger.hour,
      trigger.minute,
    );
    if (at.isAfter(now) &&
        (trigger.daysOfWeek.isEmpty ||
            trigger.daysOfWeek.contains(at.weekday))) {
      return at;
    }
  }
  return null;
}

/// "Finished · Ran by itself": how a run ended and who started it.
String flowRunLine(AppLocalizations l10n, FlowRun run) {
  final outcome = switch (run.outcome) {
    FlowRunOutcome.completed => l10n.flowsRunCompleted,
    FlowRunOutcome.declined => l10n.flowsRunDeclined,
    FlowRunOutcome.failed => l10n.flowsRunFailed,
    FlowRunOutcome.interrupted => l10n.flowsRunInterrupted,
    FlowRunOutcome.needsGrant => l10n.flowsNeedsGrant,
  };
  final by = run.triggeredBy == 'schedule'
      ? l10n.flowsRunBySchedule
      : l10n.flowsRunByYou;
  return '$outcome · $by';
}
