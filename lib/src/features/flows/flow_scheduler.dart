import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/features/flows/flow_ports.dart';

/// The platform side of scheduling and notifying, as a narrow interface so the
/// service above it is tested with no plugin and no device.
abstract interface class FlowScheduleBackend {
  Future<bool> notificationsAllowed();

  /// Shows the system permission prompt if needed. True when allowed.
  Future<bool> requestNotifications();

  Future<void> schedule({
    required String flowId,
    required String name,
    required int hour,
    required int minute,
    required List<int> days,
  });

  Future<void> cancel(String flowId);
  Future<void> cancelAll();

  Future<void> notify({
    required String flowId,
    required String title,
    required String body,
  });

  /// The flow whose notification the user tapped to open the app, once.
  Future<String?> takePendingFlow();
}

/// Android: `AlarmManager` + a notification, in `FlowScheduler.kt`.
class MethodChannelFlowScheduleBackend implements FlowScheduleBackend {
  const MethodChannelFlowScheduleBackend();

  static const MethodChannel channel = MethodChannel('finn_ai/flow_schedule');

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      // Not Android (or a test): scheduling simply is not available.
      return null;
    } on PlatformException catch (error) {
      debugPrint('FINN_FLOW_SCHEDULE $method failed: ${error.code}');
      return null;
    }
  }

  @override
  Future<bool> notificationsAllowed() async =>
      await _call<bool>('notificationsAllowed') ?? false;

  @override
  Future<bool> requestNotifications() async =>
      await _call<bool>('requestNotifications') ?? false;

  @override
  Future<void> schedule({
    required String flowId,
    required String name,
    required int hour,
    required int minute,
    required List<int> days,
  }) =>
      _call<void>('schedule', {
        'flowId': flowId,
        'name': name,
        'hour': hour,
        'minute': minute,
        'days': days,
      });

  @override
  Future<void> cancel(String flowId) =>
      _call<void>('cancel', {'flowId': flowId});

  @override
  Future<void> cancelAll() => _call<void>('cancelAll');

  @override
  Future<void> notify({
    required String flowId,
    required String title,
    required String body,
  }) =>
      _call<void>('notify', {'flowId': flowId, 'title': title, 'body': body});

  @override
  Future<String?> takePendingFlow() => _call<String>('takePendingFlow');
}

/// Keeps the platform alarms in step with the flows the user has enabled.
///
/// The store is the source of truth; [sync] makes the alarms match it, so
/// calling it after any change (or at startup, or after a restore) is always
/// safe and never needs to know what changed.
class FlowScheduler implements FlowNotifier {
  FlowScheduler({FlowScheduleBackend? backend})
      : backend = backend ?? const MethodChannelFlowScheduleBackend();

  final FlowScheduleBackend backend;

  final Set<String> _armed = {};

  /// Ids currently armed. Exposed for tests.
  @visibleForTesting
  Set<String> get armed => Set.unmodifiable(_armed);

  /// Arms every enabled, scheduled flow and disarms everything else.
  ///
  /// Without notification permission nothing is armed: an alarm that cannot
  /// tell the user anything would fire invisibly. The flow stays enabled, and
  /// the page tells the user why it is quiet.
  Future<void> sync(List<FinnFlow> flows) async {
    final wanted = {
      for (final flow in flows)
        if (flow.enabled && flow.trigger.isScheduled) flow.id: flow,
    };
    final allowed = wanted.isEmpty || await backend.notificationsAllowed();
    final target = allowed ? wanted : const <String, FinnFlow>{};

    for (final id in _armed.difference(target.keys.toSet())) {
      await backend.cancel(id);
    }
    for (final flow in target.values) {
      await backend.schedule(
        flowId: flow.id,
        name: flow.name,
        hour: flow.trigger.hour,
        minute: flow.trigger.minute,
        days: flow.trigger.daysOfWeek.toList()..sort(),
      );
    }
    _armed
      ..clear()
      ..addAll(target.keys);
  }

  /// Asks for notification permission, explaining nothing itself: the caller
  /// shows its own reason first, because the system prompt has none.
  Future<bool> ensurePermission() async {
    if (await backend.notificationsAllowed()) return true;
    return backend.requestNotifications();
  }

  @override
  Future<void> notify({
    required String flowId,
    required String title,
    required String body,
  }) =>
      backend.notify(flowId: flowId, title: title, body: body);
}
