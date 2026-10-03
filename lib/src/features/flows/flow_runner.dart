import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/engine/api/web_source.dart';
import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_executor.dart';
import 'package:finn_ai/src/features/flows/flow_ports.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';

/// Runs a flow's blocks and records what happened.
///
/// The runner is the whole point of Flows being automations rather than prompt
/// snippets, and it is also where the safety rule has to live: **a flow cannot
/// act on the device without permission.**
///
/// * A run the user starts asks first: the caller passes the confirmation it
///   just collected as [run]'s `granted`.
/// * A run that *something else* starts (a clock, a charger, the phone booting)
///   has no one to ask, so it needs the flow's standing grant. A flow with a
///   device action and no grant is recorded as [FlowRunOutcome.needsGrant] and
///   does nothing.
///
/// Seams make the whole thing testable without a model, a device or a clock:
/// the model, search, sink, notifier, speaker, environment and executor are
/// ports, and none is reached unless a block asks for it.
class FlowRunner {
  FlowRunner({
    FlowsStore? store,
    this.ask,
    this.model,
    this.search,
    this.sink,
    this.notifier,
    this.speaker,
    this.environment,
    this.executor = const PlatformDeviceActionExecutor(),
    this.clock = DateTime.now,
    this.idFactory,
    this.delay = _realDelay,
  }) : _store = store ?? FlowsStore.instance;

  final FlowsStore _store;

  /// Produces the model's answer for an ask block. Deliberately the only way
  /// this class reaches the model besides [model], so a runner with neither can
  /// still run an automation made of device actions.
  final Future<String> Function(String prompt)? ask;

  /// Richer than [ask]: also receives web material. Preferred when both exist.
  final FlowModel? model;
  final FlowSearch? search;
  final FlowOutputSink? sink;
  final FlowNotifier? notifier;
  final FlowSpeaker? speaker;
  final FlowEnvironment? environment;
  final DeviceActionExecutor executor;
  final DateTime Function() clock;
  final String Function()? idFactory;

  /// Waits. Injected so a test does not sit through a `wait` block.
  final Future<void> Function(Duration) delay;

  static Future<void> _realDelay(Duration d) => Future<void>.delayed(d);

  /// The most tokens one ask block may write. A brief is a few bullet points;
  /// 320 is room for that and not for a runaway.
  static const int maxAnswerTokens = 320;

  /// Most blocks one run will execute, a second line of defence behind the
  /// shape check.
  static const int maxExecuted = 60;

  bool _running = false;
  DateTime? _runStart;

  bool get isRunning => _running;

  /// Whether [triggeredBy] means a person is present and asking.
  static bool startedByUser(String triggeredBy) =>
      triggeredBy == 'manual' ||
      triggeredBy == 'chat' ||
      triggeredBy == 'shortcut';

  /// Runs [flow] and records the result.
  ///
  /// [granted] is the permission for *this* run and only counts for a run the
  /// user started. Any other run uses the flow's stored grant, which is only
  /// ever set by an explicit user action. [background] says the phone is not
  /// being used, so blocks that need the screen stop and ask to be tapped.
  Future<FlowRun> run(
    FinnFlow flow, {
    bool? granted,
    String triggeredBy = 'manual',
    bool background = false,
  }) async {
    if (_running) {
      // Two concurrent runs would interleave their device actions, and the run
      // log would attribute each block to whichever run happened to be reading.
      return _record(
        flow,
        FlowRunOutcome.interrupted,
        const [],
        triggeredBy: triggeredBy,
        detail: 'a run was already in progress',
      );
    }
    _running = true;
    _runStart = clock();
    try {
      final validation = FlowsStore.validate(flow);
      if (!validation.isValid) {
        // Refuse before anything runs. A flow naming an action outside the
        // catalog must not get as far as setting an alarm on its way to
        // failing.
        return _record(
          flow,
          FlowRunOutcome.failed,
          const [],
          triggeredBy: triggeredBy,
          detail: validation.problems.map((p) => p.name).join(','),
        );
      }
      final byUser = startedByUser(triggeredBy);
      if (!byUser && !await _conditionsHold(flow)) {
        return _record(
          flow,
          FlowRunOutcome.skipped,
          const [],
          triggeredBy: triggeredBy,
          detail: 'conditions not met',
        );
      }
      final state = _RunState(
        flow: flow,
        permitted: byUser ? (granted ?? flow.granted) : flow.granted,
        background: background,
      );
      await _runBlocks(flow.blocks, '', state);
      if (state.outcome == FlowRunOutcome.completed && state.results.isEmpty) {
        // A flow whose every block was skipped by a branch still ran.
        state.outcome = FlowRunOutcome.completed;
      }
      return _record(
        flow,
        state.outcome,
        state.results,
        triggeredBy: triggeredBy,
      );
    } finally {
      _running = false;
    }
  }

