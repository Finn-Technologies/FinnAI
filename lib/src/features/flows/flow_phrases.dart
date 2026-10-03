import 'package:finn_ai/src/features/flows/flow_model.dart';

/// A trigger found in a sentence, and the sentence with that part removed.
class FoundTrigger {
  const FoundTrigger(this.trigger, this.rest);

  final FlowTrigger trigger;

  /// What is left to say what the flow does.
  final String rest;
}

/// Conditions found in a sentence, and what is left.
class FoundConditions {
  const FoundConditions(this.conditions, this.rest);

  final List<FlowCondition> conditions;
  final String rest;
}

/// Plain-English phrases for triggers and conditions.
///
/// The small on-device model is not asked to design a flow, only the app
/// matches words it knows. A phrase it does not recognise is simply not found,
/// and the caller decides what to do (ask the user, or ask the model for the
/// flow in a format this file can read).
abstract final class FlowPhrases {
  static const _lead =
      r'(?:(?:when(?:ever)?|every time|each time|once|as soon as|'
      r'after|if)\s+)?(?:(?:i|my phone|the phone|my device|it)\s+)?';
  static const _tail = r'\s*(?:,|then|and then|and|:)?\s*';
  static const _headphones =
      r'(?:headphones?|headset|earphones?|earbuds?|airpods)';
  static const _theMy = r'(?:(?:the|my|a)\s+)?';

  static RegExp _event(List<String> alternatives) =>
      RegExp('$_lead(?:${alternatives.join('|')})$_tail');

  static final _chargerOn = _event([
    r'plug(?:s|ged)?(?:\s+it|\s+my phone|\s+the phone)?\s+in(?:to)?(?:\s+(?:the|my|a))?(?:\s+charger|\s+power)?',
    r'(?:charger|charging cable|power)\s+(?:is\s+)?(?:connected|plugged in|attached)',
    r'(?:starts?|begins?)\s+charging|start\s+charging',
    '(?:connect(?:s|ed)?\\s+(?:to\\s+)?)${_theMy}charger',
    r'(?:is|am|being)\s+charging',
  ]);

  static final _chargerOff = _event([
    r'unplug(?:s|ged)?(?:\s+it|\s+my phone|\s+the phone|\s+the charger|\s+my charger)?',
    r'(?:charger|charging cable|power)\s+(?:is\s+)?(?:disconnected|unplugged|removed)',
    r'(?:stops?|stopped)\s+charging',
    '(?:disconnect(?:s|ed)?\\s+(?:from\\s+)?)${_theMy}charger',
  ]);

  static final _batteryLow = _event([
    r'(?:the\s+)?battery\s+(?:is\s+|gets\s+|falls\s+|drops\s+|runs\s+|goes\s+)?'
        r'(?:low|(?:below|under|less than|at|to|reaches|hits)\s+(\d{1,2})\s*(?:%|percent)?)',
    'low battery',
    r'(?:the\s+)?battery\s+(?:level\s+)?(?:reaches|hits)\s+(\d{1,2})\s*(?:%|percent)?',
  ]);

  static final _headsetOn = _event([
    '(?:plug|connect)(?:s|ged)?(?:\\s+in)?\\s+$_theMy$_headphones',
    '$_headphones(?:\\s+are|\\s+is)?\\s+(?:connected|plugged in|in)',
  ]);

  static final _headsetOff = _event([
    '(?:unplug|disconnect)(?:s|ged)?\\s+$_theMy$_headphones',
    '$_headphones(?:\\s+are|\\s+is)?\\s+(?:disconnected|unplugged|removed|out)',
  ]);

  static final _wifiOn = _event([
    '(?:connect(?:s|ed)?\\s+to|join(?:s|ed)?|get(?:s)?\\s+on)\\s+${_theMy}wi-?fi',
    r'wi-?fi\s+(?:is\s+)?(?:connected|on)',
  ]);

