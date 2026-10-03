import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_descriptions.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';

/// "Every day at 07:30", "Weekdays at 07:30", "Monday, Friday at 18:00", or
/// the manual wording.
String flowScheduleLabel(BuildContext context, FlowTrigger trigger) =>
    flowTriggerLabel(L10n.of(context), trigger);

/// One line for any trigger: "Every day at 07:30", "Charger connected".
String flowTriggerLabel(AppLocalizations l10n, FlowTrigger trigger) {
  switch (trigger.kind) {
    case FlowTriggerKind.manual:
      return l10n.flowsOnlyWhenAsked;
    case FlowTriggerKind.interval:
      final minutes = trigger.intervalMinutes;
      if (minutes == 60) return l10n.flowsTrigEveryHour;
      return minutes % 60 == 0
          ? l10n.flowsTrigEveryHours(minutes ~/ 60)
          : l10n.flowsTrigEveryMinutes(minutes);
    case FlowTriggerKind.chargerConnected:
      return l10n.flowsTrigChargerOn;
    case FlowTriggerKind.chargerDisconnected:
      return l10n.flowsTrigChargerOff;
    case FlowTriggerKind.batteryLow:
      return l10n.flowsTrigBatteryLow(trigger.level);
    case FlowTriggerKind.headsetConnected:
      return l10n.flowsTrigHeadsetOn;
    case FlowTriggerKind.headsetDisconnected:
      return l10n.flowsTrigHeadsetOff;
    case FlowTriggerKind.wifiConnected:
      return l10n.flowsTrigWifiOn;
    case FlowTriggerKind.wifiDisconnected:
      return l10n.flowsTrigWifiOff;
    case FlowTriggerKind.airplaneOn:
      return l10n.flowsTrigAirplaneOn;
    case FlowTriggerKind.airplaneOff:
      return l10n.flowsTrigAirplaneOff;
    case FlowTriggerKind.deviceBooted:
      return l10n.flowsTrigBoot;
    case FlowTriggerKind.screenUnlocked:
      return l10n.flowsTrigUnlock;
    case FlowTriggerKind.timeOfDay:
      break;
  }
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

/// The title of a block type: "Ask FinnAI", "Notify me".
String flowBlockTitle(AppLocalizations l10n, FlowBlockKind kind) =>
    switch (kind) {
      FlowBlockKind.ask => l10n.flowsBlockAsk,
      FlowBlockKind.web => l10n.flowsBlockWeb,
      FlowBlockKind.notify => l10n.flowsBlockNotify,
      FlowBlockKind.speak => l10n.flowsBlockSpeak,
      FlowBlockKind.action => l10n.flowsBlockAction,
      FlowBlockKind.wait => l10n.flowsBlockWait,
      FlowBlockKind.branch => l10n.flowsBlockBranch,
      FlowBlockKind.saveToChat => l10n.flowsBlockSave,
      FlowBlockKind.stop => l10n.flowsBlockStop,
    };

/// One line saying what a block type is for, for the picker.
String flowBlockHint(AppLocalizations l10n, FlowBlockKind kind) =>
    switch (kind) {
      FlowBlockKind.ask => l10n.flowsBlockAskSub,
      FlowBlockKind.web => l10n.flowsBlockWebSub,
      FlowBlockKind.notify => l10n.flowsBlockNotifySub,
      FlowBlockKind.speak => l10n.flowsBlockSpeakSub,
      FlowBlockKind.action => l10n.flowsBlockActionSub,
      FlowBlockKind.wait => l10n.flowsBlockWaitSub,
      FlowBlockKind.branch => l10n.flowsBlockBranchSub,
      FlowBlockKind.saveToChat => l10n.flowsBlockSaveSub,
      FlowBlockKind.stop => l10n.flowsBlockStopSub,
    };

/// A condition as one line: "Battery below 30%".
String flowConditionLabel(AppLocalizations l10n, FlowCondition c) {
  switch (c.kind) {
    case FlowConditionKind.batteryBelow:
      return l10n.flowsCondBatteryBelow(c.value);
    case FlowConditionKind.batteryAbove:
      return l10n.flowsCondBatteryAbove(c.value);
    case FlowConditionKind.charging:
      return l10n.flowsCondCharging;
    case FlowConditionKind.notCharging:
      return l10n.flowsCondNotCharging;
    case FlowConditionKind.timeBetween:
      return l10n.flowsCondTimeBetween(
        flowMinutesLabel(c.value),
        flowMinutesLabel(c.endValue),
      );
    case FlowConditionKind.weekdays:
      return l10n.flowsCondDays(_dayNames(l10n, c.days, wide: true));
    case FlowConditionKind.wifiConnected:
      return l10n.flowsCondWifiOn;
    case FlowConditionKind.wifiDisconnected:
      return l10n.flowsCondWifiOff;
    case FlowConditionKind.headsetConnected:
      return l10n.flowsCondHeadsetOn;
    case FlowConditionKind.headsetDisconnected:
      return l10n.flowsCondHeadsetOff;
    case FlowConditionKind.airplaneOn:
      return l10n.flowsCondAirplaneOn;
    case FlowConditionKind.airplaneOff:
      return l10n.flowsCondAirplaneOff;
    case FlowConditionKind.answerContains:
      return l10n.flowsCondAnswer(c.text);
  }
}

/// Minutes after midnight as `07:30`.
String flowMinutesLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// What a block does, in one line, for its card in the chart.
String flowBlockSummary(BuildContext context, FlowBlock block) {
  final l10n = L10n.of(context);
  switch (block.kind) {
    case FlowBlockKind.ask:
      return l10n.flowsSumAsk(_short(block.text));
    case FlowBlockKind.web:
      return l10n.flowsSumWeb(
        _short(block.text.replaceFirst(RegExp(r'^\w+:\s*'), '')),
      );
    case FlowBlockKind.notify:
      return block.text.trim().isEmpty
          ? l10n.flowsSumNotifyAnswer
          : _short(block.text);
    case FlowBlockKind.speak:
      return block.text.trim().isEmpty
          ? l10n.flowsSumSpeakAnswer
          : _short(block.text);
    case FlowBlockKind.action:
      final action = DeviceActionCatalog.byName(block.actionName ?? '');
      if (action == null) return block.actionName ?? '';
      return DeviceActionDescriptions.describe(
        context,
        DeviceActionInvocation(action: action, arguments: block.arguments),
      );
    case FlowBlockKind.wait:
      return l10n.flowsSumWait(block.seconds);
    case FlowBlockKind.branch:
      return l10n.flowsSumIf(
        block.condition == null
            ? ''
            : flowConditionLabel(l10n, block.condition!),
      );
    case FlowBlockKind.saveToChat:
      return l10n.flowsBlockSaveSub;
    case FlowBlockKind.stop:
      return l10n.flowsBlockStopSub;
  }
}

String _short(String text) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length <= 60 ? flat : '${flat.substring(0, 60).trimRight()}…';
}