  Future<bool> _conditionsHold(FinnFlow flow) async {
    if (flow.conditions.isEmpty) return true;
    final env = await _snapshot();
    return flow.conditions.every((c) => c.holds(env));
  }

  Future<FlowEnvironmentSnapshot> _snapshot() async {
    try {
      final read = environment;
      if (read != null) return await read.snapshot();
    } catch (error) {
      debugPrint('FINN_FLOW environment unreadable: ${error.runtimeType}');
    }
    return FlowEnvironmentSnapshot(now: clock());
  }

  /// Runs a lane of blocks in order. Returns once the lane is done or the run
  /// has ended (a failure, a refusal, a `stop`).
  Future<void> _runBlocks(
    List<FlowBlock> blocks,
    String prefix,
    _RunState state,
  ) async {
    for (var index = 0; index < blocks.length; index++) {
      if (state.ended) return;
      if (++state.executed > maxExecuted) {
        state.fail('', FlowBlockKind.stop, 'too many blocks');
        return;
      }
      final block = blocks[index];
      final path = prefix.isEmpty ? '$index' : '$prefix.$index';
      switch (block.kind) {
        case FlowBlockKind.ask:
          await _ask(block, path, state);
        case FlowBlockKind.web:
          await _web(block, path, state);
        case FlowBlockKind.notify:
          await _notify(block, path, state);
        case FlowBlockKind.speak:
          await _speak(block, path, state);
        case FlowBlockKind.action:
          await _action(block, path, state);
        case FlowBlockKind.wait:
          await delay(Duration(seconds: block.seconds));
          state.done(path, block.kind, '${block.seconds}s');
        case FlowBlockKind.saveToChat:
          await _save(path, state);
        case FlowBlockKind.stop:
          state.done(path, block.kind, '');
          state.stopped = true;
        case FlowBlockKind.branch:
          final env = await _snapshot();
          final yes = block.condition!.holds(env, answer: state.lastAnswer);
          state.done(path, block.kind, yes ? 'yes' : 'no');
          await _runBlocks(
            yes ? block.then : block.otherwise,
            '$path.${yes ? 'then' : 'else'}',
            state,
          );
      }
    }
  }

  Future<void> _ask(FlowBlock block, String path, _RunState state) async {
    final generate = model != null
        ? (String prompt) => model!.answer(
              prompt,
              groundedContext: _joinContext(state.pendingContext),
              maxTokens: maxAnswerTokens,
            )
        : ask;
    if (generate == null) {
      state.fail(path, block.kind, 'no model available');
      return;
    }
    // A brief asked to use "the search results above" with none will invent
    // them. Better to say it could not, and stop: the run then reads as failed
    // instead of delivering a confident fiction.
    if (state.sawWeb && state.sourcesSincePrompt == 0) {
      state.fail(path, block.kind, 'no sources');
      return;
    }
    state.sawWeb = false;
    state.sourcesSincePrompt = 0;
    try {
      state.lastAnswer =
          (await generate(await _expand(block.text, state))).trim();
      state.pendingContext.clear();
      state.done(path, block.kind, '${state.lastAnswer.length} chars');
    } catch (error) {
      state.fail(path, block.kind, error.runtimeType.toString());
    }
  }

