import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';

/// Resolves a request against the catalog without a model.
///
/// The requests this feature exists for are highly predictable — "set an alarm
/// for 7am", "turn on wifi" — and a 1.6B model is both slower and less reliable
/// at them than a direct match. Anything this cannot resolve confidently returns
/// null and falls through to the model pass, so under-matching is safe and
/// over-matching is not.
class DeviceActionMatcher {
  const DeviceActionMatcher({this.now});

  /// Injectable clock so "next 7am" is deterministic under test.
  final DateTime? now;

  static final _numberWords = <String, int>{
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'forty five': 45,
    'fifty': 50,
    'sixty': 60,
    'ninety': 90,
  };

  /// Matched only when no specific screen is named, so "wifi settings" resolves
  /// to Wi-Fi rather than to the settings home.
  static const _genericSettingsAliases = <String>[
    'system settings',
    'settings',
  ];

  static const _screenAliases = <String, String>{
    'wi fi': DeviceSettingsScreens.wifi,
    'wifi': DeviceSettingsScreens.wifi,
    'wireless': DeviceSettingsScreens.wifi,
    'wlan': DeviceSettingsScreens.wifi,
    'bluetooth': DeviceSettingsScreens.bluetooth,
    'bt': DeviceSettingsScreens.bluetooth,
    'airplane': DeviceSettingsScreens.airplane,
    'airplane mode': DeviceSettingsScreens.airplane,
    'aeroplane': DeviceSettingsScreens.airplane,
    'flight mode': DeviceSettingsScreens.airplane,
    'flight': DeviceSettingsScreens.airplane,
    'hotspot': DeviceSettingsScreens.hotspot,
    'tethering': DeviceSettingsScreens.hotspot,
    'mobile data': DeviceSettingsScreens.mobileData,
    'mobile network': DeviceSettingsScreens.mobileData,
    'cellular': DeviceSettingsScreens.mobileData,
    'battery usage': DeviceSettingsScreens.batteryUsage,
    'battery saver': DeviceSettingsScreens.batterySaver,
    'power saving': DeviceSettingsScreens.batterySaver,
    'power saver': DeviceSettingsScreens.batterySaver,
    'battery': DeviceSettingsScreens.batterySaver,
    'do not disturb': DeviceSettingsScreens.dnd,
    'dnd': DeviceSettingsScreens.dnd,
    'silent': DeviceSettingsScreens.dnd,
    'brightness': DeviceSettingsScreens.display,
    'display': DeviceSettingsScreens.display,
    'screen': DeviceSettingsScreens.display,
    'sound': DeviceSettingsScreens.sound,
    'audio': DeviceSettingsScreens.sound,
    'ringtone': DeviceSettingsScreens.sound,
    'location': DeviceSettingsScreens.location,
    'gps': DeviceSettingsScreens.location,
    'storage': DeviceSettingsScreens.storage,
    'date and time': DeviceSettingsScreens.dateTime,
    'time zone': DeviceSettingsScreens.dateTime,
    'date': DeviceSettingsScreens.dateTime,
    'keyboard': DeviceSettingsScreens.keyboard,
    'language': DeviceSettingsScreens.language,
    'accessibility': DeviceSettingsScreens.accessibility,
    'applications': DeviceSettingsScreens.applications,
    'apps': DeviceSettingsScreens.applications,
    'nfc': DeviceSettingsScreens.nfc,
    'screen mirroring': DeviceSettingsScreens.cast,
    'screencast': DeviceSettingsScreens.cast,
    'cast': DeviceSettingsScreens.cast,
    'vpn': DeviceSettingsScreens.vpn,
    'developer options': DeviceSettingsScreens.developer,
    'developer': DeviceSettingsScreens.developer,
    'launcher': DeviceSettingsScreens.home,
  };

  /// Longest word first so "forty five" wins over "forty", and boundaries so
  /// "sixteen" is not read as "six". Both were wrong before, which turned
  /// "forty five minutes" into five and dropped the teens entirely.
  static final RegExp _numberWordPattern = RegExp(
    '\\b(?:${(_numberWords.keys.toList()..sort((a, b) => b.length.compareTo(a.length))).map(RegExp.escape).join('|')})\\b',
  );

  static final _urlPattern = RegExp(
    r'\b(?:https?://\S+|\S+\.(?:com|org|net|io|dev|co|gov|edu|ai)\b\S*)',
  );

  DeviceActionInvocation? match(String request) {
    final text = request.trim().toLowerCase();
    if (text.isEmpty) return null;
    final words = _normalize(text);

    return _matchTorch(text) ??
        _matchAlarm(text) ??
        _matchShowAlarms(words) ??
        _matchTimer(text) ??
        _matchMedia(words) ??
        _matchVolume(words) ??
        _matchCamera(words) ??
        _matchNavigate(text) ??
        _matchOpenUrl(text) ??
        _matchDial(text) ??
        _matchSettings(words) ??
        _matchOpenApp(text, words);
  }