  static final _wifiOff = _event([
    '(?:disconnect(?:s|ed)?\\s+from|leave(?:s)?|lose(?:s)?)\\s+${_theMy}wi-?fi',
    r'wi-?fi\s+(?:is\s+)?(?:disconnected|off|lost)',
  ]);

  static final _airplaneOn = _event([
    r'(?:airplane|flight|aeroplane) mode\s+(?:is\s+)?(?:turned\s+)?on',
    r'(?:turn|switch)(?:s|ed)?\s+on\s+(?:airplane|flight|aeroplane) mode',
  ]);

  static final _airplaneOff = _event([
    r'(?:airplane|flight|aeroplane) mode\s+(?:is\s+)?(?:turned\s+)?off',
    r'(?:turn|switch)(?:s|ed)?\s+off\s+(?:airplane|flight|aeroplane) mode',
  ]);

  static final _booted = _event([
    r'(?:boots?|reboots?|restarts?)(?:\s+up)?|starts?\s+up',
    r'(?:(?:the|my)\s+)?(?:phone|device)\s+(?:turns?|powers?)\s+on',
  ]);

  static final _unlocked = _event([
    r'unlock(?:s|ed)?\s+(?:my\s+|the\s+)?(?:phone|screen|device)',
    r'(?:phone|screen|device)\s+(?:is\s+)?unlocked',
  ]);

  static final _interval = RegExp(
    r'(?:every|each)\s+(\d+|an?|one|two|three|four|six|twelve)\s*(minutes?|mins?|hours?|hrs?)\b'
    r'|\b(hourly)\b|\bevery hour\b',
  );

  /// Looks for what starts the flow. Null when the sentence names no trigger.
  static FoundTrigger? findTrigger(String text) {
    final lower = text.toLowerCase();

    final interval = _interval.firstMatch(lower);
    if (interval != null) {
      final minutes = _intervalMinutes(interval);
      return FoundTrigger(
        FlowTrigger.every(minutes.clamp(
          FlowTrigger.minInterval,
          FlowTrigger.maxInterval,
        )),
        _cut(text, interval),
      );
    }

    // Order matters: "unplug my earbuds" must not be read as the charger, so
    // the more specific headphone phrases are tried before the charger ones.
    final events = <(RegExp, FlowTrigger Function(RegExpMatch))>[
      (
        _headsetOff,
        (_) => const FlowTrigger.event(FlowTriggerKind.headsetDisconnected)
      ),
      (
        _headsetOn,
        (_) => const FlowTrigger.event(FlowTriggerKind.headsetConnected)
      ),
      (
        _chargerOff,
        (_) => const FlowTrigger.event(FlowTriggerKind.chargerDisconnected)
      ),
      (
        _chargerOn,
        (_) => const FlowTrigger.event(FlowTriggerKind.chargerConnected)
      ),
      (
        _batteryLow,
        (m) {
          final level = int.tryParse(m.group(1) ?? m.group(2) ?? '') ?? 20;
          return FlowTrigger.batteryLow(level.clamp(1, 99));
        }
      ),
      (
        _wifiOff,
        (_) => const FlowTrigger.event(FlowTriggerKind.wifiDisconnected)
      ),
      (_wifiOn, (_) => const FlowTrigger.event(FlowTriggerKind.wifiConnected)),
      (
        _airplaneOff,
        (_) => const FlowTrigger.event(FlowTriggerKind.airplaneOff)
      ),
      (_airplaneOn, (_) => const FlowTrigger.event(FlowTriggerKind.airplaneOn)),
      (
        _unlocked,
        (_) => const FlowTrigger.event(FlowTriggerKind.screenUnlocked)
      ),
      (_booted, (_) => const FlowTrigger.event(FlowTriggerKind.deviceBooted)),
    ];
    for (final (pattern, build) in events) {
      final match = pattern.firstMatch(lower);
      if (match != null) return FoundTrigger(build(match), _cut(text, match));
    }

    return _clockTrigger(text, lower);
  }

