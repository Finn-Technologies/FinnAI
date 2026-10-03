import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/flows/flow_scheduler.dart';
import 'package:finn_ai/src/features/flows/flows_page.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

class _Backend implements FlowScheduleBackend {
  _Backend({this.allowed = true});

  bool allowed;
  int requests = 0;
  List<FlowTriggerSpec> alarms = const [];
  List<FlowTriggerSpec> events = const [];

  @override
  Future<bool> notificationsAllowed() async => allowed;

  @override
  Future<bool> requestNotifications() async {
    requests++;
    allowed = true;
    return allowed;
  }

  @override
  Future<void> sync({
    required List<FlowTriggerSpec> alarms,
    required List<FlowTriggerSpec> events,
  }) async {
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
  }) async {}

  @override
  Future<String?> takePendingFlow() async => null;
}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late FlowsStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_automations_');
    store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester, _Backend backend) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: FlowsPage(
          onBack: () {},
          store: store,
          scheduler: FlowScheduler(backend: backend),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpFor(WidgetTester tester, [int ms = 500]) async {
    await tester.pump();
    await tester.pump(Duration(milliseconds: ms));
  }

  /// Taps a key after scrolling it into view: the live test window is not the
  /// phone-sized one, and a long chart can sit below the fold.
  Future<void> tapKey(WidgetTester tester, String key) async {
    var finder = find.byKey(Key(key));
    // A control narrower than its slot (a chip) is hit at the chip, not at the
    // middle of the row it sits in.
    final inner = find.descendant(of: finder, matching: find.byType(InkWell));
    if (inner.evaluate().isNotEmpty) finder = inner.first;
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(finder);
  }

  Future<void> fillMorningBrief(WidgetTester tester) async {
    await tapKey(tester, 'add-flow-button');
    await pumpFor(tester, 400);
    await tapKey(tester, 'flow-new-template');
    await pumpFor(tester);
    await tapKey(tester, 'flow-template-morning_brief');
    await pumpFor(tester);
    await tester.enterText(
      find.byKey(const Key('flow-slot-topics')),
      'football and tech',
    );
    await tester.enterText(find.byKey(const Key('flow-slot-city')), 'Rome');
    await tester.pump();
  }

  testWidgets('a morning brief is created from a template and scheduled', (
    tester,
  ) async {
    final backend = _Backend();
    await open(tester, backend);
    expect(find.text('No flows yet'), findsOneWidget);

    await fillMorningBrief(tester);
    await tapKey(tester, 'flow-automation-save');
    await settle(tester);

    final flow = store.flows.singleWhere((f) => f.name == 'Morning brief');
    expect(flow.blocks.map((b) => b.kind), [
      FlowBlockKind.web,
      FlowBlockKind.web,
      FlowBlockKind.ask,
      FlowBlockKind.notify,
      FlowBlockKind.saveToChat,
    ]);
    expect(flow.trigger.isScheduled, isTrue);
    expect(flow.trigger.hour, 7);
    expect(flow.trigger.minute, 30);
    expect(flow.enabled, isTrue);
    expect(backend.alarms.single.flowId, flow.id,
        reason: 'the alarm is armed once the flow is saved');
    // The flowchart opens on the new flow.
    expect(find.byKey(const Key('flow-trigger-0')), findsOneWidget);
    expect(find.textContaining('Every day at 07:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without notification permission it explains, then asks', (
    tester,
  ) async {
    final backend = _Backend(allowed: false);
    await open(tester, backend);

    await fillMorningBrief(tester);
    await tapKey(tester, 'flow-automation-save');
    await pumpFor(tester);

    // Our own reason first; the system prompt has none.
    expect(find.text('Allow notifications?'), findsOneWidget);
    expect(backend.requests, 0);
    await tester.tap(find.text('Allow'));
    await settle(tester);

    expect(backend.requests, 1);
    expect(backend.alarms, isNotEmpty);
  });

  testWidgets('a trigger is added from the chart and arms the listener', (
    tester,
  ) async {
    final backend = _Backend();
    await store.upsertCustom(
      id: null,
      name: 'Torch',
      description: '',
      blocks: const [FlowBlock.notify('hi')],
    );
    await open(tester, backend);

    await tester.tap(find.text('Torch').first);
    await pumpFor(tester);
    await tapKey(tester, 'flow-add-trigger');
    await pumpFor(tester);
    await tapKey(tester, 'trigger-kind-chargerConnected');
    await settle(tester);

    final flow = store.flows.singleWhere((f) => f.name == 'Torch');
    expect(flow.triggers.single.kind, FlowTriggerKind.chargerConnected);
    expect(find.text('Charger connected'), findsOneWidget);
    expect(backend.events.single.flowId, flow.id);
    expect(backend.alarms, isEmpty);
  });

  testWidgets('a step is added at a "+" and saved at once', (tester) async {
    final backend = _Backend();
    await store.upsertCustom(
      id: null,
      name: 'Note',
      description: '',
      blocks: const [FlowBlock.notify('first')],
    );
    await open(tester, backend);

    await tester.tap(find.text('Note').first);
    await pumpFor(tester);
    await tapKey(tester, 'flow-insert-root-1');
    await pumpFor(tester);
    await tapKey(tester, 'block-kind-saveToChat');
    await settle(tester);

    final flow = store.flows.singleWhere((f) => f.name == 'Note');
    expect(flow.blocks.map((b) => b.kind), [
      FlowBlockKind.notify,
      FlowBlockKind.saveToChat,
    ]);
  });

  testWidgets('a step can be removed from its sheet', (tester) async {
    final backend = _Backend();
    await store.upsertCustom(
      id: null,
      name: 'Two',
      description: '',
      blocks: const [FlowBlock.notify('a'), FlowBlock.saveToChat()],
    );
    await open(tester, backend);

    await tester.tap(find.text('Two').first);
    await pumpFor(tester);
    await tapKey(tester, 'flow-block-root-1');
    await pumpFor(tester);
    await tapKey(tester, 'block-remove');
    await settle(tester);

    expect(
      store.flows.singleWhere((f) => f.name == 'Two').blocks.single.kind,
      FlowBlockKind.notify,
    );
  });

  testWidgets('a branch shows a yes lane and an otherwise lane',
      (tester) async {
    final backend = _Backend();
    await store.upsertCustom(
      id: null,
      name: 'Branchy',
      description: '',
      blocks: const [
        FlowBlock.branch(
          FlowCondition.batteryBelow(30),
          then: [FlowBlock.notify('low')],
          otherwise: [FlowBlock.notify('fine')],
        ),
      ],
    );
    await open(tester, backend);

    await tester.tap(find.text('Branchy').first);
    await pumpFor(tester);

    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('Otherwise'), findsOneWidget);
    expect(find.byKey(const Key('flow-block-0t-0')), findsOneWidget);
    expect(find.byKey(const Key('flow-block-0e-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a manual-only flow asks for no permission', (tester) async {
    final backend = _Backend(allowed: false);
    await store.upsertCustom(
      id: null,
      name: 'Manual',
      description: '',
      blocks: const [FlowBlock.notify('hi')],
    );
    await open(tester, backend);

    await tester.tap(find.byKey(
      Key('flow-toggle-${store.flows.last.id}'),
    ));
    await settle(tester);

    expect(backend.requests, 0,
        reason: 'nothing is scheduled, nothing to allow');
  });
}
