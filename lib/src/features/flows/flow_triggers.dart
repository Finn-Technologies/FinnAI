import 'package:flutter/foundation.dart';

/// What can start a flow by itself.
enum FlowTriggerKind {
  /// Only the user starts it (the button, a chat message, a shortcut).
  manual,

  /// A clock time, on some or all days.
  timeOfDay,

  /// Every so many minutes.
  interval,

  chargerConnected,
  chargerDisconnected,

  /// The battery fell to a level and is not charging.
  batteryLow,
  headsetConnected,
  headsetDisconnected,
  wifiConnected,
  wifiDisconnected,
  airplaneOn,
  airplaneOff,

  /// The phone finished starting up.
  deviceBooted,

  /// The user unlocked the screen.
  screenUnlocked;

  /// Triggers the operating system tells us about as they happen. They need
  /// the small always-on service that listens for them.
  bool get isEvent => switch (this) {
        manual || timeOfDay || interval => false,
        _ => true,
      };

  /// Triggers an alarm can express.
  bool get isScheduled => this == timeOfDay || this == interval;
}

/// When a flow runs on its own.
@immutable
class FlowTrigger {
  const FlowTrigger._(
    this.kind, {
    this.hour = 0,
    this.minute = 0,
    this.daysOfWeek = const {},
    this.intervalMinutes = 0,
    this.level = 20,
  });

  const FlowTrigger.manual() : this._(FlowTriggerKind.manual);

  const FlowTrigger.daily(int hour, int minute)
      : this._(FlowTriggerKind.timeOfDay, hour: hour, minute: minute);

  const FlowTrigger.weekly(int hour, int minute, Set<int> days)
      : this._(
          FlowTriggerKind.timeOfDay,
          hour: hour,
          minute: minute,
          daysOfWeek: days,
        );

  const FlowTrigger.every(int minutes)
      : this._(FlowTriggerKind.interval, intervalMinutes: minutes);

  const FlowTrigger.batteryLow([int level = 20])
      : this._(FlowTriggerKind.batteryLow, level: level);

  const FlowTrigger.event(FlowTriggerKind kind) : this._(kind);

  final FlowTriggerKind kind;

  /// Local time. A local time and not UTC on purpose: a flow that runs at 7am
  /// should run at 7am where the phone is, and the device timezone is what the
  /// user means by "7am".
  final int hour;
  final int minute;

  /// 1 = Monday .. 7 = Sunday, matching `DateTime.weekday`. Empty means every
  /// day for a [FlowTriggerKind.timeOfDay].
  final Set<int> daysOfWeek;

  /// For [FlowTriggerKind.interval]. The platform batches alarms, so anything
  /// under [minInterval] would not be honoured and is not offered.
  final int intervalMinutes;

  /// For [FlowTriggerKind.batteryLow]: the percent it must fall to.
  final int level;

  static const int minInterval = 15;
  static const int maxInterval = 24 * 60;

  bool get isScheduled => kind.isScheduled;
  bool get isEvent => kind.isEvent;
  bool get isManual => kind == FlowTriggerKind.manual;

  /// Whether this trigger's own values are usable.
  bool get isValid => switch (kind) {
        FlowTriggerKind.timeOfDay =>
          hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59,
        FlowTriggerKind.interval =>
          intervalMinutes >= minInterval && intervalMinutes <= maxInterval,
        FlowTriggerKind.batteryLow => level >= 1 && level <= 99,
        _ => true,
      };

  /// Whether a clock-time trigger is due at [now], given that the caller has
  /// already decided to run at most once per minute. Pure, so the whole rule is
  /// testable without a clock, a plugin, or a device.
  bool isDueAt(DateTime now) {
    if (kind != FlowTriggerKind.timeOfDay) return false;
    if (now.hour != hour || now.minute != minute) return false;
    return daysOfWeek.isEmpty || daysOfWeek.contains(now.weekday);
  }

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        if (kind == FlowTriggerKind.timeOfDay) 'hour': hour,
        if (kind == FlowTriggerKind.timeOfDay) 'minute': minute,
        if (daysOfWeek.isNotEmpty && kind == FlowTriggerKind.timeOfDay)
          'days': daysOfWeek.toList()..sort(),
        if (kind == FlowTriggerKind.interval) 'every': intervalMinutes,
        if (kind == FlowTriggerKind.batteryLow) 'level': level,
      };

  /// Null for a kind this version does not know.
  static FlowTrigger? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['kind']?.toString();
    final kind =
        FlowTriggerKind.values.where((k) => k.name == name).firstOrNull;
    if (kind == null) return null;
    int? number(String key) => (raw[key] as num?)?.toInt();
    switch (kind) {
      case FlowTriggerKind.timeOfDay:
        final hour = number('hour');
        final minute = number('minute');
        if (hour == null || minute == null) return null;
        final days = {
          for (final day in (raw['days'] as List<Object?>? ?? const []))
            if (day is num && day >= 1 && day <= 7) day.toInt(),
        };
        return days.isEmpty || days.length == 7
            ? FlowTrigger.daily(hour.clamp(0, 23), minute.clamp(0, 59))
            : FlowTrigger.weekly(hour.clamp(0, 23), minute.clamp(0, 59), days);
      case FlowTriggerKind.interval:
        return FlowTrigger.every(
          (number('every') ?? minInterval).clamp(minInterval, maxInterval),
        );
      case FlowTriggerKind.batteryLow:
        return FlowTrigger.batteryLow((number('level') ?? 20).clamp(1, 99));
      case FlowTriggerKind.manual:
        return const FlowTrigger.manual();
      default:
        return FlowTrigger.event(kind);
    }
  }

  /// Most triggers one flow may have.
  static const int maxPerFlow = 4;

  static List<FlowTrigger> listFromJson(Object? raw) => [
        if (raw is List)
          for (final item in raw.take(maxPerFlow))
            if (FlowTrigger.fromJson(item) case final trigger?)
              if (!trigger.isManual) trigger,
      ];

  @override
  bool operator ==(Object other) =>
      other is FlowTrigger &&
      other.kind == kind &&
      other.hour == hour &&
      other.minute == minute &&
      other.intervalMinutes == intervalMinutes &&
      other.level == level &&
      setEquals(other.daysOfWeek, daysOfWeek);

  @override
  int get hashCode => Object.hash(
      kind, hour, minute, intervalMinutes, level, daysOfWeek.length);
}