  Future<void> _web(FlowBlock block, String path, _RunState state) async {
    final searcher = search;
    if (searcher == null) {
      state.fail(path, block.kind, 'no search available');
      return;
    }
    try {
      state.sawWeb = true;
      final query = await _expand(block.text, state);
      final found = await searcher.search(query);
      if (found.groundedContext.isNotEmpty) {
        state.pendingContext.add(found.groundedContext);
      } else {
        // Say what is missing. With other sources present the prompt would
        // otherwise fill the gap from imagination: a brief that had weather
        // but no news wrote the news itself.
        final what = query.replaceFirst(RegExp(r'^\w+:\s*'), '');
        state.pendingContext.add(
          'NO RESULTS were found for "$what". Write "no results" for that '
          'part. Do not make anything up.',
        );
      }
      state.sourcesSincePrompt += found.sources.length;
      for (final source in found.sources) {
        if (!state.sources.any((s) => s.url == source.url)) {
          state.sources.add(source);
        }
      }
      // An offline search is a fact about the world, not a flow failure: the
      // next ask is told there were no results.
      state.done(
        path,
        block.kind,
        found.failed ? 'offline' : '${found.sources.length} sources',
      );
    } catch (error) {
      state.fail(path, block.kind, error.runtimeType.toString());
    }
  }

  Future<void> _notify(FlowBlock block, String path, _RunState state) async {
    var detail = 'no notifier';
    final tell = notifier;
    if (tell != null) {
      try {
        final own = (await _expand(block.text, state)).trim();
        await tell.notify(
          flowId: state.flow.id,
          title: block.title.isEmpty ? state.flow.name : block.title,
          body: _notificationBody(own.isEmpty ? state.lastAnswer : own),
        );
        detail = 'sent';
      } catch (error) {
        detail = error.runtimeType.toString();
      }
    }
    state.done(path, block.kind, detail);
  }

  Future<void> _speak(FlowBlock block, String path, _RunState state) async {
    var detail = 'no voice';
    final voice = speaker;
    if (voice != null) {
      try {
        final own = (await _expand(block.text, state)).trim();
        final said = await voice.speak(own.isEmpty ? state.lastAnswer : own);
        detail = said ? 'spoken' : 'no voice';
      } catch (error) {
        detail = error.runtimeType.toString();
      }
    }
    state.done(path, block.kind, detail);
  }

  Future<void> _save(String path, _RunState state) async {
    var detail = 'nothing to save';
    if (state.lastAnswer.isNotEmpty && sink != null) {
      try {
        await sink!.deliver(state.flow, state.lastAnswer, state.sources);
        detail = 'saved';
      } catch (error) {
        detail = error.runtimeType.toString();
        debugPrint('FINN_FLOW deliver failed: $detail');
      }
    }
    state.done(path, FlowBlockKind.saveToChat, detail);
  }

  Future<void> _action(FlowBlock block, String path, _RunState state) async {
    final name = block.actionName;
    final action = name == null ? null : DeviceActionCatalog.byName(name);
    if (action == null) {
      state.fail(path, block.kind, 'unknown action');
      return;
    }
    if (!state.permitted) {
      // The rule. Stop here, not after the action.
      state.results.add(
        FlowStepResult(
          path: path,
          kind: block.kind,
          outcome: FlowRunOutcome.needsGrant,
        ),
      );
      state.outcome = FlowRunOutcome.needsGrant;
      return;
    }
    if (state.background &&
        !DeviceActionCatalog.runsInBackground(action.name)) {
      state.results.add(
        FlowStepResult(
          path: path,
          kind: block.kind,
          outcome: FlowRunOutcome.needsScreen,
          detail: action.name,
        ),
      );
      state.outcome = FlowRunOutcome.needsScreen;
      return;
    }
    try {
      final result = await executor.execute(
        DeviceActionInvocation(action: action, arguments: block.arguments),
      );
      // `opened` and `performed` are both the block having done its job; the
      // difference is recorded by the executor, not re-decided here.
      if (result.isSuccess) {
        state.done(path, block.kind, result.outcome.name);
      } else {
        state.fail(path, block.kind, result.outcome.name);
      }
    } catch (error) {
      state.fail(path, block.kind, error.runtimeType.toString());
    }
  }

  static String _joinContext(List<String> parts) {
    final joined = parts.join('\n\n');
    // A bounded prompt is a fast prompt on a small phone.
    return joined.length <= 4000 ? joined : joined.substring(0, 4000);
  }

