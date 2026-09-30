import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_executor.dart';
import 'package:finn_ai/src/features/flows/flow_ports.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/engine/api/web_source.dart';

/// Runs a flow's steps, in order, and records what happened.
///
/// The runner is the whole point of turning Flows from a prompt-snippet manager
/// into automations, and it is also the place where the safety rule has to
/// live: **a flow cannot act on the device without permission.** A manual run
/// asks; a scheduled run needs a standing grant, and a flow that has neither
/// stops at the first device action with [FlowRunOutcome.needsGrant] rather
/// than proceeding.
///
/// Two seams make the whole thing testable without a model, a device, or a
/// clock: [ask] generates text, and [executor] performs actions. Neither is
/// reached unless a step asks for it.
class FlowRunner {
  FlowRunner({
    FlowsStore? store,
    this.ask,
    this.model,
    this.search,
    this.sink,
    this.notifier,
    this.executor = const PlatformDeviceActionExecutor(),
    this.clock = DateTime.now,
    this.idFactory,
  }) : _store = store ?? FlowsStore.instance;

  final FlowsStore _store;

  /// Produces the model's answer for a prompt step.
  ///
  /// Deliberately the only way this class reaches the model: a runner with no
  /// [ask] can still execute an automation, which is what makes the safety
  /// tests cheap and what keeps a prompt step from being a hidden chat turn.
  final Future<String> Function(String prompt)? ask;

  /// Richer than [ask]: also receives web material for the step. Preferred when
  /// both are given.
  final FlowModel? model;

  /// Runs a `browse` step. Without it a browse step fails, and the flow stops.
  final FlowSearch? search;

  /// Receives the written result at the end of a successful run.
  final FlowOutputSink? sink;

  /// Posts the `notify` step.
  final FlowNotifier? notifier;

  final DeviceActionExecutor executor;
  final DateTime Function() clock;

  /// Supplies run ids. Injected so a test can make them deterministic.
  final String Function()? idFactory;

  bool _running = false;

  bool get isRunning => _running;

