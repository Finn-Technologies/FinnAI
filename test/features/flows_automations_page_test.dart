import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/flows/flow_scheduler.dart';
import 'package:finn_ai/src/features/flows/flows_page.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

class _Backend implements FlowScheduleBackend {
  _Backend({this.allowed = true, this.grant = true});

  bool allowed;
  final bool grant;
  int requests = 0;
  final scheduled = <String, (int, int)>{};

  @override
  Future<bool> notificationsAllowed() async => allowed;

  @override
  Future<bool> requestNotifications() async {
    requests++;
    allowed = grant;
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
      scheduled[flowId] = (hour, minute);

  @override
  Future<void> cancel(String flowId) async => scheduled.remove(flowId);

  @override
  Future<void> cancelAll() async => scheduled.clear();

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

  /// The live binding's window is 800x600 whatever the test asks for, so a
  /// control far down the list has to be scrolled to before it can be tapped.
  Future<void> bringIntoView(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 12; i++) {
      if (finder.evaluate().isNotEmpty) {
        final y = tester.getCenter(finder).dy;
        if (y > 80 && y < 520) return;
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> createMorningBrief(WidgetTester tester) async {
    await bringIntoView(tester, find.byKey(const Key('new-automation-button')));
    await tester.tap(find.byKey(const Key('new-automation-button')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('flow-template-morning_brief')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
        find.byKey(const Key('flow-slot-topics')), 'football and tech');
    await tester.enterText(find.byKey(const Key('flow-slot-city')), 'Rome');
    await tester.pump();
  }

  testWidgets('a morning brief is created from a template and scheduled', (
    tester,
  ) async {
    final backend = _Backend();
    await open(tester, backend);
    expect(find.text('No automations yet. Start with a morning brief.'),
        findsOneWidget);

    await createMorningBrief(tester);
    // Defaults to every day at 07:30; choose "Every day" explicitly.
    await tester.tap(find.byKey(const Key('flow-automation-save')));
    await settle(tester);

    final flow = store.flows.singleWhere((f) => f.name == 'Morning brief');
    expect(flow.steps.map((s) => s.kind), [
      FlowStepKind.browse,
      FlowStepKind.browse,
      FlowStepKind.prompt,
      FlowStepKind.notify,
    ]);
    expect(flow.trigger.isScheduled, isTrue);
    expect(flow.trigger.hour, 7);
    expect(flow.trigger.minute, 30);
    expect(flow.enabled, isTrue);
    expect(backend.scheduled[flow.id], (7, 30),
        reason: 'the alarm is armed once the flow is saved');
    expect(find.text('Every day at 07:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'notifications are explained before the system prompt, and '
      'declining leaves the flow quiet with a note', (tester) async {
    final backend = _Backend(allowed: false, grant: false);
    await open(tester, backend);

    await createMorningBrief(tester);
    await tester.tap(find.byKey(const Key('flow-automation-save')));
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);

    // Our own explanation comes first; the OS prompt has none.
    expect(find.text('Allow notifications?'), findsOneWidget);
    expect(backend.requests, 0);
    await tester.tap(find.byKey(const Key('flow-notify-allow')));
    await settle(tester);

    expect(backend.requests, 1);
    expect(backend.scheduled, isEmpty, reason: 'nothing armed without a grant');
    final flow = store.flows.singleWhere((f) => f.name == 'Morning brief');
    expect(flow.enabled, isTrue, reason: 'the flow stays on, just quiet');
    expect(find.byKey(Key('flow-notify-off-${flow.id}')), findsOneWidget);
  });

  testWidgets('a manual-only automation asks for no permission', (
    tester,
  ) async {
    final backend = _Backend(allowed: false);
    await open(tester, backend);

    await createMorningBrief(tester);
    await tester.tap(find.byKey(const Key('flow-schedule-mode-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('flow-automation-save')));
    await settle(tester);

    expect(find.text('Allow notifications?'), findsNothing);
    expect(backend.requests, 0);
    final flow = store.flows.singleWhere((f) => f.name == 'Morning brief');
    expect(flow.trigger.isScheduled, isFalse);
  });

  testWidgets('the schedule chip opens the editor and saves a new time rule', (
    tester,
  ) async {
    final backend = _Backend();
    await open(tester, backend);
    await createMorningBrief(tester);
    await tester.tap(find.byKey(const Key('flow-automation-save')));
    await settle(tester);

    final flow = store.flows.singleWhere((f) => f.name == 'Morning brief');
    final chip = find.byKey(Key('flow-schedule-${flow.id}'));
    await bringIntoView(tester, chip);
    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('flow-schedule-mode-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('flow-schedule-save')));
    await settle(tester);

    final updated = store.flows.singleWhere((f) => f.id == flow.id);
    expect(updated.trigger.daysOfWeek, {1, 2, 3, 4, 5});
    expect(backend.scheduled[flow.id], isNotNull);
  });
}
