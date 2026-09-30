import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/features/flows/flow_scheduler.dart';

class _Backend implements FlowScheduleBackend {
  _Backend({this.allowed = true});

  bool allowed;
  bool grantOnRequest = true;
  int requests = 0;
  final scheduled = <String, (int, int, List<int>)>{};
  final cancelled = <String>[];
  final notified = <(String, String, String)>[];

  @override
  Future<bool> notificationsAllowed() async => allowed;

  @override
  Future<bool> requestNotifications() async {
    requests++;
    allowed = grantOnRequest;
    return allowed;
  }

  @override
  Future<void> schedule({
    required String flowId,
    required String name,
    required int hour,
    required int minute,
    required List<int> days,
  }) async =>
      scheduled[flowId] = (hour, minute, days);

  @override
  Future<void> cancel(String flowId) async {
    cancelled.add(flowId);
    scheduled.remove(flowId);
  }

  @override
  Future<void> cancelAll() async => scheduled.clear();

  @override
  Future<void> notify({
    required String flowId,
    required String title,
    required String body,
  }) async =>
      notified.add((flowId, title, body));

  @override
  Future<String?> takePendingFlow() async => null;
}

FinnFlow _flow(
  String id, {
  bool enabled = true,
  FlowTrigger trigger = const FlowTrigger.daily(7, 30),
}) =>
    FinnFlow(
      id: id,
      name: id,
      description: '',
      instructions: '',
      category: 'Automation',
      enabled: enabled,
      trigger: trigger,
      steps: const [FlowStep(kind: FlowStepKind.notify, text: 'hi')],
    );

void main() {
  test('arms enabled scheduled flows and nothing else', () async {
    final backend = _Backend();
    await FlowScheduler(backend: backend).sync([
      _flow('a'),
      _flow('b', enabled: false),
      _flow('c', trigger: const FlowTrigger.manual()),
      _flow('d', trigger: const FlowTrigger.weekly(9, 0, {5, 1})),
    ]);
    expect(backend.scheduled.keys.toSet(), {'a', 'd'});
    expect(backend.scheduled['d']!.$1, 9);
    expect(backend.scheduled['d']!.$2, 0);
    expect(backend.scheduled['d']!.$3, [1, 5], reason: 'days are sorted');
  });

  test('disabling or removing a flow disarms it', () async {
    final backend = _Backend();
    final scheduler = FlowScheduler(backend: backend);
    await scheduler.sync([_flow('a'), _flow('b')]);
    await scheduler.sync([_flow('a', enabled: false)]);
    expect(backend.scheduled, isEmpty);
    expect(backend.cancelled.toSet(), {'a', 'b'});
    expect(scheduler.armed, isEmpty);
  });

  test('without notification permission nothing is armed', () async {
    final backend = _Backend(allowed: false);
    final scheduler = FlowScheduler(backend: backend);
    await scheduler.sync([_flow('a')]);
    expect(backend.scheduled, isEmpty);
    expect(scheduler.armed, isEmpty);

    // Granting it later and syncing again arms the flow.
    backend.allowed = true;
    await scheduler.sync([_flow('a')]);
    expect(backend.scheduled.keys, ['a']);
  });

  test('revoking permission disarms what was armed', () async {
    final backend = _Backend();
    final scheduler = FlowScheduler(backend: backend);
    await scheduler.sync([_flow('a')]);
    backend.allowed = false;
    await scheduler.sync([_flow('a')]);
    expect(backend.scheduled, isEmpty);
  });

  test('syncing twice is idempotent', () async {
    final backend = _Backend();
    final scheduler = FlowScheduler(backend: backend);
    await scheduler.sync([_flow('a')]);
    await scheduler.sync([_flow('a')]);
    expect(backend.scheduled.keys, ['a']);
    expect(backend.cancelled, isEmpty);
  });

  test('ensurePermission asks once, and only when needed', () async {
    final allowed = _Backend();
    expect(await FlowScheduler(backend: allowed).ensurePermission(), isTrue);
    expect(allowed.requests, 0);

    final denied = _Backend(allowed: false)..grantOnRequest = false;
    expect(await FlowScheduler(backend: denied).ensurePermission(), isFalse);
    expect(denied.requests, 1);
  });

  test('notify passes the flow id, title and body through', () async {
    final backend = _Backend();
    await FlowScheduler(backend: backend)
        .notify(flowId: 'a', title: 'T', body: 'B');
    expect(backend.notified.single, ('a', 'T', 'B'));
  });
}
