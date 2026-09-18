import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/actions/action_catalog.dart';

/// How an action reaches the device.
///
/// [execute] fires an intent that really performs the task (an alarm, a timer,
/// media transport). [open] can only raise the right system screen: Android
/// forbids third-party apps from toggling radio state, so navigation is the
/// honest implementation for those, not a fallback.
enum DeviceActionTier { execute, open }

enum DeviceActionParamType { text, integer, boolean, time, duration, list }

@immutable
class DeviceActionParam {
  const DeviceActionParam({
    required this.name,
    required this.type,
    this.required = true,
    this.description = '',
  });

  final String name;
  final DeviceActionParamType type;
  final bool required;
  final String description;
}

/// One thing Finn can do to the device.
@immutable
class DeviceAction {
  const DeviceAction({
    required this.name,
    required this.tier,
    required this.summary,
    this.params = const [],
    this.phrases = const [],
  });

  final String name;
  final DeviceActionTier tier;

  /// One line for the prompt contract, written for a 1.6B model.
  final String summary;

  final List<DeviceActionParam> params;

  /// Trigger words for the deterministic matcher. A request that matches one of
  /// these is resolved without a model pass at all.
  final List<String> phrases;

  bool get producesStateChange => tier == DeviceActionTier.execute;
}

/// A resolved action: the catalog entry plus the arguments it will run with.
@immutable
class DeviceActionInvocation {
  const DeviceActionInvocation({
    required this.action,
    this.arguments = const {},
  });

  final DeviceAction action;
  final Map<String, Object?> arguments;

  String? argument(String name) => arguments[name]?.toString();

  int? intArgument(String name) {
    final value = arguments[name];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool boolArgument(String name) {
    final value = arguments[name];
    if (value is bool) return value;
    final text = value?.toString().toLowerCase();
    return text == 'true' || text == 'yes' || text == '1';
  }

  DeviceActionInvocation copyWith({Map<String, Object?>? arguments}) =>
      DeviceActionInvocation(
        action: action,
        arguments: arguments ?? this.arguments,
      );

  Map<String, Object?> toJson() => {
        'name': action.name,
        'arguments': arguments,
      };

  /// Null when the stored action is no longer in the catalog, so a reply that
  /// proposed something since removed degrades to plain text instead of
  /// rendering a card that cannot run.
  static DeviceActionInvocation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final action = DeviceActionCatalog.byName(raw['name']?.toString() ?? '');
    if (action == null) return null;
    final arguments = raw['arguments'];
    return DeviceActionInvocation(
      action: action,
      arguments: arguments is Map
          ? arguments.map((k, v) => MapEntry(k.toString(), v))
          : const {},
    );
  }
}

enum DeviceActionOutcome { performed, opened, unavailable, failed }

/// What came back from the platform.
///
/// Deliberately carries no user-facing sentence: the outcome plus a resolved
/// proper noun (an app label, a settings screen) is enough for the UI to build a
/// localized line, which keeps every translated string in `L10n`.
@immutable
class DeviceActionResult {
  const DeviceActionResult({
    required this.outcome,
    this.detail = '',
    this.error = '',
  });

  const DeviceActionResult.unavailable({this.detail = '', this.error = ''})
      : outcome = DeviceActionOutcome.unavailable;

  const DeviceActionResult.failed({this.error = '', this.detail = ''})
      : outcome = DeviceActionOutcome.failed;

  const DeviceActionResult.opened({this.detail = ''})
      : outcome = DeviceActionOutcome.opened,
        error = '';

  const DeviceActionResult.performed({this.detail = ''})
      : outcome = DeviceActionOutcome.performed,
        error = '';

  final DeviceActionOutcome outcome;

  /// A resolved proper noun from the device — an app name, a settings screen.
  final String detail;

  /// Technical failure text, shown only alongside a localized message.
  final String error;

  bool get isSuccess =>
      outcome == DeviceActionOutcome.performed ||
      outcome == DeviceActionOutcome.opened;
}
