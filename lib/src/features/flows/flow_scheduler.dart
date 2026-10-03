import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/features/flows/flow_ports.dart';

/// One trigger, as the platform needs to hear about it.
@immutable
class FlowTriggerSpec {
  const FlowTriggerSpec({
    required this.flowId,
    required this.slot,
    required this.name,
    required this.trigger,
    required this.auto,
  });

  final String flowId;

  /// Which of the flow's triggers this is, so a flow with a morning and an
  /// evening time keeps two alarms.
  final int slot;
  final String name;
  final FlowTrigger trigger;

  /// Whether the flow may run by itself when this fires. When false the
  /// platform only tells the user it is due and runs it when they tap.
  final bool auto;

  Map<String, Object?> toMap() => {
        'flowId': flowId,
        'slot': slot,
        'name': name,
        'kind': trigger.kind.name,
        'hour': trigger.hour,
        'minute': trigger.minute,
        'days': trigger.daysOfWeek.toList()..sort(),
        'every': trigger.intervalMinutes,
        'level': trigger.level,
        'auto': auto,
      };
}

/// The platform side of scheduling and notifying, as a narrow interface so the
/// service above it is tested with no plugin and no device.
abstract interface class FlowScheduleBackend {
  Future<bool> notificationsAllowed();

  /// Shows the system permission prompt if needed. True when allowed.
  Future<bool> requestNotifications();

  /// Makes the platform's alarms and event listeners exactly [alarms] and
  /// [events]. Everything not listed is removed, so calling it after any change
  /// (or at startup) is always safe.
  Future<void> sync({
    required List<FlowTriggerSpec> alarms,
    required List<FlowTriggerSpec> events,
  });

  Future<void> cancelAll();

  Future<void> notify({
    required String flowId,
    required String title,
    required String body,
  });

  /// The flow whose notification the user tapped to open the app, once.
  Future<String?> takePendingFlow();
}

/// Android: `AlarmManager`, a listener service and notifications, in
/// `FlowScheduler.kt` and `FlowTriggerService.kt`.
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
  Future<void> sync({
    required List<FlowTriggerSpec> alarms,
    required List<FlowTriggerSpec> events,
  }) =>
      _call<void>('sync', {
        'alarms': [for (final a in alarms) a.toMap()],
        'events': [for (final e in events) e.toMap()],
      });

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

/// Keeps the platform's alarms and event listeners in step with the flows the
/// user has enabled.
///
/// The store is the source of truth; [sync] makes the platform match it, so
/// calling it after any change (or at startup, or after a restore) is always
/// safe and never needs to know what changed.
class FlowScheduler implements FlowNotifier {
  FlowScheduler({FlowScheduleBackend? backend})
      : backend = backend ?? const MethodChannelFlowScheduleBackend();

  final FlowScheduleBackend backend;

  List<FlowTriggerSpec> _alarms = const [];
  List<FlowTriggerSpec> _events = const [];

  /// Flow ids with at least one alarm armed. Exposed for tests.
  @visibleForTesting
  Set<String> get armed => {for (final a in _alarms) a.flowId};

  /// Flow ids with at least one event listener armed. Exposed for tests.
  @visibleForTesting
  Set<String> get listening => {for (final e in _events) e.flowId};

  /// Arms every enabled automation's triggers and disarms everything else.
  ///
  /// Without notification permission nothing is armed: a trigger that cannot
  /// tell the user anything would fire invisibly. The flow stays enabled, and
  /// the page tells the user why it is quiet.
  Future<void> sync(List<FinnFlow> flows) async {
    final alarms = <FlowTriggerSpec>[];
    final events = <FlowTriggerSpec>[];
    for (final flow in flows) {
      if (!flow.enabled || !flow.isAutomation) continue;
      for (var slot = 0; slot < flow.triggers.length; slot++) {
        final trigger = flow.triggers[slot];
        if (!trigger.isScheduled && !trigger.isEvent) continue;
        final spec = FlowTriggerSpec(
          flowId: flow.id,
          slot: slot,
          name: flow.name,
          trigger: trigger,
          auto: flow.autoRunIsPermitted,
        );
        (trigger.isScheduled ? alarms : events).add(spec);
      }
    }
    final wanted = alarms.isNotEmpty || events.isNotEmpty;
    final allowed = !wanted || await backend.notificationsAllowed();
    _alarms = allowed ? alarms : const [];
    _events = allowed ? events : const [];
    await backend.sync(alarms: _alarms, events: _events);
  }

  /// Disarms every alarm and event listener, for "delete all data".
  Future<void> disarmAll() => sync(const []);

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
