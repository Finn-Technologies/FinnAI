import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/features/flows/flow_templates.dart';

/// A flow read out of a sentence: which template, what goes in its slots and
/// when it runs. Deterministic on purpose: the small on-device model is not
/// asked to design a flow, only the app matches words to a template it knows.
class FlowIntent {
  const FlowIntent({
    required this.template,
    required this.slots,
    required this.trigger,
  });

  final FlowTemplate template;
  final Map<String, String> slots;
  final FlowTrigger trigger;

  static const _keywords = <String, List<String>>{
    'morning_brief': ['brief', 'briefing', 'news', 'headlines', 'weather'],
    'web_check': ['check', 'watch', 'monitor', 'track', 'price', 'latest'],
    'reminder': ['remind', 'reminder', 'remember', 'alarm', 'tell me to'],
  };

  /// Null when nothing in [text] points at a template.
  static FlowIntent? parse(String text) {
    final lower = text.toLowerCase();
    FlowTemplate? best;
    var bestScore = 0;
    for (final template in FlowTemplates.all) {
      var score = 0;
      for (final word in _keywords[template.id] ?? const <String>[]) {
        if (RegExp('\\b${RegExp.escape(word)}').hasMatch(lower)) score++;
      }
      if (score > bestScore) {
        best = template;
        bestScore = score;
      }
    }
    if (best == null) return null;
    return FlowIntent(
      template: best,
      slots: _slotsFor(best, text),
      trigger: _triggerFrom(lower, best.defaultTrigger),
    );
  }

  static Map<String, String> _slotsFor(FlowTemplate template, String text) {
    final cleaned = text
        .replaceAll(
            RegExp(r'\b(every|each)\s+\w+day\b', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'\bat\s+\d{1,2}([:.]\d{2})?\s*(am|pm)?\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final about = RegExp(r'\b(?:about|on|for|of)\s+(.+)$', caseSensitive: false)
        .firstMatch(cleaned)
        ?.group(1)
        ?.trim();
    final subject = (about != null && about.length > 2) ? about : cleaned;
    return switch (template.id) {
      'morning_brief' => {'topics': subject},
      'web_check' => {'topic': subject},
      'reminder' => {
          'message': cleaned
              .replaceFirst(
                RegExp(r'^(remind me to|remind me|tell me to)\s*',
                    caseSensitive: false),
                '',
              )
              .trim(),
        },
      _ => const {},
    };
  }

  static FlowTrigger _triggerFrom(String lower, FlowTrigger fallback) {
    var hour = fallback.hour;
    var minute = fallback.minute;
    final time = RegExp(r'\b(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?\b')
        .allMatches(lower)
        .map((m) => m)
        .where((m) => m.group(2) != null || m.group(3) != null)
        .firstOrNull;
    if (time != null) {
      hour = int.parse(time.group(1)!);
      minute = int.tryParse(time.group(2) ?? '0') ?? 0;
      final meridiem = time.group(3);
      if (meridiem == 'pm' && hour < 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
      hour = hour.clamp(0, 23);
      minute = minute.clamp(0, 59);
    }
    if (lower.contains('weekday')) {
      return FlowTrigger.weekly(hour, minute, const {1, 2, 3, 4, 5});
    }
    const names = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    final days = {
      for (final entry in names.entries)
        if (lower.contains(entry.key)) entry.value,
    };
    if (days.isNotEmpty && days.length < 7) {
      return FlowTrigger.weekly(hour, minute, days);
    }
    if (lower.contains('manual') || lower.contains('when i ask')) {
      return const FlowTrigger.manual();
    }
    return FlowTrigger.daily(hour, minute);
  }
}