  static int _intervalMinutes(RegExpMatch match) {
    if (match.group(3) != null || match.group(0)!.contains('every hour')) {
      return 60;
    }
    final word = match.group(1)!;
    final count = int.tryParse(word) ??
        const {
          'a': 1,
          'an': 1,
          'one': 1,
          'two': 2,
          'three': 3,
          'four': 4,
          'six': 6,
          'twelve': 12,
        }[word] ??
        1;
    return match.group(2)!.startsWith('h') ? count * 60 : count;
  }

  static const _dayNames = {
    'monday': 1,
    'tuesday': 2,
    'wednesday': 3,
    'thursday': 4,
    'friday': 5,
    'saturday': 6,
    'sunday': 7,
  };

  static final _every = RegExp(
    r'\b(?:every|each)\s+(?:day|morning|evening|night|afternoon|weekday)|\bdaily\b|\bweekdays?\b|\bweekends?\b'
    r'|\bevery\s+(?:mon|tues|wednes|thurs|fri|satur|sun)day\b|\bon\s+(?:mon|tues|wednes|thurs|fri|satur|sun)days?\b',
  );

  static FoundTrigger? _clockTrigger(String text, String lower) {
    final every = _every.firstMatch(lower);
    // "at 7:30" with a minute or am/pm is a time; a bare "at 7" is accepted
    // only beside "every", so "at 2 in the park" is not read as 02:00.
    RegExpMatch? at;
    for (final m in RegExp(
      r'\bat\s+(\d{1,2})(?:[:.h](\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?\b',
    ).allMatches(lower)) {
      if (m.group(2) != null || m.group(3) != null || every != null) {
        at = m;
        break;
      }
    }
    if (every == null && at == null) {
      final loose = _loose(lower);
      if (loose == null) return null;
      return FoundTrigger(loose.$1, _cut(text, loose.$2));
    }

    var hour = 7;
    var minute = 30;
    final part = every?.group(0) ?? '';
    if (part.contains('evening')) {
      hour = 18;
      minute = 0;
    } else if (part.contains('night')) {
      hour = 22;
      minute = 0;
    } else if (part.contains('afternoon')) {
      hour = 14;
      minute = 0;
    }
    if (at != null) {
      hour = int.parse(at.group(1)!);
      minute = int.tryParse(at.group(2) ?? '0') ?? 0;
      final meridiem = at.group(3)?.replaceAll('.', '');
      if (meridiem == 'pm' && hour < 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
    }
    hour = hour.clamp(0, 23);
    minute = minute.clamp(0, 59);

    final days = <int>{};
    if (lower.contains('weekday')) days.addAll(const {1, 2, 3, 4, 5});
    if (lower.contains('weekend')) days.addAll(const {6, 7});
    for (final entry in _dayNames.entries) {
      if (lower.contains(entry.key) ||
          lower.contains('${entry.key.substring(0, 3)} ')) {
        days.add(entry.value);
      }
    }
    final trigger = days.isEmpty || days.length == 7
        ? FlowTrigger.daily(hour, minute)
        : FlowTrigger.weekly(hour, minute, days);

    var rest = text;
    for (final m in [at, every]) {
      if (m != null) rest = rest.replaceRange(m.start, m.end, ' ');
    }
    return FoundTrigger(trigger, _tidy(rest));
  }

  /// "tomorrow morning"-style phrases are not triggers; only "at 8am" alone
  /// (a time with am/pm or minutes, no "every") reaches here and is read as
  /// daily.
  static (FlowTrigger, RegExpMatch)? _loose(String lower) => null;

  /// Removes a match (and the words that led into it) from [text].
  static String _cut(String text, RegExpMatch match) => _tidy(
        text.replaceRange(match.start, match.end, ' '),
      );

  static String _tidy(String text) => text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s,.:;-]+|[\s,.:;-]+$'), '')
      .replaceFirst(
          RegExp(r'^(?:then|and|and then|please)\s+', caseSensitive: false), '')
      .trim();

