import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_block_sheet.dart';
import 'package:finn_ai/src/features/flows/flow_chart.dart';
import 'package:finn_ai/src/features/flows/flow_condition_sheet.dart';
import 'package:finn_ai/src/features/flows/flow_edit.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flow_run_page.dart';
import 'package:finn_ai/src/features/flows/flow_trigger_sheet.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// One flow, drawn as a flowchart and edited in place.
///
/// Every change saves at once: tap a card to change it, tap a "+" on a line to
/// add a step there. There is no draft and no save button, so nothing can be
/// lost by leaving the page.
class FlowEditorPage extends StatelessWidget {
  const FlowEditorPage({
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
        final running = actions.runningId == flow.id;
        final triggered = flow.triggers.any((t) => t.isScheduled || t.isEvent);
        return FinnPage(
          title: flow.name,
          actions: [_menu(context, flow)],
          footer: FinnButton(
            key: Key('flow-run-${flow.id}'),
            label: running ? l10n.flowsRunRunning : l10n.flowsRunAction,
            icon: FluxIcons.arrowRight02,
            onTap: running || flow.blocks.isEmpty
                ? null
                : () => unawaited(_run(context, flow)),
          ),
          children: [
            if (triggered)
              FinnReveal(child: _StatusTile(flow: flow, actions: actions)),
            FlowChart(
              flow: flow,
              onEditTrigger: (i) => unawaited(_editTrigger(context, flow, i)),
              onAddTrigger: () => unawaited(_editTrigger(context, flow, null)),
              onEditCondition: (i) =>
                  unawaited(_editCondition(context, flow, i)),
              onAddCondition: () =>
                  unawaited(_editCondition(context, flow, null)),
              onEditBlock: (lane, i) =>
                  unawaited(_editBlock(context, flow, lane, i)),
              onInsert: (lane, i) => unawaited(_insert(context, flow, lane, i)),
            ),
            if (flow.hasDeviceAction && triggered)
              FinnTile(
                title: l10n.flowsAutoTitle,
                subtitle: l10n.flowsAutoNeedsAllow,
                chevron: false,
                trailing: FinnSwitch(
                  key: Key('flow-grant-${flow.id}'),
                  value: flow.granted,
                  label: l10n.flowsAutoTitle,
                  onChanged: (v) =>
                      unawaited(actions.setGranted(context, flow, v)),
                ),
              ),
            if (flow.enabled && flow.eventTriggers.isNotEmpty)
              FinnCaption(
                actions.notificationsOn == false
                    ? l10n.flowsListenerNeedsNotify
                    : l10n.flowsListenerOn,
              ),
            if (runs.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                l10n.flowsRecentRuns,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
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

  Widget _menu(BuildContext context, FinnFlow flow) {
    final l10n = L10n.of(context);
    return Builder(
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
                label: l10n.flowsRenameTitle,
                icon: FluxIcons.edit,
                onTap: () => unawaited(_rename(context, flow)),
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
    );
  }

  Future<void> _rename(BuildContext context, FinnFlow flow) async {
    final l10n = L10n.of(context);
    final name = await showFinnPrompt(
      context,
      title: l10n.flowsRenameTitle,
      initial: flow.name,
      confirmLabel: l10n.commonSave,
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await actions.update(context, flow, name: name.trim());
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

  Future<void> _editTrigger(
    BuildContext context,
    FinnFlow flow,
    int? index,
  ) async {
    final pick = await pickFlowTrigger(
      context,
      current: index == null ? null : flow.triggers[index],
    );
    if (pick == null || !context.mounted) return;
    final triggers = [...flow.triggers];
    if (pick.trigger == null) {
      if (index != null) triggers.removeAt(index);
    } else if (index == null) {
      triggers.add(pick.trigger!);
    } else {
      triggers[index] = pick.trigger!;
    }
    await actions.update(context, flow, triggers: triggers);
  }

  Future<void> _editCondition(
    BuildContext context,
    FinnFlow flow,
    int? index,
  ) async {
    final pick = await pickFlowCondition(
      context,
      initial: index == null ? null : flow.conditions[index],
      removable: index != null,
    );
    if (pick == null || !context.mounted) return;
    final conditions = [...flow.conditions];
    if (pick.condition == null) {
      if (index != null) conditions.removeAt(index);
    } else if (index == null) {
      conditions.add(pick.condition!);
    } else {
      conditions[index] = pick.condition!;
    }
    await actions.update(context, flow, conditions: conditions);
  }

  Future<void> _editBlock(
    BuildContext context,
    FinnFlow flow,
    FlowLane lane,
    int index,
  ) async {
    final block = FlowEdit.at(flow.blocks, lane, index);
    if (block == null) return;
    final count = FlowEdit.laneBlocks(flow.blocks, lane).length;
    final result = await editFlowBlock(
      context,
      block,
      isNew: false,
      canMoveUp: index > 0,
      canMoveDown: index < count - 1,
    );
    if (result == null || !context.mounted) return;
    final blocks = switch (result.op) {
      FlowBlockOp.save => FlowEdit.replace(
          flow.blocks,
          lane,
          index,
          result.block ?? block,
        ),
      FlowBlockOp.remove => FlowEdit.remove(flow.blocks, lane, index),
      FlowBlockOp.moveUp => FlowEdit.move(flow.blocks, lane, index, -1),
      FlowBlockOp.moveDown => FlowEdit.move(flow.blocks, lane, index, 1),
    };
    await actions.update(context, flow, blocks: blocks);
  }

  Future<void> _insert(
    BuildContext context,
    FinnFlow flow,
    FlowLane lane,
    int index,
  ) async {
    final total = flow.blocks.fold<int>(0, (sum, b) => sum + b.size);
    if (total >= FlowBlock.maxPerFlow) return;
    final kind = await pickFlowBlockKind(
      context,
      canBranch: FlowEdit.canNestBranch(lane),
    );
    if (kind == null || !context.mounted) return;
    var block = newFlowBlock(kind);
    if (kind != FlowBlockKind.saveToChat && kind != FlowBlockKind.stop) {
      final result = await editFlowBlock(context, block, isNew: true);
      if (result == null ||
          result.op != FlowBlockOp.save ||
          result.block == null ||
          !context.mounted) {
        return;
      }
      block = result.block!;
    }
    await actions.update(
      context,
      flow,
      blocks: FlowEdit.insert(flow.blocks, lane, index, block),
    );
  }
}

/// On/off and what happens next, for a flow something else starts.
class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.flow, required this.actions});

  final FinnFlow flow;
  final FlowsActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final next = flow.enabled
        ? flow.scheduledTriggers
            .map((t) => flowNextRun(t, DateTime.now()))
            .whereType<DateTime>()
            .fold<DateTime?>(
              null,
              (a, b) => a == null || b.isBefore(a) ? b : a,
            )
        : null;
    return FinnTile(
      title: flow.name,
      subtitle: !flow.enabled
          ? l10n.flowsDetailPaused
          : next != null
              ? l10n.flowsDetailOn(flowWhen(context, next, withTime: true))
              : flow.eventTriggers.isNotEmpty
                  ? l10n.flowsDetailOnEvent
                  : l10n.flowsDetailOnManual,
      chevron: false,
      trailing: FinnSwitch(
        key: Key('flow-toggle-${flow.id}'),
        value: flow.enabled,
        label: l10n.flowsNameSemantic(flow.name),
        onChanged: (v) => unawaited(actions.setEnabled(context, flow, v)),
      ),
    );
  }
}