  static String _normalize(String text) => text
      .replaceAll(RegExp(r'[^a-z0-9:]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Off only when the negation sits next to the torch word. Scanning the whole
  /// sentence turned "turn on the flashlight, the power is off" into an off
  /// command.
  static bool _torchWantsOff(String text) {
    final beforeTorch = RegExp(
      r'\b(?:off|disable|disabled|stop|stopped|kill)\b'
      r'(?:\s+\w+){0,3}\s+(?:flashlight|torch)\b',
    );
    final afterTorch = RegExp(
      r'\b(?:flashlight|torch)\b'
      r'(?:\s+\w+){0,3}\s+(?:off|disable|disabled|stop|stopped|kill)\b',
    );
    return beforeTorch.hasMatch(text) || afterTorch.hasMatch(text);
  }

  DeviceActionInvocation? _matchTorch(String text) {
    if (!RegExp(r'\b(flashlight|torch)\b').hasMatch(text)) return null;
    return DeviceActionInvocation(
      action: DeviceActionCatalog.torch,
      arguments: {'on': !_torchWantsOff(text)},
    );
  }

  DeviceActionInvocation? _matchAlarm(String text) {
    final mentionsAlarm = RegExp(r'\b(alarm|wake me|wake up)\b').hasMatch(text);
    if (!mentionsAlarm) return null;
    final time = _parseClockTime(text);
    if (time == null) return null;
    final label = _matchQuotedLabel(text);
    return DeviceActionInvocation(
      action: DeviceActionCatalog.setAlarm,
      arguments: {
        'hour': time.hour,
        'minute': time.minute,
        if (label != null) 'label': label,
      },
    );
  }

  /// [DeviceActionCatalog.showAlarms] declares these phrases but nothing
  /// produced it, so "show my alarms" could only ever reach the model.
  DeviceActionInvocation? _matchShowAlarms(String words) {
    final mentions = RegExp(
      r'\b(?:show|list|view|see|open|check)\b(?:\s+\w+){0,2}\s+alarms?\b'
      r'|\bmy alarms?\b',
    ).hasMatch(words);
    if (!mentions) return null;
    return const DeviceActionInvocation(action: DeviceActionCatalog.showAlarms);
  }

  DeviceActionInvocation? _matchTimer(String text) {
    if (!RegExp(r'\b(timer|countdown)\b').hasMatch(text)) return null;
    final seconds = _parseDuration(text);
    if (seconds == null || seconds <= 0 || seconds > 86400) return null;
    return DeviceActionInvocation(
      action: DeviceActionCatalog.setTimer,
      arguments: {'seconds': seconds},
    );
  }

  DeviceActionInvocation? _matchMedia(String words) {
    final action = RegExp(
      r'\b(play|pause|resume|next|skip|previous|prev)\b',
    ).firstMatch(words)?.group(1);
    if (action == null) return null;
    final mediaish = RegExp(
      r'\b(music|song|track|media|playback|audio|video)\b',
    ).hasMatch(words);
    if (!mediaish) return null;
    final resolved = switch (action) {
      'play' || 'resume' => 'play',
      'pause' => 'pause',
      'next' || 'skip' => 'next',
      _ => 'previous',
    };
    return DeviceActionInvocation(
      action: DeviceActionCatalog.media,
      arguments: {'action': resolved},
    );
  }

  DeviceActionInvocation? _matchVolume(String words) {
    final mentionsVolume = RegExp(r'\bvolume\b').hasMatch(words);
    final louder = RegExp(r'\b(louder|volume up)\b').hasMatch(words);
    final quieter = RegExp(r'\b(quieter|volume down)\b').hasMatch(words);
    final mute =
        mentionsVolume && RegExp(r'\b(mute|silence)\b').hasMatch(words);
    if (!louder && !quieter && !mute) return null;
    final direction = mute
        ? 'mute'
        : louder
            ? 'up'
            : 'down';
    return DeviceActionInvocation(
      action: DeviceActionCatalog.volume,
      arguments: {'direction': direction},
    );
  }

  DeviceActionInvocation? _matchCamera(String words) {
    if (!RegExp(r'\b(camera|photo|picture|selfie)\b').hasMatch(words)) {
      return null;
    }
    if (!RegExp(r'\b(take|open|launch|snap|capture)\b').hasMatch(words)) {
      return null;
    }
    return const DeviceActionInvocation(action: DeviceActionCatalog.takePhoto);
  }

  DeviceActionInvocation? _matchNavigate(String text) {
    final match = RegExp(
      r'\b(?:navigate to|directions to|take me to|route to)\s+(.{2,80})$',
    ).firstMatch(text);
    final destination = match?.group(1)?.trim();
    if (destination == null || destination.isEmpty) return null;
    return DeviceActionInvocation(
      action: DeviceActionCatalog.navigate,
      arguments: {'query': destination},
    );
  }

  /// A bare "open website example.com" used to fall through to
  /// [DeviceActionCatalog.openApp] with the whole phrase as an app name.
  DeviceActionInvocation? _matchOpenUrl(String text) {
    if (!RegExp(r'\b(?:open|browse|visit|go to|load)\b').hasMatch(text)) {
      return null;
    }
    final url = _urlPattern.firstMatch(text)?.group(0);
    if (url == null) return null;
    return DeviceActionInvocation(
      action: DeviceActionCatalog.openUrl,
      arguments: {'url': url},
    );
  }

  DeviceActionInvocation? _matchDial(String text) {
    final match = RegExp(
      r'\b(?:call|dial)\s+([+0-9][0-9\s\-()]{5,20})',
    ).firstMatch(text);
    final digits = match?.group(1)?.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits == null || digits.length < 6) return null;
    return DeviceActionInvocation(
      action: DeviceActionCatalog.dial,
      arguments: {'number': digits},
    );
  }

  DeviceActionInvocation? _matchSettings(String words) {
    final screen = screenFor(words);
    if (screen == null) return null;
    return DeviceActionInvocation(
      action: DeviceActionCatalog.openSettings,
      arguments: {'screen': screen},
    );
  }

  DeviceActionInvocation? _matchOpenApp(String text, String words) {
    final match = RegExp(
      r'\b(?:open|launch|start)\s+(.{2,40})$',
    ).firstMatch(text);
    final name = match?.group(1)?.trim();
    if (name == null || name.isEmpty) return null;
    if (screenFor(_normalize(name)) != null) return null;
    if (RegExp(r'\b(url|http|www)\b').hasMatch(name)) return null;
    return DeviceActionInvocation(
      action: DeviceActionCatalog.openApp,
      arguments: {'name': name},
    );
  }

  /// Longest alias wins so "battery usage" beats "battery", and
  /// "mobile data" beats a bare noun. Shared with the model parser so a screen
  /// named either way resolves to the same id.
  static String? screenFor(String words) {
    String? best;
    var bestLength = 0;
    for (final entry in _screenAliases.entries) {
      if (entry.key.length <= bestLength) continue;
      if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(words)) {
        best = entry.value;
        bestLength = entry.key.length;
      }
    }
    if (best != null) return best;
    for (final alias in _genericSettingsAliases) {
      if (RegExp('\\b${RegExp.escape(alias)}\\b').hasMatch(words)) {
        return DeviceSettingsScreens.system;
      }
    }
    return null;
  }