  /// Runs [flow] and records the result.
  ///
  /// [granted] is the permission for *this* run. It defaults to the flow's
  /// stored grant, which is only ever set by an explicit user action — so a
  /// scheduled run with no grant stops, and a manual run still stops unless
  /// the caller passes the confirmation it just collected.
  Future<FlowRun> run(FinnFlow flow,
      {bool? granted, String triggeredBy = 'manual'}) async {
    if (_running) {
      // Two concurrent runs would interleave their device actions, and the run
      // log would attribute each step to whichever run happened to be reading.
      return _record(
        flow,
        FlowRunOutcome.interrupted,
        const [],
        triggeredBy: triggeredBy,
        detail: 'a run was already in progress',
      );
    }
    _running = true;
    final results = <FlowStepResult>[];
    var outcome = FlowRunOutcome.completed;
    var lastAnswer = '';
    // Web material gathered by browse steps, consumed by the next prompt step.
    final pendingContext = <String>[];
    final allSources = <WebSource>[];
    var produced = false;
    var sawBrowse = false;
    var sourcesSincePrompt = 0;
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

      final permitted = granted ?? flow.granted;
      for (var index = 0; index < flow.steps.length; index++) {
        final step = flow.steps[index];
        switch (step.kind) {
          case FlowStepKind.prompt:
            final generate = model != null
                ? (String prompt) => model!.answer(
                      prompt,
                      groundedContext: _joinContext(pendingContext),
                    )
                : ask;
            if (generate == null) {
              results.add(FlowStepResult(
                index: index,
                kind: step.kind,
                outcome: FlowRunOutcome.failed,
                detail: 'no model available',
              ));
              outcome = FlowRunOutcome.failed;
              break;
            }
            // A brief asked to use "the search results above" with none will
            // invent them. Better to say it could not, and stop: the run then
            // reads as failed instead of delivering a confident fiction.
            if (sawBrowse && sourcesSincePrompt == 0) {
              results.add(FlowStepResult(
                index: index,
                kind: step.kind,
                outcome: FlowRunOutcome.failed,
                detail: 'no sources',
              ));
              outcome = FlowRunOutcome.failed;
              break;
            }
            sawBrowse = false;
            sourcesSincePrompt = 0;
            try {
              lastAnswer =
                  (await generate(_expand(step.text, lastAnswer))).trim();
              pendingContext.clear();
              produced = produced || lastAnswer.isNotEmpty;
              results.add(FlowStepResult(
                index: index,
                kind: step.kind,
                outcome: FlowRunOutcome.completed,
                detail: '${lastAnswer.length} chars',
              ));
            } catch (error) {
              results.add(FlowStepResult(
                index: index,
                kind: step.kind,
                outcome: FlowRunOutcome.failed,
                detail: error.runtimeType.toString(),
              ));
              outcome = FlowRunOutcome.failed;
            }

          case FlowStepKind.browse:
            final searcher = search;
            if (searcher == null) {
              results.add(FlowStepResult(
                index: index,
                kind: step.kind,
                outcome: FlowRunOutcome.failed,
                detail: 'no search available',
              ));
              outcome = FlowRunOutcome.failed;
              break;
            }
            try {
              sawBrowse = true;
              final found =
                  await searcher.search(_expand(step.text, lastAnswer));
              if (found.groundedContext.isNotEmpty) {
                pendingContext.add(found.groundedContext);
              } else {
                // Say what is missing. With other sources present the prompt
                // would otherwise fill the gap from imagination: a brief that
                // had weather but no news wrote the news itself.
                final what = _expand(step.text, '')
                    .replaceFirst(RegExp(r'^\w+:\s*'), '');
                pendingContext.add(
                  'NO RESULTS were found for "$what". Write "no results" for '
                  'that part. Do not make anything up.',
                );
              }
              sourcesSincePrompt += found.sources.length;
              for (final source in found.sources) {
                if (!allSources.any((s) => s.url == source.url)) {
                  allSources.add(source);
                }
              }
              // An offline search is a fact about the world, not a flow
              // failure: the next prompt is told there were no results.
              results.add(FlowStepResult(
                index: index,
                kind: step.kind,
                outcome: FlowRunOutcome.completed,
                detail: found.failed
                    ? 'offline'
                    : '${found.sources.length} sources',
              ));
            } catch (error) {
              results.add(FlowStepResult(
                index: index,
                kind: step.kind,
                outcome: FlowRunOutcome.failed,
                detail: error.runtimeType.toString(),
              ));
              outcome = FlowRunOutcome.failed;
            }

          case FlowStepKind.notify:
            var notified = 'no notifier';
            final tell = notifier;
            if (tell != null) {
              try {
                await tell.notify(
                  flowId: flow.id,
                  title: flow.name,
                  body: _notificationBody(
                    lastAnswer.isEmpty ? _expand(step.text, '') : lastAnswer,
                  ),
                );
                notified = 'sent';
              } catch (error) {
                notified = error.runtimeType.toString();
              }
            }
            results.add(FlowStepResult(
              index: index,
              kind: step.kind,
              outcome: FlowRunOutcome.completed,
              detail: notified,
            ));

          case FlowStepKind.deviceAction:
            if (!permitted) {
              // The rule. Stop here, not after the action.
              results.add(FlowStepResult(
                index: index,
                kind: step.kind,
                outcome: FlowRunOutcome.needsGrant,
              ));
              outcome = FlowRunOutcome.needsGrant;
              break;
            }
            final executed = await _execute(step);
            results.add(executed);
            if (executed.outcome != FlowRunOutcome.completed) {
              outcome = FlowRunOutcome.failed;
            }
        }
        // A failed step, a refused grant or a declined confirmation all end the
        // run: later steps may depend on this one, and a notification or a
        // device action after a failure is the wrong thing to do next.
        if (outcome != FlowRunOutcome.completed) break;
      }
      if (outcome == FlowRunOutcome.completed && produced && sink != null) {
        try {
          await sink!.deliver(flow, lastAnswer, allSources);
        } catch (error) {
          debugPrint('FINN_FLOW deliver failed: ${error.runtimeType}');
        }
      }
      return _record(flow, outcome, results, triggeredBy: triggeredBy);
    } finally {
      _running = false;
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

  /// Fills `{input}` (the previous answer) and `{date}` (today, ISO) in a step.
  String _expand(String text, String previous) => text
      .replaceAll('{input}', previous)
      .replaceAll('{date}', _isoDate(clock()));

  static String _isoDate(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';

  /// Runs every flow whose trigger is due at [now].
  ///
  /// Returns the runs it started. A flow whose scheduled run is not permitted
  /// is *not* run: it is recorded as needing a grant so the user can see that
  /// it tried, rather than silently doing nothing.
  Future<List<FlowRun>> runDueScheduledFlows(DateTime now) async {
    final due = _store.flows
        .where((flow) => flow.enabled && flow.trigger.isDueAt(now))
        .toList(growable: false);
    final runs = <FlowRun>[];
    for (final flow in due) {
      if (!flow.scheduledRunIsPermitted) {
        runs.add(await _record(
          flow,
          FlowRunOutcome.needsGrant,
          const [],
          triggeredBy: 'schedule',
          detail: 'no standing grant',
        ));
        continue;
      }
      runs.add(await run(flow, triggeredBy: 'schedule'));
    }
    return runs;
  }

  Future<FlowStepResult> _execute(FlowStep step) async {
    final name = step.actionName;
    final action = name == null ? null : DeviceActionCatalog.byName(name);
    if (action == null) {
      return FlowStepResult(
        index: -1,
        kind: step.kind,
        outcome: FlowRunOutcome.failed,
        detail: 'unknown action',
      );
    }
    try {
      final result = await executor.execute(DeviceActionInvocation(
        action: action,
        arguments: step.arguments,
      ));
      return FlowStepResult(
        index: -1,
        kind: step.kind,
        // `opened` and `performed` are both the step having done its job; the
        // difference is recorded by the executor, not re-decided here.
        outcome:
            result.isSuccess ? FlowRunOutcome.completed : FlowRunOutcome.failed,
        detail: result.outcome.name,
      );
    } catch (error) {
      return FlowStepResult(
        index: -1,
        kind: step.kind,
        outcome: FlowRunOutcome.failed,
        detail: error.runtimeType.toString(),
      );
    }
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
    final run = FlowRun(
      id: idFactory?.call() ?? 'run-${clock().microsecondsSinceEpoch}',
      flowId: flow.id,
      startedAt: clock(),
      outcome: outcome,
      triggeredBy: triggeredBy,
      steps: [
        for (var i = 0; i < steps.length; i++)
          FlowStepResult(
            index: steps[i].index < 0 ? i : steps[i].index,
            kind: steps[i].kind,
            outcome: steps[i].outcome,
            detail: steps[i].detail,
          ),
      ],
    );
    if (detail.isNotEmpty) {
      debugPrint('FINN_FLOW $flow.id $outcome $detail');
    }
    await _store.recordRun(run);
    return run;
  }
}
