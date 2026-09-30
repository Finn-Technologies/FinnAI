import 'dart:io';

import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_executor.dart';
import 'package:finn_ai/src/features/flows/flow_runner.dart';
import 'package:finn_ai/src/features/flows/flows_page.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The store reads and writes real files, which never settle under the
  // default test binding's fake clock.
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_skills_page_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  testWidgets('the four-flow cap shows the localized limit sentence', (
    tester,
  ) async {
    final store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();
    for (final flow in finnBuiltInFlows) {
      expect(await store.setEnabled(flow.id, true), isTrue);
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: FlowsPage(onBack: () {}, store: store),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('add-flow-button')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('new-skill-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('new-skill-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(const Key('flow-name-field')),
      'Fifth flow',
    );
    await tester.enterText(
      find.byKey(const Key('flow-instructions-field')),
      'Do the thing.',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('save-flow-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.failure, FlowsFailure.limit);
    // Shown both in the snackbar and in the inline notice.
    expect(
      find.text('Flow limit reached (4). Delete one to add another.'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
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
          steps: const [
            FlowStep(
              kind: FlowStepKind.deviceAction,
              text: 'Set the alarm',
              actionName: 'set_alarm',
              arguments: {'hour': '7', 'minute': '0'},
            ),
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

    /// Scrolls a custom flow's card into view.
    ///
    /// The custom section sits below the four built-ins, so its run button is
    /// off-screen on a 390x844 phone — which is a fact about the page, not a
    /// test artefact.
    Future<void> scrollTo(WidgetTester tester, FinnFlow flow) async {
      await tester.scrollUntilVisible(
        find.byKey(Key('flow-run-${flow.id}')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
    }

    testWidgets('a prompt-only flow shows a run button and no grant switch',
        (tester) async {
      await store.upsertCustom(
        id: null,
        name: 'Note',
        description: '',
        instructions: 'x',
        steps: const [FlowStep(kind: FlowStepKind.prompt, text: 'Summarise')],
      );
      await open(tester);

      expect(find.text('Run now'), findsWidgets);
      // A flow that cannot touch the phone needs no permission, so it is not
      // offered one.
      expect(find.text('Let this run by itself'), findsNothing);
    });

    testWidgets('a device-action flow offers the standing grant', (
      tester,
    ) async {
      await store.upsertCustom(
        id: null,
        name: 'Wake me',
        description: '',
        instructions: 'x',
        steps: alarmFlow().steps,
      );
      await open(tester);

      expect(find.text('Let this run by itself'), findsOneWidget);
      expect(
          find.textContaining('needs this before it can run'), findsOneWidget);
      // The grant is its own control, not a repurposing of the enable switch:
      // turning the flow on is not permission for it to act on its own.
      final flow = store.flows.last;
      expect(find.byKey(Key('flow-grant-${flow.id}')), findsOneWidget);
      final grant = tester.widget<Switch>(
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
        instructions: 'x',
        steps: alarmFlow().steps,
      );
      await open(tester);
      await scrollTo(tester, store.flows.last);

      await tester.tap(find.byKey(Key('flow-run-${store.flows.last.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(executor.calls, isEmpty, reason: 'nothing runs before the tap');

      await tester.tap(find.byKey(const Key('flow-confirm-run')));
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
        instructions: 'x',
        steps: alarmFlow().steps,
      );
      await open(tester);
      await scrollTo(tester, store.flows.last);

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
        instructions: 'x',
        steps: alarmFlow().steps,
      );
      await store.recordRun(FlowRun(
        id: 'run-0',
        flowId: store.flows.last.id,
        startedAt: DateTime(2026, 9, 30, 7),
        outcome: FlowRunOutcome.completed,
        triggeredBy: 'schedule',
      ));
      await open(tester);

      expect(find.text('Recent runs'), findsOneWidget);
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
        instructions: 'x',
        steps: alarmFlow().steps,
        trigger: const FlowTrigger.daily(7, 0),
      );
      await store.recordRun(FlowRun(
        id: 'run-0',
        flowId: store.flows.last.id,
        startedAt: DateTime(2026, 9, 30, 7),
        outcome: FlowRunOutcome.needsGrant,
        triggeredBy: 'schedule',
      ));
      await open(tester);

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