  static String? _matchQuotedLabel(String text) {
    final match = RegExp(
      r'''["'\u201c]([^"'\u201d]{1,40})["'\u201d]''',
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  ({int hour, int minute})? _parseClockTime(String text) {
    final match = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm|a m|p m)?\b',
    ).firstMatch(text);
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    if (hour > 23 || minute > 59) return null;

    var meridiem = match.group(3)?.replaceAll(' ', '');
    if (meridiem == null) {
      if (RegExp(r'\b(morning|wake me|wake up|breakfast)\b').hasMatch(text)) {
        meridiem = 'am';
      } else if (RegExp(
        r'\b(evening|tonight|night|afternoon|dinner)\b',
      ).hasMatch(text)) {
        meridiem = 'pm';
      }
    }

    if (meridiem == 'am') {
      if (hour == 12) hour = 0;
    } else if (meridiem == 'pm') {
      if (hour < 12) hour += 12;
    } else if (hour >= 1 && hour < 12) {
      // No meridiem: an alarm at "7" means the next 7 o'clock, not whichever
      // one happened to be written. 0 is excluded because "0:30" is half past
      // midnight; rolling it forward produced a 12:30 noon alarm.
      final reference = now ?? DateTime.now();
      hour = hour <= reference.hour ? hour + 12 : hour;
    }
    return (hour: hour, minute: minute);
  }

  int? _parseDuration(String text) {
    final normalized = text.replaceAllMapped(
      _numberWordPattern,
      (m) => ' ${_numberWords[m.group(0)]} ',
    );

    var total = 0;
    var matched = false;
    final pattern = RegExp(
      r'(\d+)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)\b',
    );
    for (final match in pattern.allMatches(normalized)) {
      final value = int.tryParse(match.group(1)!);
      // A digit run too long for an int, or absurdly large, must decline rather
      // than overflow into a nonsense duration.
      if (value == null || value > 86400) return null;
      final unit = match.group(2)!;
      matched = true;
      if (unit.startsWith('h')) {
        total += value * 3600;
      } else if (unit.startsWith('m')) {
        total += value * 60;
      } else {
        total += value;
      }
    }
    return matched ? total : null;
  }
}
