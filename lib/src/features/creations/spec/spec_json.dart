/// Lenient readers for decoded spec JSON.
///
/// These are only reached after [SpecValidator] has accepted the payload, so
/// they exist to fail loudly on a programming error rather than to produce
/// user-facing messages. The thrown [FormatException] text is still written to
/// be understood by a model in a repair prompt, because the pipeline also feeds
/// it back when construction fails after a lenient validation pass.
abstract final class SpecJson {
  static String string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw FormatException('"$key" is required and must be text');
  }

  static String stringOr(
    Map<String, Object?> json,
    String key,
    String fallback,
  ) {
    final value = json[key];
    return value is String ? value.trim() : fallback;
  }

  static int intOr(Map<String, Object?> json, String key, int fallback) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static Map<String, Object?> object(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is Map) return Map<String, Object?>.from(value);
    throw FormatException('"$key" is required and must be an object');
  }

  static List<String> stringList(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! List) {
      throw FormatException('"$key" is required and must be a list');
    }
    return value
        .where((item) => item != null)
        .map((item) => '$item'.trim())
        .toList(growable: false);
  }

  static List<Map<String, Object?>> objectList(
    Map<String, Object?> json,
    String key,
  ) {
    final value = json[key];
    if (value is! List) {
      throw FormatException('"$key" is required and must be a list');
    }
    return value
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }

  static Object? raw(Map<String, Object?> json, String key) => json[key];
}
