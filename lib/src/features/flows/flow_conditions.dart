import 'package:flutter/foundation.dart';

/// What the phone looks like right now, as far as a flow cares.
///
/// Read once at the start of a run (and again at each branch), by the platform
/// bridge in the app and by a fake in tests, so a condition is a pure function
/// of this snapshot and needs no device to test.
@immutable
class FlowEnvironmentSnapshot {
  const FlowEnvironmentSnapshot({
    required this.now,
    this.batteryPercent = 100,
    this.charging = false,
    this.wifiConnected = false,
    this.headsetConnected = false,
    this.airplane = false,
  });

  final DateTime now;
  final int batteryPercent;
  final bool charging;
  final bool wifiConnected;
  final bool headsetConnected;
  final bool airplane;

  factory FlowEnvironmentSnapshot.fromMap(
    Map<Object?, Object?> map, {
    required DateTime now,
  }) =>
      FlowEnvironmentSnapshot(
        now: now,
        batteryPercent:
            ((map['battery'] as num?)?.toInt() ?? 100).clamp(0, 100),
        charging: map['charging'] == true,
        wifiConnected: map['wifi'] == true,
        headsetConnected: map['headset'] == true,
        airplane: map['airplane'] == true,
      );
}

/// What a condition tests.
enum FlowConditionKind {
  batteryBelow,
  batteryAbove,
  charging,
  notCharging,
  timeBetween,
  weekdays,
  wifiConnected,
  wifiDisconnected,
  headsetConnected,
  headsetDisconnected,
  airplaneOn,
  airplaneOff,

  /// The last answer the model wrote contains some text.
  answerContains,
}

/// A yes/no question about the phone or the run, used in two places: as a
/// flow's *only if* conditions and as the test of a branch block.
@immutable
class FlowCondition {
  const FlowCondition(
    this.kind, {
    this.value = 0,
    this.endValue = 0,
    this.days = const {},
    this.text = '',
  });

  const FlowCondition.batteryBelow(int percent)
      : this(FlowConditionKind.batteryBelow, value: percent);

  const FlowCondition.batteryAbove(int percent)
      : this(FlowConditionKind.batteryAbove, value: percent);

  /// Between two times of day, each as minutes after midnight. The window may
  /// run past midnight (22:00 to 06:00).
  const FlowCondition.timeBetween(int startMinutes, int endMinutes)
      : this(
          FlowConditionKind.timeBetween,
          value: startMinutes,
          endValue: endMinutes,
        );

  /// On these days, 1 = Monday .. 7 = Sunday.
  const FlowCondition.weekdays(Set<int> days)
      : this(FlowConditionKind.weekdays, days: days);

  const FlowCondition.answerContains(String text)
      : this(FlowConditionKind.answerContains, text: text);

  final FlowConditionKind kind;

  /// Percent for battery conditions, or the start minute of a time window.
  final int value;

  /// The end minute of a time window.
  final int endValue;
  final Set<int> days;
  final String text;

  /// Longest text a condition may carry.
  static const int maxTextLength = 80;

  bool holds(FlowEnvironmentSnapshot env, {String answer = ''}) {
    switch (kind) {
      case FlowConditionKind.batteryBelow:
        return env.batteryPercent < value;
      case FlowConditionKind.batteryAbove:
        return env.batteryPercent > value;
      case FlowConditionKind.charging:
        return env.charging;
      case FlowConditionKind.notCharging:
        return !env.charging;
      case FlowConditionKind.timeBetween:
        final minutes = env.now.hour * 60 + env.now.minute;
        return value <= endValue
            ? minutes >= value && minutes < endValue
            : minutes >= value || minutes < endValue;
      case FlowConditionKind.weekdays:
        return days.isEmpty || days.contains(env.now.weekday);
      case FlowConditionKind.wifiConnected:
        return env.wifiConnected;
      case FlowConditionKind.wifiDisconnected:
        return !env.wifiConnected;
      case FlowConditionKind.headsetConnected:
        return env.headsetConnected;
      case FlowConditionKind.headsetDisconnected:
        return !env.headsetConnected;
      case FlowConditionKind.airplaneOn:
        return env.airplane;
      case FlowConditionKind.airplaneOff:
        return !env.airplane;
      case FlowConditionKind.answerContains:
        final needle = text.trim().toLowerCase();
        return needle.isNotEmpty && answer.toLowerCase().contains(needle);
    }
  }

  /// Whether the values this kind reads are in range.
  bool get isValid => switch (kind) {
        FlowConditionKind.batteryBelow ||
        FlowConditionKind.batteryAbove =>
          value >= 0 && value <= 100,
        FlowConditionKind.timeBetween =>
          value >= 0 && value < 1440 && endValue >= 0 && endValue < 1440,
        FlowConditionKind.weekdays => days.every((d) => d >= 1 && d <= 7),
        FlowConditionKind.answerContains => text.trim().isNotEmpty,
        _ => true,
      };

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        if (kind == FlowConditionKind.batteryBelow ||
            kind == FlowConditionKind.batteryAbove ||
            kind == FlowConditionKind.timeBetween)
          'value': value,
        if (kind == FlowConditionKind.timeBetween) 'end': endValue,
        if (kind == FlowConditionKind.weekdays) 'days': days.toList()..sort(),
        if (kind == FlowConditionKind.answerContains) 'text': text,
      };

  /// Null for a kind this version does not know, so a flow written by a newer
  /// app loses the condition rather than guessing what it meant.
  static FlowCondition? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['kind']?.toString();
    final kind =
        FlowConditionKind.values.where((k) => k.name == name).firstOrNull;
    if (kind == null) return null;
    int number(String key) => ((raw[key] as num?)?.toInt() ?? 0);
    return FlowCondition(
      kind,
      value: kind == FlowConditionKind.timeBetween
          ? number('value').clamp(0, 1439)
          : number('value').clamp(0, 100),
      endValue: number('end').clamp(0, 1439),
      days: {
        for (final day in (raw['days'] as List<Object?>? ?? const []))
          if (day is num && day >= 1 && day <= 7) day.toInt(),
      },
      text: _clip(raw['text']?.toString() ?? ''),
    );
  }

  static List<FlowCondition> listFromJson(Object? raw) => [
        if (raw is List)
          for (final item in raw.take(maxPerFlow))
            if (FlowCondition.fromJson(item) case final condition?) condition,
      ];

  /// Most "only if" conditions a flow may have.
  static const int maxPerFlow = 4;

  static String _clip(String text) => text.trim().length <= maxTextLength
      ? text.trim()
      : text.trim().substring(0, maxTextLength);

  @override
  bool operator ==(Object other) =>
      other is FlowCondition &&
      other.kind == kind &&
      other.value == value &&
      other.endValue == endValue &&
      other.text == text &&
      setEquals(other.days, days);

  @override
  int get hashCode => Object.hash(kind, value, endValue, text, days.length);
}
