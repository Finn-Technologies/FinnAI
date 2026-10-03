import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/features/flows/flow_scheduler.dart';

class _Backend implements FlowScheduleBackend {
  _Backend({this.allowed = true});

  bool allowed;
  bool grantOnRequest = true;
  int requests = 0;
  List<FlowTriggerSpec> alarms = const [];
  List<FlowTriggerSpec> events = const [];
  int syncs = 0;
  final notified = <(String, String, String)>[];

  Set<String> get alarmIds => {for (final a in alarms) a.flowId};
  Set<String> get eventIds => {for (final e in events) e.flowId};

  @override
  Future<bool> notificationsAllowed() async => allowed;

  @override
  Future<bool> requestNotifications() async {
    requests++;
    allowed = grantOnRequest;
    return allowed;
  }

  @override
  Future<void> sync({
    required List<FlowTriggerSpec> alarms,
    required List<FlowTriggerSpec> events,
  }) async {
    syncs++;
    this.alarms = alarms;
    this.events = events;
  }

  @override
  Future<void> cancelAll() async {
    alarms = const [];
    events = const [];
  }

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
  List<FlowTrigger> triggers = const [FlowTrigger.daily(7, 30)],
  List<FlowBlock> blocks = const [FlowBlock.notify('hi')],
  bool granted = false,
}) =>
    FinnFlow(
      id: id,
      name: id,
      description: '',
      instructions: '',
      category: 'Automation',
      enabled: enabled,
      triggers: triggers,
      blocks: blocks,
      granted: granted,
    );

void main() {
  test('arms enabled scheduled flows and nothing else', () async {
    final backend = _Backend();
    await FlowScheduler(backend: backend).sync([
      _flow('a'),
      _flow('b', enabled: false),
      _flow('c', triggers: const []),
      _flow('d', triggers: const [
        FlowTrigger.weekly(9, 0, {5, 1})
      ]),
    ]);
    expect(backend.alarmIds, {'a', 'd'});
    final d = backend.alarms.firstWhere((a) => a.flowId == 'd');
    expect(d.trigger.hour, 9);
    expect(d.trigger.minute, 0);
    expect(d.toMap()['days'], [1, 5], reason: 'days are sorted');
  });

  test('a flow with two times keeps two alarms', () async {
    final backend = _Backend();
    await FlowScheduler(backend: backend).sync([
      _flow(
        'a',
        triggers: const [FlowTrigger.daily(7, 0), FlowTrigger.daily(19, 0)],
      ),
    ]);
    expect(backend.alarms.map((a) => a.slot), [0, 1]);
  });

  test('device events go to the listener, not to an alarm', () async {
    final backend = _Backend();
    await FlowScheduler(backend: backend).sync([
      _flow(
        'a',
        triggers: const [FlowTrigger.event(FlowTriggerKind.chargerConnected)],
      ),
      _flow('b', triggers: const [FlowTrigger.batteryLow(15)]),
    ]);
    expect(backend.alarms, isEmpty);
    expect(backend.eventIds, {'a', 'b'});
    expect(backend.events.last.toMap()['level'], 15);
  });

  test('a repeating flow is an alarm with an interval', () async {
    final backend = _Backend();
    await FlowScheduler(backend: backend).sync([
      _flow('a', triggers: const [FlowTrigger.every(30)]),
    ]);
    expect(backend.alarms.single.toMap()['every'], 30);
  });

  test('a trigger may run unattended only when the flow may', () async {
    final backend = _Backend();
    const act = [
      FlowBlock.action('torch', {'on': 'true'})
    ];
    await FlowScheduler(backend: backend).sync([
      _flow('plain'),
      _flow('ungranted', blocks: act),
      _flow('granted', blocks: act, granted: true),
    ]);
    final auto = {for (final a in backend.alarms) a.flowId: a.auto};
    expect(auto, {'plain': true, 'ungranted': false, 'granted': true});
  });

  test('disabling or removing a flow disarms it', () async {
    final backend = _Backend();
    final scheduler = FlowScheduler(backend: backend);
    await scheduler.sync([_flow('a'), _flow('b')]);
    await scheduler.sync([_flow('a', enabled: false)]);
    expect(backend.alarms, isEmpty);
    expect(scheduler.armed, isEmpty);
  });

  test('without notification permission nothing is armed', () async {
    final backend = _Backend(allowed: false);
    final scheduler = FlowScheduler(backend: backend);
    await scheduler.sync([_flow('a')]);
    expect(backend.alarms, isEmpty);
    expect(scheduler.armed, isEmpty);

    // Granting it later and syncing again arms the flow.
    backend.allowed = true;
    await scheduler.sync([_flow('a')]);
    expect(backend.alarmIds, {'a'});
  });

  test('revoking permission disarms what was armed', () async {
    final backend = _Backend();
    final scheduler = FlowScheduler(backend: backend);
    await scheduler.sync([_flow('a')]);
    backend.allowed = false;
    await scheduler.sync([_flow('a')]);
    expect(backend.alarms, isEmpty);
  });

  test('a guide never arms anything', () async {
    final backend = _Backend();
    await FlowScheduler(backend: backend).sync([
      _flow('guide', blocks: const []),
    ]);
    expect(backend.alarms, isEmpty);
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