String flowRunStatus(AppLocalizations l10n, FlowRunOutcome outcome) =>
    switch (outcome) {
      FlowRunOutcome.completed => l10n.flowsRunStatusDone,
      FlowRunOutcome.failed => l10n.flowsRunStatusFailed,
      FlowRunOutcome.declined => l10n.flowsRunStatusDeclined,
      FlowRunOutcome.needsGrant => l10n.flowsRunStatusNeedsGrant,
      FlowRunOutcome.needsScreen => l10n.flowsRunStatusNeedsScreen,
      FlowRunOutcome.skipped => l10n.flowsRunStatusSkipped,
      FlowRunOutcome.interrupted => l10n.flowsRunStatusStopped,
    };

/// "Finished · Ran by itself": how a run ended and who started it.
String flowRunLine(AppLocalizations l10n, FlowRun run) {
  final outcome = switch (run.outcome) {
    FlowRunOutcome.completed => l10n.flowsRunCompleted,
    FlowRunOutcome.declined => l10n.flowsRunDeclined,
    FlowRunOutcome.failed => l10n.flowsRunFailed,
    FlowRunOutcome.interrupted => l10n.flowsRunInterrupted,
    FlowRunOutcome.needsGrant => l10n.flowsNeedsGrant,
    FlowRunOutcome.needsScreen => l10n.flowsRunNeedsScreen,
    FlowRunOutcome.skipped => l10n.flowsRunSkipped,
  };
  final by =
      run.triggeredBy == 'schedule' || run.triggeredBy.startsWith('event:')
          ? l10n.flowsRunBySchedule
          : run.triggeredBy == 'chat'
              ? l10n.flowsRunByChat
              : l10n.flowsRunByYou;
  return '$outcome · $by';
}
