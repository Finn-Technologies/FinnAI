import 'dart:convert';

import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/actions/action_matcher.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';

/// Reads a device action out of model output.
///
/// The model is the fallback for requests the deterministic matcher cannot
/// resolve, so this stays forgiving about framing and strict about meaning: an
/// unknown action name or a missing required argument returns null rather than
/// guessing, and every value is re-normalized against the catalog so a
/// plausible-but-wrong slot never reaches the executor.
class DeviceActionParser {
  const DeviceActionParser();

  DeviceActionInvocation? parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final candidates = <String>[
      ...RegExp(
        r'<tool_call>([\s\S]*?)(?:</tool_call>|$)',
        caseSensitive: false,
      ).allMatches(value).map((m) => m.group(1)!.trim()),
      ...RegExp(r'\{[\s\S]*\}').allMatches(value).map((m) => m.group(0)!),
    ];

    for (final candidate in candidates) {
      DeviceActionInvocation? invocation;
      try {
        invocation = _parseToolCall(candidate);
      } catch (_) {
        // Malformed model output is a normal event, not an exception: fall
        // through to plain text rather than taking the turn down.
        invocation = null;
      }
      if (invocation != null) return invocation;
    }
    return null;
  }

  DeviceActionInvocation? _parseToolCall(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;

    final name = decoded['name']?.toString();
    if (name == null) return null;
    final action = DeviceActionCatalog.byName(name);
    if (action == null) return null;

    final rawArguments = decoded['arguments'];
    final arguments = rawArguments is Map
        ? rawArguments.map((k, v) => MapEntry(k.toString(), v))
        : const <String, Object?>{};

    final resolved = _resolveArguments(action, arguments);
    if (resolved == null) return null;
    return DeviceActionInvocation(action: action, arguments: resolved);
  }

  static Map<String, Object?>? _resolveArguments(
    DeviceAction action,
    Map<String, Object?> arguments,
  ) {
    final resolved = <String, Object?>{};
    for (final param in action.params) {
      final value = _normalize(param, arguments[param.name]);
      if (value == null) {
        if (param.required) return null;
        continue;
      }
      resolved[param.name] = value;
    }
    return resolved;
  }

  static Object? _normalize(DeviceActionParam param, Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    switch (param.type) {
      case DeviceActionParamType.integer:
        final value = _parseInteger(text);
        if (value == null) return null;
        return switch (param.name) {
          'hour' => value >= 0 && value <= 23 ? value : null,
          'minute' => value >= 0 && value <= 59 ? value : null,
          'seconds' => value > 0 && value <= 86400 ? value : null,
          _ => value,
        };
      case DeviceActionParamType.boolean:
        final lowered = text.toLowerCase();
        if (['true', 'on', 'yes', '1', 'enable'].contains(lowered)) return true;
        if (['false', 'off', 'no', '0', 'disable'].contains(lowered)) {
          return false;
        }
        return null;
      case DeviceActionParamType.text:
        if (param.name == 'screen') {
          final normalized =
              text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
          // The directive hands the model canonical ids such as "date_time"
          // and "system"; screenFor only knows human aliases, so "system" and
          // "home" used to be rejected outright.
          final id = normalized.replaceAll(' ', '_');
          if (DeviceActionCatalog.isValidSettingsScreen(id)) return id;
          return DeviceActionMatcher.screenFor(normalized);
        }
        if (param.name == 'direction') {
          final lowered = text.toLowerCase();
          if (['up', 'down', 'mute'].contains(lowered)) return lowered;
          return null;
        }
        if (param.name == 'action') {
          final lowered = text.toLowerCase();
          if (['play', 'pause', 'next', 'previous'].contains(lowered)) {
            return lowered;
          }
          return null;
        }
        return text.length > 200 ? text.substring(0, 200) : text;
      case DeviceActionParamType.time:
      case DeviceActionParamType.duration:
      case DeviceActionParamType.list:
        return text;
    }
  }

  /// Whole numbers and decimals only. `double.toInt()` throws on Infinity and
  /// NaN, and "NaN" is valid text a model can emit, so non-finite values have to
  /// be rejected here rather than crashing the turn.
  static int? _parseInteger(String text) {
    final asInt = int.tryParse(text);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(text);
    if (asDouble == null || !asDouble.isFinite || asDouble.abs() > 1e15) {
      return null;
    }
    return asDouble.toInt();
  }
}