  /// One short paragraph for a notification body.
  static String _notificationBody(String text) {
    final flat = text
        .replaceAll(RegExp(r'[*_#`>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return flat.length <= 240 ? flat : '${flat.substring(0, 240).trimRight()}…';
  }

  /// Fills `{input}` / `{ai}` (the previous answer), `{date}`, `{time}` and
  /// `{battery}` in a block's text.
  Future<String> _expand(String text, _RunState state) async {
    if (!text.contains('{')) return text;
    var out = text
        .replaceAll('{input}', state.lastAnswer)
        .replaceAll('{ai}', state.lastAnswer);
    final now = clock();
    out = out
        .replaceAll('{date}', _isoDate(now))
        .replaceAll('{time}', _clock(now));
    if (out.contains('{battery}')) {
      out =
          out.replaceAll('{battery}', '${(await _snapshot()).batteryPercent}%');
    }
    return out;
  }

  static String _isoDate(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';

  static String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// Runs every enabled flow with a clock-time trigger due at [now].
  ///
  /// A flow that may not run on its own is *not* run: it is recorded as
  /// needing a grant so the user can see that it tried, rather than silently
  /// doing nothing.
  Future<List<FlowRun>> runDueScheduledFlows(
    DateTime now, {
    bool background = false,
  }) =>
      _runMatching(
        (flow) => flow.triggers.any((t) => t.isDueAt(now)),
        triggeredBy: 'schedule',
        background: background,
      );

  /// Runs every enabled flow that has a trigger of [kind].
  Future<List<FlowRun>> runForEvent(
    FlowTriggerKind kind, {
    bool background = false,
  }) =>
      _runMatching(
        (flow) => flow.triggers.any((t) => t.kind == kind),
        triggeredBy: 'event:${kind.name}',
        background: background,
      );

  Future<List<FlowRun>> _runMatching(
    bool Function(FinnFlow flow) matches, {
    required String triggeredBy,
    required bool background,
  }) async {
    final due = _store.flows
        .where((flow) => flow.enabled && flow.isAutomation && matches(flow))
        .toList(growable: false);
    final runs = <FlowRun>[];
    for (final flow in due) {
      if (!flow.autoRunIsPermitted) {
        _runStart = clock();
        runs.add(
          await _record(
            flow,
            FlowRunOutcome.needsGrant,
            const [],
            triggeredBy: triggeredBy,
            detail: 'no standing grant',
          ),
        );
        continue;
      }
      runs.add(
          await run(flow, triggeredBy: triggeredBy, background: background));
    }
    return runs;
  }

  Future<FlowRun> _record(
    FinnFlow flow,
    FlowRunOutcome outcome,
    List<FlowStepResult> steps, {
    String triggeredBy = 'manual',
    String detail = '',
  }) async {
    // The run log records what happened, never what the model said. It is
    // written to disk and read back on device, and a transcript in a log file
    // is a privacy problem the app does not otherwise have.
    final started = _runStart ?? clock();
    final run = FlowRun(
      id: idFactory?.call() ?? 'run-${clock().microsecondsSinceEpoch}',
      flowId: flow.id,
      startedAt: started,
      durationMs: clock().difference(started).inMilliseconds,
      outcome: outcome,
      triggeredBy: triggeredBy,
      steps: steps,
    );
    if (detail.isNotEmpty) {
      debugPrint('FINN_FLOW ${flow.id} $outcome $detail');
    }
    await _store.recordRun(run);
    return run;
  }
}

/// Everything one run accumulates.
class _RunState {
  _RunState({
    required this.flow,
    required this.permitted,
    required this.background,
  });

  final FinnFlow flow;
  final bool permitted;
  final bool background;

  final List<FlowStepResult> results = [];
  final List<String> pendingContext = [];
  final List<WebSource> sources = [];
  String lastAnswer = '';
  bool sawWeb = false;
  int sourcesSincePrompt = 0;
  int executed = 0;
  bool stopped = false;
  FlowRunOutcome outcome = FlowRunOutcome.completed;

  /// A failed block, a refused grant, a block that needs the screen, a declined
  /// confirmation or a `stop` all end the run: later blocks may depend on this
  /// one, and a notification or a device action after a failure is the wrong
  /// thing to do next.
  bool get ended => stopped || outcome != FlowRunOutcome.completed;

  void done(String path, FlowBlockKind kind, String detail) => results.add(
        FlowStepResult(
          path: path,
          kind: kind,
          outcome: FlowRunOutcome.completed,
          detail: detail,
        ),
      );

  void fail(String path, FlowBlockKind kind, String detail) {
    results.add(
      FlowStepResult(
        path: path,
        kind: kind,
        outcome: FlowRunOutcome.failed,
        detail: detail,
      ),
    );
    outcome = FlowRunOutcome.failed;
  }
}
