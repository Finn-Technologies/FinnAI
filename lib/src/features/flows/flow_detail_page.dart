import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flow_run_page.dart';
import 'package:finn_ai/src/features/flows/flow_schedule_sheet.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// One flow: when it runs, what it does, how its recent runs went.
class FlowDetailPage extends StatelessWidget {
  const FlowDetailPage({
    super.key,
    required this.flowId,
    required this.actions,
  });

  final String flowId;
  final FlowsActions actions;

  FinnFlow? _flow() =>
      actions.store.flows.where((f) => f.id == flowId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([actions.store, actions]),
      builder: (context, _) {
        final flow = _flow();
        if (flow == null) {
          // Deleted from here: leave once the frame is done.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const SizedBox.shrink();
        }
        final runs = actions.store.runsOf(flow.id).take(5).toList();
        final next =
            flow.enabled ? flowNextRun(flow.trigger, DateTime.now()) : null;
        final running = actions.runningId == flow.id;
        return FinnPage(
          title: flow.name,
          actions: [
            Builder(
              builder: (menuContext) => FinnCircleButton.icon(
                icon: FluxIcons.moreHorizontal,
                label: l10n.flowsActionsTooltip,
                onTap: () => unawaited(
                  showFinnMenu(
                    context,
                    anchor: finnAnchorOf(menuContext),
                    items: [
                      FinnMenuItem(
                        label: l10n.flowsRunAction,
                        icon: FluxIcons.arrowRight02,
                        onTap: () => unawaited(_run(context, flow)),
                      ),
                      FinnMenuItem(
                        label: l10n.flowsMenuEdit,
                        icon: FluxIcons.edit,
                        onTap: () => unawaited(_schedule(context, flow)),
                      ),
                      FinnMenuItem(
                        label: flow.enabled
                            ? l10n.flowsMenuPause
                            : l10n.flowsMenuResume,
                        icon: FluxIcons.timer,
                        onTap: () => unawaited(
                          actions.setEnabled(context, flow, !flow.enabled),
                        ),
                      ),
                      FinnMenuItem(
                        label: l10n.flowsMenuDuplicate,
                        icon: FluxIcons.copy,
                        onTap: () => unawaited(actions.duplicate(flow)),
                      ),
                      FinnMenuItem(
                        label: l10n.flowsMenuDelete,
                        icon: FluxIcons.close,
                        destructive: true,
                        onTap: () => unawaited(actions.delete(context, flow)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          footer: FinnButton(
            key: Key('flow-run-${flow.id}'),
            label: l10n.flowsRunAction,
            icon: FluxIcons.arrowRight02,
            onTap: running ? null : () => unawaited(_run(context, flow)),
          ),
          children: [
            FinnReveal(
              child: FinnTile(
                title: flow.name,
                subtitle: !flow.enabled
                    ? l10n.flowsDetailPaused
                    : next == null
                        ? l10n.flowsDetailOnManual
                        : l10n.flowsDetailOn(
                            flowWhen(context, next, withTime: true),
                          ),
                chevron: false,
                trailing: FinnSwitch(
                  key: Key('flow-toggle-${flow.id}'),
                  value: flow.enabled,
                  label: l10n.flowsNameSemantic(flow.name),
                  onChanged: (v) =>
                      unawaited(actions.setEnabled(context, flow, v)),
                ),
              ),
            ),
            _Heading(l10n.flowsWhen),
            FinnTile(
              key: Key('flow-schedule-${flow.id}'),
              icon: FluxIcons.alarm,
              title: flowScheduleLabel(context, flow.trigger),
              onTap: () => unawaited(_schedule(context, flow)),
            ),
            if (actions.notificationsOn == false &&
                flow.enabled &&
                flow.trigger.isScheduled)
              FinnCaption(l10n.flowsNotifyOff),
            _Heading(l10n.flowsThen),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              decoration: BoxDecoration(
                color: FluxColors.controlOf(context),
                borderRadius: BorderRadius.circular(FluxRadius.card),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < flow.steps.length; i++)
                    Container(
                      constraints: const BoxConstraints(minHeight: 50),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        border: i == flow.steps.length - 1
                            ? null
                            : Border(
                                bottom: BorderSide(
                                  color: FluxColors.lineOf(context),
                                ),
                              ),
                      ),
                      child: Text(
                        flowStepLabel(l10n, flow.steps[i]),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
            if (flow.hasDeviceAction)
              FinnTile(
                title: l10n.flowsGrantLabel,
                subtitle: l10n.flowsGrantExplain,
                chevron: false,
                trailing: FinnSwitch(
                  key: Key('flow-grant-${flow.id}'),
                  value: flow.granted,
                  label: l10n.flowsGrantLabel,
                  onChanged: (v) =>
                      unawaited(actions.setGranted(context, flow, v)),
                ),
              ),
            _Heading(l10n.flowsRecentRuns),
            if (runs.isEmpty) FinnCaption(l10n.flowsNoRunsYet),
            for (final run in runs)
              FinnTile(
                title: flowWhen(context, run.startedAt, withTime: true),
                subtitle: flowRunLine(l10n, run),
                onTap: () => Navigator.of(context).push(
                  FinnPageRoute<void>(
                    child: FlowRunPage(
                      flow: flow,
                      run: run,
                      actions: actions,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _run(BuildContext context, FinnFlow flow) async {
    final run = await actions.run(context, flow);
    if (run == null || !context.mounted) return;
    unawaited(
      Navigator.of(context).push(
        FinnPageRoute<void>(
          child: FlowRunPage(flow: flow, run: run, actions: actions),
        ),
      ),
    );
  }

  Future<void> _schedule(BuildContext context, FinnFlow flow) async {
    final trigger = await showFlowSchedule(context, flow.trigger);
    if (trigger == null || !context.mounted) return;
    await actions.setTrigger(context, flow, trigger);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(5, 8, 5, 0),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}
