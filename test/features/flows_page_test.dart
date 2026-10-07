import 'dart:io';
import 'dart:math' as math;

import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_executor.dart';
import 'package:finn_ai/src/features/flows/flow_runner.dart';
import 'package:finn_ai/src/features/flows/flow_tile.dart';
import 'package:finn_ai/src/features/flows/flows_page.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';

void main() {
  test('every tile colour keeps white text at WCAG AA', () {
    for (final kind in FlowTriggerKind.values) {
      for (final colour in flowTileColors(kind)) {
        final ratio = 1.05 / (_luminance(colour) + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '$kind $colour');
      }
    }
  });

  // The store reads and writes real files, which never settle under the
  // default test binding's fake clock.
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_flows_page_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  group('a flow with steps is an automation', () {
    late FlowsStore store;
    late _RecordingExecutor executor;

    /// A flow whose only step changes the phone, so it needs a grant to run by
    /// itself and a confirmation to run by hand.
    FinnFlow alarmFlow() => FinnFlow(
          id: 'custom-alarm',
          name: 'Wake me',
          description: 'Sets an alarm',
          instructions: 'x',
          category: 'Custom',
          blocks: const [
            FlowBlock.action('set_alarm', {'hour': '7', 'minute': '0'}),
          ],
        );

    setUp(() async {
      store = FlowsStore(directoryProvider: () async => directory);
      await store.initialize();
      executor = _RecordingExecutor();
    });

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: FluxTheme.light,
          home: FlowsPage(
            onBack: () {},
            store: store,
            runner: FlowRunner(
              store: store,
              executor: executor,
              clock: () => DateTime(2026, 9, 30, 7),
              idFactory: () => 'run-1',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    /// Opens a flow's detail page from the list.
    Future<void> openDetail(WidgetTester tester, FinnFlow flow) async {
      await tester.tap(find.text(flow.name).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets(
        'a tile\'s run and on/off controls are 48dp targets, '
        'even under a long name', (tester) async {
      await store.upsertCustom(
        id: null,
        name: 'Benachrichtigung über den Akkustand am frühen Morgen',
        description: '',
        blocks: const [FlowBlock.ask('Summarise')],
      );
      await open(tester);
      final flow = store.flows.last;
      for (final key in [
        'flow-run-tile-${flow.id}',
        'flow-toggle-${flow.id}'
      ]) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
      }
      expect(tester.takeException(), isNull);
    });

    /// Scrolls a flow's card into view.
    testWidgets('an ask-only flow shows a run button and no grant switch',
        (tester) async {
      await store.upsertCustom(
        id: null,
        name: 'Note',
        description: '',
        blocks: const [FlowBlock.ask('Summarise')],
      );
      await open(tester);
      await openDetail(tester, store.flows.last);

      expect(find.text('Run now'), findsWidgets);
      // A flow that cannot touch the phone needs no permission, so it is not
      // offered one.
      expect(find.text('Let it run by itself'), findsNothing);
    });

    testWidgets('a device-action flow offers the standing grant', (
      tester,
    ) async {
      await store.upsertCustom(
        id: null,
        name: 'Wake me',
        description: '',
        blocks: alarmFlow().blocks,
        triggers: const [FlowTrigger.daily(7, 0)],
      );
      await open(tester);
      await openDetail(tester, store.flows.last);

      // The chart is long; the permission sits below it.
      await tester.scrollUntilVisible(
        find.text('Let it run by itself'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Let it run by itself'), findsOneWidget);
      expect(find.textContaining('Allow it to run when you are not looking'),
          findsOneWidget);
      // The grant is its own control, not a repurposing of the enable switch:
      // turning the flow on is not permission for it to act on its own.
      final flow = store.flows.last;
      expect(find.byKey(Key('flow-grant-${flow.id}')), findsOneWidget);
      final grant = tester.widget<FinnSwitch>(
        find.byKey(Key('flow-grant-${flow.id}')),
      );
      expect(grant.value, isFalse, reason: 'a new flow is not pre-granted');
    });

    testWidgets('Run asks first when the flow can change the phone', (
      tester,
    ) async {
      await store.upsertCustom(
        id: null,
        name: 'Wake me',
        description: '',
        blocks: alarmFlow().blocks,
      );
      await open(tester);
      await openDetail(tester, store.flows.last);

      await tester.tap(find.byKey(Key('flow-run-${store.flows.last.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(executor.calls, isEmpty, reason: 'nothing runs before the tap');

      await tester.tap(find.text('Run now').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(executor.calls, hasLength(1));
      expect(store.runs, hasLength(1));
      expect(store.runs.single.outcome, FlowRunOutcome.completed);
    });

    testWidgets(
        'declining the confirmation records a refusal and acts on '
        'nothing', (tester) async {
      await store.upsertCustom(
        id: null,
        name: 'Wake me',
        description: '',
        blocks: alarmFlow().blocks,
      );
      await open(tester);
      await openDetail(tester, store.flows.last);

      await tester.tap(find.byKey(Key('flow-run-${store.flows.last.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(executor.calls, isEmpty);
      expect(store.runs, hasLength(1));
      expect(store.runs.single.outcome, FlowRunOutcome.needsGrant);
    });

    testWidgets('the run history shows what happened and who started it', (
      tester,
    ) async {
      await store.upsertCustom(
        id: null,
        name: 'Wake me',
        description: '',
        blocks: alarmFlow().blocks,
      );
      await store.recordRun(FlowRun(
        id: 'run-0',
        flowId: store.flows.last.id,
        startedAt: DateTime(2026, 9, 30, 7),
        outcome: FlowRunOutcome.completed,
        triggeredBy: 'schedule',
      ));
      await open(tester);
      await openDetail(tester, store.flows.last);

      await tester.scrollUntilVisible(
        find.text('Recent runs'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Recent runs'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Ran by itself'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Ran by itself'), findsOneWidget);
      expect(find.textContaining('Finished'), findsOneWidget);
    });

    testWidgets('a run that needed a grant says so, so the user can act', (
      tester,
    ) async {
      await store.upsertCustom(
        id: null,
        name: 'Wake me',
        description: '',
        blocks: alarmFlow().blocks,
        triggers: const [FlowTrigger.daily(7, 0)],
      );
      await store.recordRun(FlowRun(
        id: 'run-0',
        flowId: store.flows.last.id,
        startedAt: DateTime(2026, 9, 30, 7),
        outcome: FlowRunOutcome.needsGrant,
        triggeredBy: 'schedule',
      ));
      await open(tester);
      await openDetail(tester, store.flows.last);

      await tester.scrollUntilVisible(
        find.textContaining('Needs your permission to run by itself'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Needs your permission to run by itself'),
        findsOneWidget,
      );
    });
  });
}

class _RecordingExecutor implements DeviceActionExecutor {
  final List<DeviceActionInvocation> calls = [];

  @override
  Future<DeviceActionResult> execute(DeviceActionInvocation invocation) async {
    calls.add(invocation);
    return const DeviceActionResult.performed();
  }
}

/// WCAG 2.x relative luminance of an opaque colour.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}
