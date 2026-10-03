import 'dart:io';

import 'package:finn_ai/src/engine/api/web_source.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_executor.dart';
import 'package:finn_ai/src/features/flows/flow_ports.dart';
import 'package:finn_ai/src/features/flows/flow_runner.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one rule this feature rests on: a flow may not act on the device
/// without permission.
///
/// It has to hold in several separate places — the shape check, the manual
/// run, a scheduled run and an event-started run — because any one of them
/// being wrong is a flow that does something nobody asked for.
void main() {
  late Directory directory;
  late FlowsStore store;
  late _RecordingExecutor executor;
  late List<String> asked;
  late List<String> notified;
  late List<String> spoken;
  late _FakeEnvironment environment;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn-flows');
    store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();
    executor = _RecordingExecutor();
    asked = [];
    notified = [];
    spoken = [];
    environment = _FakeEnvironment();
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
        blocks: const [
          FlowBlock.ask('What time is it?'),
          FlowBlock.action('set_alarm', {'hour': '7', 'minute': '0'}),
        ],
      );

  FlowRunner runner({
    Future<String> Function(String)? ask,
    DateTime? now,
    String Function()? id,
    FlowSearch? search,
    FlowOutputSink? sink,
    Future<void> Function(Duration)? delay,
  }) =>
      FlowRunner(
        store: store,
        executor: executor,
        ask: ask ??
            (prompt) async {
              asked.add(prompt);
              return 'it is 7am';
            },
        search: search,
        sink: sink,
        notifier: _Notifier(notified),
        speaker: _Speaker(spoken),
        environment: environment,
        clock: () => now ?? DateTime(2026, 9, 30, 7, 0),
        idFactory: id ?? (() => 'run-test'),
        delay: delay ?? (_) async {},
      );

  Future<void> save(
    FinnFlow flow, {
    bool granted = false,
    bool enabled = true,
  }) async {
    final ok = await store.upsertCustom(
      id: null,
      name: flow.name,
      description: flow.description,
      blocks: flow.blocks,
      triggers: flow.triggers,
      conditions: flow.conditions,
      enabled: enabled,
      granted: granted,
    );
    expect(ok, isTrue);
  }

  group('a flow cannot act on the device without permission', () {
    test('an ungranted manual run stops at the device action', () async {
      final run = await runner().run(alarmFlow());

      expect(run.outcome, FlowRunOutcome.needsGrant);
      // The ask block before it still ran: the grant stops the *action*, not
      // the whole flow.
      expect(asked, hasLength(1));
      expect(executor.calls, isEmpty, reason: 'the alarm must not be set');
      expect(run.steps.last.outcome, FlowRunOutcome.needsGrant);
    });

    test('a granted run performs the action', () async {
      final run = await runner().run(alarmFlow(granted: true));

      expect(run.outcome, FlowRunOutcome.completed);
      expect(executor.calls.single.action.name, 'set_alarm');
      expect(executor.calls.single.arguments['hour'], '7');
    });

    test('a per-run grant is enough even when the flow stores none', () async {
      final run = await runner().run(alarmFlow(), granted: true);

      expect(run.outcome, FlowRunOutcome.completed);
      expect(executor.calls, hasLength(1));
      expect(
        store.flows.where((f) => f.id == 'custom-alarm').isEmpty,
        isTrue,
        reason: 'a one-off confirmation must not become a standing grant',
      );
    });

    test('a run something else started ignores a per-run grant', () async {
      // `granted` is the answer to "may I?" asked of a person. Nobody was asked
      // here, so it must not count.
      final run = await runner().run(
        alarmFlow(),
        granted: true,
        triggeredBy: 'event:chargerConnected',
      );

      expect(run.outcome, FlowRunOutcome.needsGrant);
      expect(executor.calls, isEmpty);
    });

    test('a scheduled run without a grant does not act', () async {
      await save(
        alarmFlow().copyWith(triggers: [const FlowTrigger.daily(7, 0)]),
      );

      final runs =
          await runner().runDueScheduledFlows(DateTime(2026, 9, 30, 7, 0));

      expect(executor.calls, isEmpty);
      expect(runs.single.outcome, FlowRunOutcome.needsGrant);
      expect(runs.single.triggeredBy, 'schedule');
    });

    test('a scheduled run with a grant acts', () async {
      await save(
        alarmFlow().copyWith(triggers: [const FlowTrigger.daily(7, 0)]),
        granted: true,
      );

      final runs =
          await runner().runDueScheduledFlows(DateTime(2026, 9, 30, 7, 0));

      expect(executor.calls, hasLength(1));
      expect(runs.single.outcome, FlowRunOutcome.completed);
    });

    test('an event-started run without a grant does not act', () async {
      await save(
        alarmFlow().copyWith(
          triggers: [const FlowTrigger.event(FlowTriggerKind.chargerConnected)],
        ),
      );

      final runs = await runner().runForEvent(FlowTriggerKind.chargerConnected);

      expect(executor.calls, isEmpty);
      expect(runs.single.outcome, FlowRunOutcome.needsGrant);
      expect(runs.single.triggeredBy, 'event:chargerConnected');
    });

    test('an event-started run with a grant acts', () async {
      await save(
        alarmFlow().copyWith(
          triggers: [const FlowTrigger.event(FlowTriggerKind.chargerConnected)],
        ),
        granted: true,
      );

      final runs = await runner().runForEvent(FlowTriggerKind.chargerConnected);

      expect(executor.calls, hasLength(1));
      expect(runs.single.outcome, FlowRunOutcome.completed);
    });

    test('a flow with no device action needs no grant when triggered',
        () async {
      await save(
        const FinnFlow(
          id: '',
          name: 'Morning note',
          description: '',
          instructions: '',
          category: 'Custom',
          blocks: [FlowBlock.ask('Summarise today')],
          triggers: [FlowTrigger.daily(7, 0)],
        ),
      );

      final runs =
          await runner().runDueScheduledFlows(DateTime(2026, 9, 30, 7, 0));

      expect(runs.single.outcome, FlowRunOutcome.completed);
      expect(asked, hasLength(1));
    });

    test('a flow the user did not enable never runs by itself', () async {
      await save(
        alarmFlow().copyWith(triggers: [const FlowTrigger.daily(7, 0)]),
        granted: true,
        enabled: false,
      );

      final runs =
          await runner().runDueScheduledFlows(DateTime(2026, 9, 30, 7, 0));

      expect(runs, isEmpty);
      expect(executor.calls, isEmpty);
    });

    test('a device action inside a branch is still gated', () async {
      final flow = alarmFlow().copyWith(
        blocks: const [
          FlowBlock.branch(
            FlowCondition(FlowConditionKind.charging),
            then: [
              FlowBlock.action('torch', {'on': 'true'})
            ],
          ),
        ],
      );
      environment.charging = true;

      final run = await runner().run(flow);

      expect(run.outcome, FlowRunOutcome.needsGrant);
      expect(executor.calls, isEmpty);
    });
  });

  group('the shape of a flow is checked before anything runs', () {
    test('an action outside the catalog is refused, and nothing executes',
        () async {
      final flow = alarmFlow(granted: true).copyWith(
        blocks: const [FlowBlock.action('exfiltrate_everything')],
      );

      final run = await runner().run(flow);

      expect(run.outcome, FlowRunOutcome.failed);
      expect(executor.calls, isEmpty);
    });

    test('an unknown action hidden in a branch is refused too', () async {
      final flow = alarmFlow(granted: true).copyWith(
        blocks: const [
          FlowBlock.branch(
            FlowCondition(FlowConditionKind.charging),
            otherwise: [FlowBlock.action('exfiltrate_everything')],
          ),
        ],
      );

      final run = await runner().run(flow);

      expect(run.outcome, FlowRunOutcome.failed);
      expect(executor.calls, isEmpty);
    });

    test('a missing required argument is refused', () async {
      final flow = alarmFlow(granted: true).copyWith(
        blocks: const [FlowBlock.action('set_alarm')],
      );

      final run = await runner().run(flow);

      expect(run.outcome, FlowRunOutcome.failed);
      expect(executor.calls, isEmpty);
    });

    test('a flow with no blocks is refused', () async {
      final run = await runner().run(
        alarmFlow(granted: true).copyWith(blocks: const []),
      );
      expect(run.outcome, FlowRunOutcome.failed);
    });

    test('too many blocks are refused', () async {
      final flow = alarmFlow(granted: true).copyWith(
        blocks: [for (var i = 0; i < 31; i++) const FlowBlock.wait(1)],
      );
      final run = await runner().run(flow);
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
      // The answer to the ask block was "it is 7am". A run log is written to
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

    test('saving a flow never rewrites the run log', () async {
      await runner().run(alarmFlow(granted: true));
      final log =
          File('${directory.path}${Platform.pathSeparator}flows.json.runs');
      final before = await log.readAsString();

      // A second engine wrote another run; this store has not seen it.
      await log.writeAsString('[]');
      await save(alarmFlow());

      expect(await log.readAsString(), '[]', reason: before);
    });

    test('each result says where in the flow it happened', () async {
      final flow = alarmFlow(granted: true).copyWith(
        blocks: const [
          FlowBlock.notify('hi'),
          FlowBlock.branch(
            FlowCondition(FlowConditionKind.charging),
            then: [FlowBlock.wait(1), FlowBlock.notify('yes')],
          ),
        ],
      );
      environment.charging = true;

      final run = await runner().run(flow);

      expect(run.steps.map((s) => s.path), ['0', '1', '1.then.0', '1.then.1']);
    });
  });

  group('blocks run in order and can build on each other', () {
    test('a later block sees the previous answer', () async {
      final flow = alarmFlow(granted: true).copyWith(
        blocks: const [
          FlowBlock.ask('What time should I wake?'),
          FlowBlock.ask('So: {input}'),
          FlowBlock.ask('Again: {ai}'),
        ],
      );

      await runner().run(flow);

      expect(asked, [
        'What time should I wake?',
        'So: it is 7am',
        'Again: it is 7am',
      ]);
    });

    test('{date}, {time} and {battery} are filled in', () async {
      environment.battery = 42;
      final flow = alarmFlow().copyWith(
        blocks: const [FlowBlock.ask('{date} {time} {battery}')],
      );

      await runner(now: DateTime(2026, 9, 30, 7, 5)).run(flow);

      expect(asked, ['2026-09-30 07:05 42%']);
    });

    test('a failing ask block stops the flow', () async {
      final flow = alarmFlow(granted: true).copyWith(
        blocks: const [FlowBlock.ask('first'), FlowBlock.ask('second')],
      );
      var calls = 0;
      final failing = runner(
        ask: (_) async {
          calls++;
          throw StateError('model gone');
        },
      );

      final run = await failing.run(flow);

      expect(run.outcome, FlowRunOutcome.failed);
      expect(calls, 1);
    });

    test('a failed block means nothing after it runs', () async {
      final flow = alarmFlow(granted: true).copyWith(
        blocks: const [
          FlowBlock.ask('first'),
          FlowBlock.notify('done'),
          FlowBlock.action('torch', {'on': 'true'}),
        ],
      );

      final run =
          await runner(ask: (_) async => throw StateError('x')).run(flow);

      expect(run.outcome, FlowRunOutcome.failed);
      expect(notified, isEmpty);
      expect(executor.calls, isEmpty);
    });

    test('a runner with no model still runs an action-only flow', () async {
      final flow = alarmFlow(granted: true).copyWith(
        blocks: const [
          FlowBlock.action('set_alarm', {'hour': '7'})
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
        blocks: const [
          FlowBlock.action('set_alarm', {'hour': '7'})
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

      expect(second.outcome, FlowRunOutcome.interrupted);
      await first;
    });

    test('notify sends its own text, or the last answer when empty', () async {
      final flow = alarmFlow().copyWith(
        blocks: const [
          FlowBlock.notify('Charging', title: 'Battery'),
          FlowBlock.ask('x'),
          FlowBlock.notify(''),
        ],
      );

      await runner().run(flow);

      expect(notified, ['Battery|Charging', 'Wake me|it is 7am']);
    });

    test('speak says its text, or the last answer when empty', () async {
      final flow = alarmFlow().copyWith(
        blocks: const [
          FlowBlock.speak('Hello'),
          FlowBlock.ask('x'),
          FlowBlock.speak(''),
        ],
      );

      await runner().run(flow);

      expect(spoken, ['Hello', 'it is 7am']);
    });

    test('a flow that speaks with no voice still completes', () async {
      final run = await FlowRunner(
        store: store,
        clock: () => DateTime(2026, 9, 30),
        idFactory: () => 'r',
      ).run(
        alarmFlow().copyWith(blocks: const [FlowBlock.speak('Hello')]),
      );

      expect(run.outcome, FlowRunOutcome.completed);
      expect(run.steps.single.detail, 'no voice');
    });

    test('wait waits the time it says', () async {
      final waited = <Duration>[];
      final run = await runner(delay: (d) async => waited.add(d)).run(
        alarmFlow().copyWith(blocks: const [FlowBlock.wait(7)]),
      );

      expect(run.outcome, FlowRunOutcome.completed);
      expect(waited, [const Duration(seconds: 7)]);
    });

    test('save to chat delivers the last answer, and only when there is one',
        () async {
      final sink = _Sink();
      await runner(sink: sink).run(
        alarmFlow().copyWith(
          blocks: const [
            FlowBlock.saveToChat(),
            FlowBlock.ask('x'),
            FlowBlock.saveToChat()
          ],
        ),
      );

      expect(sink.delivered, ['it is 7am']);
    });

    test('stop ends the flow without a failure', () async {
      final run = await runner().run(
        alarmFlow().copyWith(
          blocks: const [
            FlowBlock.notify('one'),
            FlowBlock.stop(),
            FlowBlock.notify('two'),
          ],
        ),
      );

      expect(run.outcome, FlowRunOutcome.completed);
      expect(notified, ['Wake me|one']);
    });

    test('a web block with no results stops the next ask rather than inventing',
        () async {
      final run = await runner(search: _Search(const [])).run(
        alarmFlow().copyWith(
          blocks: const [FlowBlock.web('news: x'), FlowBlock.ask('summarise')],
        ),
      );

      expect(run.outcome, FlowRunOutcome.failed, reason: 'no sources');
      expect(asked, isEmpty);
    });

    test('sources from a web block reach the next ask', () async {
      String? context;
      final fakeModel = _Model((prompt, ctx) => context = ctx);
      final withModel = FlowRunner(
        store: store,
        model: fakeModel,
        search: _Search([
          WebSource(
            title: 't',
            url: Uri.parse('https://example.com'),
            snippet: 'headline',
          ),
        ]),
        clock: () => DateTime(2026, 9, 30),
        idFactory: () => 'r',
      );

      final run = await withModel.run(
        alarmFlow().copyWith(
          blocks: const [FlowBlock.web('news: x'), FlowBlock.ask('summarise')],
        ),
      );

      expect(run.outcome, FlowRunOutcome.completed);
      expect(context, contains('headline'));
    });
  });

  group('conditions and branches', () {
    FinnFlow noteFlow({List<FlowCondition> conditions = const []}) =>
        alarmFlow().copyWith(
          blocks: const [FlowBlock.notify('ran')],
          conditions: conditions,
        );

    test('a run something else started is skipped when a condition fails',
        () async {
      environment.battery = 80;
      final run = await runner().run(
        noteFlow(conditions: const [FlowCondition.batteryBelow(30)]),
        triggeredBy: 'event:chargerConnected',
      );

      expect(run.outcome, FlowRunOutcome.skipped);
      expect(notified, isEmpty);
    });

    test('and runs when every condition holds', () async {
      environment
        ..battery = 20
        ..charging = true;
      final run = await runner().run(
        noteFlow(
          conditions: const [
            FlowCondition.batteryBelow(30),
            FlowCondition(FlowConditionKind.charging),
          ],
        ),
        triggeredBy: 'event:chargerConnected',
      );

      expect(run.outcome, FlowRunOutcome.completed);
      expect(notified, ['Wake me|ran']);
    });

    test('a run the user started ignores the conditions', () async {
      environment.battery = 99;
      final run = await runner().run(
        noteFlow(conditions: const [FlowCondition.batteryBelow(30)]),
      );

      expect(run.outcome, FlowRunOutcome.completed);
    });

    test('a branch runs the yes lane or the otherwise lane', () async {
      final flow = alarmFlow().copyWith(
        blocks: const [
          FlowBlock.branch(
            FlowCondition.batteryBelow(30),
            then: [FlowBlock.notify('low')],
            otherwise: [FlowBlock.notify('fine')],
          ),
        ],
      );

      environment.battery = 10;
      await runner().run(flow);
      environment.battery = 90;
      await runner().run(flow);

      expect(notified, ['Wake me|low', 'Wake me|fine']);
    });

    test('a branch can test what the model wrote', () async {
      final flow = alarmFlow().copyWith(
        blocks: const [
          FlowBlock.ask('x'),
          FlowBlock.branch(
            FlowCondition.answerContains('7AM'),
            then: [FlowBlock.notify('matched')],
          ),
        ],
      );

      await runner().run(flow);

      expect(notified, ['Wake me|matched']);
    });

    test('a branch can nest inside a branch', () async {
      environment
        ..battery = 10
        ..charging = true;
      final flow = alarmFlow().copyWith(
        blocks: const [
          FlowBlock.branch(
            FlowCondition.batteryBelow(30),
            then: [
              FlowBlock.branch(
                FlowCondition(FlowConditionKind.charging),
                then: [FlowBlock.notify('low and charging')],
              ),
            ],
          ),
        ],
      );

      await runner().run(flow);

      expect(notified, ['Wake me|low and charging']);
    });
  });

  group('running in the background', () {
    test('a block that needs the screen stops and asks to be tapped', () async {
      final flow = alarmFlow(granted: true).copyWith(
        blocks: const [
          FlowBlock.action('torch', {'on': 'true'}),
          FlowBlock.action('open_url', {'url': 'https://example.com'}),
          FlowBlock.notify('after'),
        ],
      );

      final run = await runner().run(
        flow,
        triggeredBy: 'event:chargerConnected',
        background: true,
      );

      expect(run.outcome, FlowRunOutcome.needsScreen);
      expect(executor.calls.map((c) => c.action.name), ['torch']);
      expect(notified, isEmpty, reason: 'nothing runs after a stopped block');
    });

    test('the same flow runs fully in the foreground', () async {
      final flow = alarmFlow(granted: true).copyWith(
        blocks: const [
          FlowBlock.action('open_url', {'url': 'https://example.com'}),
        ],
      );

      final run = await runner().run(flow, background: false);

      expect(run.outcome, FlowRunOutcome.completed);
    });

    test('torch, volume, media and vibrate work in the background', () async {
      final flow = alarmFlow(granted: true).copyWith(
        blocks: const [
          FlowBlock.action('torch', {'on': 'true'}),
          FlowBlock.action('volume', {'direction': 'down'}),
          FlowBlock.action('media', {'action': 'pause'}),
          FlowBlock.action('vibrate'),
        ],
      );

      final run = await runner().run(
        flow,
        triggeredBy: 'schedule',
        background: true,
      );

      expect(run.outcome, FlowRunOutcome.completed);
      expect(executor.calls, hasLength(4));
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

class _FakeEnvironment implements FlowEnvironment {
  int battery = 100;
  bool charging = false;

  @override
  Future<FlowEnvironmentSnapshot> snapshot() async => FlowEnvironmentSnapshot(
        now: DateTime(2026, 9, 30, 7, 0),
        batteryPercent: battery,
        charging: charging,
      );
}

class _Notifier implements FlowNotifier {
  _Notifier(this.sent);

  final List<String> sent;

  @override
  Future<void> notify({
    required String flowId,
    required String title,
    required String body,
  }) async =>
      sent.add('$title|$body');
}

class _Speaker implements FlowSpeaker {
  _Speaker(this.said);

  final List<String> said;

  @override
  Future<bool> speak(String text) async {
    said.add(text);
    return true;
  }
}

class _Sink implements FlowOutputSink {
  final List<String> delivered = [];

  @override
  Future<void> deliver(
    FinnFlow flow,
    String text,
    List<WebSource> sources,
  ) async =>
      delivered.add(text);
}

class _Search implements FlowSearch {
  _Search(this.sources);

  final List<WebSource> sources;

  @override
  Future<FlowSearchResult> search(String query) async => FlowSearchResult(
        groundedContext:
            sources.isEmpty ? '' : sources.map((s) => s.snippet).join('\n'),
        sources: sources,
      );
}

class _Model implements FlowModel {
  _Model(this.onAnswer);

  final void Function(String prompt, String context) onAnswer;

  @override
  Future<String> answer(
    String prompt, {
    String groundedContext = '',
    int? maxTokens,
  }) async {
    onAnswer(prompt, groundedContext);
    return 'answer';
  }
}
