import 'dart:io';

import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_executor.dart';
import 'package:finn_ai/src/features/flows/flow_runner.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one rule this feature rests on: a flow may not act on the device
/// without permission.
///
/// It has to hold in three separate places — the shape check, the manual run,
/// and the scheduled run — because any one of them being wrong is a flow that
/// sets an alarm nobody asked for.
void main() {
  late Directory directory;
  late FlowsStore store;
  late _RecordingExecutor executor;
  late List<String> asked;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn-flows');
    store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();
    executor = _RecordingExecutor();
    asked = [];
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  FinnFlow alarmFlow({bool granted = false}) => FinnFlow(
        id: 'custom-alarm',
        name: 'Wake me',
        description: 'Sets an alarm',
        instructions: '',
        category: 'Custom',
        granted: granted,
        steps: const [
          FlowStep(kind: FlowStepKind.prompt, text: 'What time is it?'),
          FlowStep(
            kind: FlowStepKind.deviceAction,
            text: 'Set the alarm',
            actionName: 'set_alarm',
            arguments: {'hour': '7', 'minute': '0'},
          ),
        ],
      );

  FlowRunner runner({
    Future<String> Function(String)? ask,
    DateTime? now,
    String Function()? id,
  }) =>
      FlowRunner(
        store: store,
        executor: executor,
        ask: ask ??
            (prompt) async {
              asked.add(prompt);
              return 'it is 7am';
            },
        clock: () => now ?? DateTime(2026, 9, 30, 7, 0),
        idFactory: id ?? (() => 'run-test'),
      );

  group('a flow cannot act on the device without permission', () {
    test('an ungranted manual run stops at the device action', () async {
      final run = await runner().run(alarmFlow());

      expect(run.outcome, FlowRunOutcome.needsGrant);
      // The prompt step before it still ran: the grant stops the *action*, not
      // the whole flow.
      expect(asked, hasLength(1));
      expect(executor.calls, isEmpty, reason: 'the alarm must not be set');
      expect(run.steps.last.outcome, FlowRunOutcome.needsGrant);
    });

    test('a granted run performs the action', () async {
      final run = await runner().run(alarmFlow(granted: true));

      expect(run.outcome, FlowRunOutcome.completed);
      expect(executor.calls, hasLength(1));
      expect(executor.calls.single.action.name, 'set_alarm');
      expect(executor.calls.single.arguments['hour'], '7');
    });

    test('a per-run grant is enough even when the flow stores none', () async {
      // This is the manual path: the user confirmed, so the caller passes it
      // for this run only and nothing is persisted.
      final run = await runner().run(alarmFlow(), granted: true);

      expect(run.outcome, FlowRunOutcome.completed);
      expect(executor.calls, hasLength(1));
      expect(
        store.flows.where((f) => f.id == 'custom-alarm').isEmpty,
        isTrue,
        reason: 'a one-off confirmation must not become a standing grant',
      );
    });

    test('a scheduled run without a grant does not act', () async {
      final flow = alarmFlow().copyWith(
        trigger: const FlowTrigger.daily(7, 0),
        enabled: true,
      );
      await store.upsertCustom(
        id: null,
        name: flow.name,
        description: flow.description,
        instructions: 'x',
        steps: flow.steps,
        trigger: flow.trigger,
      );

      final runs =
          await runner().runDueScheduledFlows(DateTime(2026, 9, 30, 7, 0));

      expect(executor.calls, isEmpty);
      expect(runs.single.outcome, FlowRunOutcome.needsGrant);
      expect(runs.single.triggeredBy, 'schedule');
    });

    test('a scheduled run with a grant acts', () async {
      await store.upsertCustom(
        id: null,
        name: 'Wake me',
        description: '',
        instructions: 'x',
        steps: alarmFlow().steps,
        trigger: const FlowTrigger.daily(7, 0),
        granted: true,
      );

      final runs =
          await runner().runDueScheduledFlows(DateTime(2026, 9, 30, 7, 0));

      expect(executor.calls, hasLength(1));
      expect(runs.single.outcome, FlowRunOutcome.completed);
      expect(runs.single.triggeredBy, 'schedule');
    });

    test('a prompt-only flow needs no grant and runs when scheduled', () async {
      await store.upsertCustom(
        id: null,
        name: 'Morning note',
        description: '',
        instructions: 'x',
        steps: const [
          FlowStep(kind: FlowStepKind.prompt, text: 'Summarise today')
        ],
        trigger: const FlowTrigger.daily(7, 0),
      );

      final runs =
          await runner().runDueScheduledFlows(DateTime(2026, 9, 30, 7, 0));

      expect(runs.single.outcome, FlowRunOutcome.completed);
      expect(asked, hasLength(1));
    });
  });

  group('the shape of a flow is checked before anything runs', () {
    test('an action outside the catalog is refused, and nothing executes',
        () async {
      final flow = alarmFlow(granted: true).copyWith(
        steps: const [
          FlowStep(
            kind: FlowStepKind.deviceAction,
            text: 'Do something not on the list',
            actionName: 'exfiltrate_everything',
          ),
        ],
      );

      final run = await runner().run(flow);

      expect(run.outcome, FlowRunOutcome.failed);
      expect(executor.calls, isEmpty);
    });

    test('a missing required argument is refused', () async {
      final flow = alarmFlow(granted: true).copyWith(
        steps: const [
          FlowStep(
            kind: FlowStepKind.deviceAction,
            text: 'Set an alarm with no time',
            actionName: 'set_alarm',
          ),
        ],
      );

      final run = await runner().run(flow);

      expect(run.outcome, FlowRunOutcome.failed);
      expect(executor.calls, isEmpty);
    });

    test('a flow with no steps is refused', () async {
      final run = await runner().run(
        alarmFlow(granted: true).copyWith(steps: const []),
      );
      expect(run.outcome, FlowRunOutcome.failed);
    });
  });

  group('runs are recorded', () {
    test('every run lands in the log, including the refusals', () async {
      await runner().run(alarmFlow());

      expect(store.runs, hasLength(1));
      expect(store.runs.single.outcome, FlowRunOutcome.needsGrant);
      expect(store.runs.single.flowId, 'custom-alarm');
    });

    test('the log survives a reload', () async {
      await runner().run(alarmFlow(granted: true));

      final reopened = FlowsStore(directoryProvider: () async => directory);
      await reopened.initialize();
      expect(reopened.runs, hasLength(1));
      expect(reopened.runs.single.outcome, FlowRunOutcome.completed);
    });

    test('the log never contains model text', () async {
      await runner().run(alarmFlow(granted: true));
      final log =
          File('${directory.path}${Platform.pathSeparator}flows.json.runs');
      final body = await log.readAsString();
      // The answer to the prompt step was "it is 7am". A run log is written to
      // disk and read back on device; it records what happened, not what the
      // model said.
      expect(body, isNot(contains('it is 7am')));
    });

    test('the log is bounded', () async {
      for (var i = 0; i < FlowsStore.maxRunHistory + 5; i++) {
        await runner(id: () => 'run-$i').run(alarmFlow());
      }
      expect(store.runs.length, FlowsStore.maxRunHistory);
      // Newest first, so the last run written is the first one kept.
      expect(store.runs.first.id, 'run-${FlowsStore.maxRunHistory + 4}');
    });
  });

  group('steps run in order and can build on each other', () {
    test('a later step sees the previous answer', () async {
      final flow = alarmFlow(granted: true).copyWith(
        steps: const [
          FlowStep(kind: FlowStepKind.prompt, text: 'What time should I wake?'),
          FlowStep(kind: FlowStepKind.prompt, text: 'So: {input}'),
        ],
      );

      await runner().run(flow);

      expect(asked, ['What time should I wake?', 'So: it is 7am']);
    });

    test('a failing prompt step stops the flow', () async {
      final flow = alarmFlow(granted: true).copyWith(
        steps: const [
          FlowStep(kind: FlowStepKind.prompt, text: 'first'),
          FlowStep(kind: FlowStepKind.prompt, text: 'second'),
        ],
      );
      final failing = FlowRunner(
        store: store,
        executor: executor,
        ask: (_) async => throw StateError('model gone'),
        clock: () => DateTime(2026, 9, 30),
        idFactory: () => 'run-test',
      );

      final run = await failing.run(flow);

      expect(run.outcome, FlowRunOutcome.failed);
      expect(asked, isEmpty);
    });

    test('a runner with no model still runs an action-only flow', () async {
      // A pure automation should not need a 1.6B model to set an alarm.
      final flow = alarmFlow(granted: true).copyWith(
        steps: const [
          FlowStep(
            kind: FlowStepKind.deviceAction,
            text: 'Set the alarm',
            actionName: 'set_alarm',
            arguments: {'hour': '7'},
          ),
        ],
      );

      final run = await FlowRunner(
        store: store,
        executor: executor,
        clock: () => DateTime(2026, 9, 30),
        idFactory: () => 'run-test',
      ).run(flow);

      expect(run.outcome, FlowRunOutcome.completed);
      expect(executor.calls, hasLength(1));
    });

    test('two runs do not interleave', () async {
      final flow = alarmFlow(granted: true).copyWith(
        steps: const [
          FlowStep(
            kind: FlowStepKind.deviceAction,
            text: 'Set the alarm',
            actionName: 'set_alarm',
            arguments: {'hour': '7'},
          ),
        ],
      );
      final slow = FlowRunner(
        store: store,
        executor: _SlowExecutor(),
        ask: (_) async => 'x',
        clock: () => DateTime(2026, 9, 30),
        idFactory: () => 'run-test',
      );

      final first = slow.run(flow);
      final second = await slow.run(flow);

      // The second is refused rather than interleaved, because two runs would
      // otherwise attribute their actions to each other in the log.
      expect(second.outcome, FlowRunOutcome.interrupted);
      await first;
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

class _SlowExecutor implements DeviceActionExecutor {
  @override
  Future<DeviceActionResult> execute(DeviceActionInvocation invocation) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return const DeviceActionResult.performed();
  }
}
