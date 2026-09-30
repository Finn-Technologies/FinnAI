part of 'eval_prompts.dart';

/// One machine-checkable condition on a generated answer.
///
/// All checks run against the lower-cased answer unless [caseSensitive].
@immutable
class AnswerCheck {
  const AnswerCheck._(this._test, this.description, this._kind);

  /// Any one of [needles] appears in the answer.
  factory AnswerCheck.containsAny(
    List<String> needles, {
    bool caseSensitive = false,
  }) =>
      AnswerCheck._(
        (answer) => needles.any(
          (needle) => caseSensitive
              ? answer.contains(needle)
              : answer.toLowerCase().contains(needle.toLowerCase()),
        ),
        'contains any of ${needles.join(' | ')}',
        'contains_any',
      );

  /// Every one of [needles] appears in the answer.
  factory AnswerCheck.containsAll(
    List<String> needles, {
    bool caseSensitive = false,
  }) =>
      AnswerCheck._(
        (answer) => needles.every(
          (needle) => caseSensitive
              ? answer.contains(needle)
              : answer.toLowerCase().contains(needle.toLowerCase()),
        ),
        'contains all of ${needles.join(' | ')}',
        'contains_all',
      );

  /// The answer stays clear of the trap [needle].
  factory AnswerCheck.forbids(String needle, {bool caseSensitive = false}) =>
      AnswerCheck._(
        (answer) => caseSensitive
            ? !answer.contains(needle)
            : !answer.toLowerCase().contains(needle.toLowerCase()),
        'does not mention $needle',
        'forbids',
      );

  /// [pattern] matches the answer. Not case-insensitive by design: use
  /// inline flags for that.
  factory AnswerCheck.matches(RegExp pattern) => AnswerCheck._(
        (answer) => pattern.hasMatch(answer),
        'matches $pattern',
        'matches',
      );

  /// The answer is between [min] and [max] whitespace-separated words.
  factory AnswerCheck.wordCount(int min, int max) => AnswerCheck._(
        (answer) {
          final words = answer
              .split(RegExp(r'\s+'))
              .where((word) => word.trim().isNotEmpty)
              .length;
          return words >= min && words <= max;
        },
        'is $min-$max words',
        'word_count',
      );

  /// The answer carries at least [count] non-empty lines, i.e. it is a list
  /// or a set of steps rather than a single sentence.
  factory AnswerCheck.hasLines(int count) => AnswerCheck._(
        (answer) =>
            answer.split('\n').where((line) => line.trim().isNotEmpty).length >=
            count,
        'has $count or more lines',
        'has_lines',
      );

  /// A check written in Dart, for the assessments that already exist as
  /// functions (see `evaluation.dart`). [description] is what a failed run
  /// prints, so it has to say what was expected.
  factory AnswerCheck.satisfies(
    String description,
    bool Function(String answer) test,
  ) =>
      AnswerCheck._(
        test,
        description,
        'custom',
      );

  final bool Function(String answer) _test;
  final String description;
  final String _kind;

  /// True when [answer] satisfies this check. A crash inside the predicate is
  /// a failed check, never a crashed run.
  bool accepts(String answer) {
    try {
      return _test(answer);
    } catch (_) {
      return false;
    }
  }

  static AnswerCheck? _fromJson(Object? json) {
    if (json is! Map) return null;
    final map = json.cast<String, Object?>();
    final kind = map['check'];
    final caseSensitive = map['caseSensitive'] == true;
    List<String> strings(String key) {
      final value = map[key];
      if (value is List) {
        return value.whereType<String>().toList(growable: false);
      }
      return const [];
    }

    switch (kind) {
      case 'contains_any':
        final needles = strings('needles');
        return needles.isEmpty
            ? null
            : AnswerCheck.containsAny(needles, caseSensitive: caseSensitive);
      case 'contains_all':
        final needles = strings('needles');
        return needles.isEmpty
            ? null
            : AnswerCheck.containsAll(needles, caseSensitive: caseSensitive);
      case 'forbids':
        final needle = map['needle'];
        return needle is! String
            ? null
            : AnswerCheck.forbids(needle, caseSensitive: caseSensitive);
      case 'matches':
        final pattern = map['pattern'];
        if (pattern is! String) return null;
        try {
          return AnswerCheck.matches(RegExp(pattern));
        } on FormatException {
          return null;
        }
      case 'word_count':
        final min = map['min'];
        final max = map['max'];
        if (min is! int || max is! int) return null;
        return AnswerCheck.wordCount(min, max);
      case 'has_lines':
        final count = map['count'];
        return count is int ? AnswerCheck.hasLines(count) : null;
      default:
        return null;
    }
  }

  Map<String, Object?> toJson() => {'check': _kind, 'description': description};
}