  // ---- conditions -------------------------------------------------------

  static final _onlyBatteryBelow = RegExp(
    r'(?:only\s+)?(?:if|when|while)\s+(?:the\s+)?battery\s+(?:is\s+)?(?:below|under|less than)\s+(\d{1,3})\s*(?:%|percent)?',
  );
  static final _onlyBatteryAbove = RegExp(
    r'(?:only\s+)?(?:if|when|while)\s+(?:the\s+)?battery\s+(?:is\s+)?(?:above|over|more than)\s+(\d{1,3})\s*(?:%|percent)?',
  );
  static final _onlyCharging = RegExp(
    r'(?:only\s+)?(?:if|when|while)\s+(?:i(?:t)?(?:\s+is|\s+am|\s*[\x27’]s|\s*[\x27’]m)?\s+)?(?:(not)\s+)?charging',
  );
  static final _onlyWifi = RegExp(
    r'(?:only\s+)?(?:if|when|while)\s+(?:i(?:t)?(?:\s+is|\s+am)?\s+)?(?:(not|dis)\s*)?(?:connected to\s+)?wi-?fi(?:\s+is)?(?:\s+(?:connected|on))?',
  );
  static final _between = RegExp(
    r'(?:only\s+)?between\s+(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?\s+(?:and|to|-)\s+(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?',
  );
  static final _onlyDays = RegExp(
    r'(?:only\s+)?on\s+(weekdays|weekends)',
  );

  /// Reads "only if …" style conditions out of [text].
  static FoundConditions findConditions(String text) {
    final lower = text.toLowerCase();
    var rest = text;
    final found = <FlowCondition>[];

    void take(RegExp pattern, FlowCondition? Function(RegExpMatch) build) {
      final match = pattern.firstMatch(lower);
      if (match == null) return;
      final condition = build(match);
      if (condition == null) return;
      found.add(condition);
      // Blank the same span in a copy kept aligned with `lower`.
      rest = rest.replaceRange(
          match.start, match.end, ' ' * (match.end - match.start));
    }

    take(
        _onlyBatteryBelow,
        (m) =>
            FlowCondition.batteryBelow(int.parse(m.group(1)!).clamp(0, 100)));
    take(
        _onlyBatteryAbove,
        (m) =>
            FlowCondition.batteryAbove(int.parse(m.group(1)!).clamp(0, 100)));
    take(
        _onlyCharging,
        (m) => m.group(1) != null
            ? const FlowCondition(FlowConditionKind.notCharging)
            : const FlowCondition(FlowConditionKind.charging));
    take(_between, (m) {
      int minutes(String? h, String? mi, String? ap) {
        var hour = int.parse(h!);
        if (ap == 'pm' && hour < 12) hour += 12;
        if (ap == 'am' && hour == 12) hour = 0;
        return (hour.clamp(0, 23)) * 60 +
            (int.tryParse(mi ?? '0') ?? 0).clamp(0, 59);
      }

      // "between 9 and 5pm": a bare first hour borrows the second's am/pm.
      final firstAp = m.group(3) ?? m.group(6);
      return FlowCondition.timeBetween(
        minutes(m.group(1), m.group(2), firstAp),
        minutes(m.group(4), m.group(5), m.group(6)),
      );
    });
    take(
        _onlyDays,
        (m) => FlowCondition.weekdays(
              m.group(1) == 'weekdays' ? const {1, 2, 3, 4, 5} : const {6, 7},
            ));
    take(
        _onlyWifi,
        (m) => m.group(1) != null
            ? const FlowCondition(FlowConditionKind.wifiDisconnected)
            : const FlowCondition(FlowConditionKind.wifiConnected));

    return FoundConditions(
      found.take(FlowCondition.maxPerFlow).toList(),
      _tidy(rest),
    );
  }
}
