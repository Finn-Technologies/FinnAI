import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/flows/flow_edit.dart';
import 'package:finn_ai/src/features/flows/flow_icons.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// What each kind of node is coloured with: the saturated hues of the step
/// picker (`flowBlockColor`), so a flow reads as the same coloured sequence
/// in the picker and in the chart. Restated here rather than imported so the
/// chart has no dependency on the sheets.
abstract final class FlowTints {
  static const trigger = Color(0xFF22A35A);
  static const condition = Color(0xFFE0A100);
  static const ask = Color(0xFF8B5CF6);
  static const web = Color(0xFF3B82F6);
  static const notify = Color(0xFFF97316);
  static const speak = Color(0xFFEC4899);
  static const action = Color(0xFF14A3A0);
  static const save = Color(0xFF6366F1);
  static const quiet = Color(0xFF6B7280);

  static Color forBlock(FlowBlockKind kind) => switch (kind) {
        FlowBlockKind.ask => ask,
        FlowBlockKind.web => web,
        FlowBlockKind.notify => notify,
        FlowBlockKind.speak => speak,
        FlowBlockKind.action => action,
        FlowBlockKind.branch => condition,
        FlowBlockKind.saveToChat => save,
        FlowBlockKind.wait || FlowBlockKind.stop => quiet,
      };
}

/// A flow drawn as a flowchart: what starts it, what must hold, then the steps
/// in order with their branches, joined by lines you can tap to add a step.
///
/// The chart only draws and reports taps; every edit is made by the page that
/// owns it, through [FlowEdit].
class FlowChart extends StatelessWidget {
  const FlowChart({
    super.key,
    required this.flow,
    required this.onEditTrigger,
    required this.onAddTrigger,
    required this.onEditCondition,
    required this.onAddCondition,
    required this.onEditBlock,
    required this.onInsert,
  });

  final FinnFlow flow;
  final void Function(int index) onEditTrigger;
  final VoidCallback onAddTrigger;
  final void Function(int index) onEditCondition;
  final VoidCallback onAddCondition;
  final void Function(FlowLane lane, int index) onEditBlock;
  final void Function(FlowLane lane, int index) onInsert;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final auto = flow.triggers.any((t) => t.isScheduled || t.isEvent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(l10n.flowsEdWhen),
        if (flow.triggers.isEmpty)
          _NodeCard(
            key: const Key('flow-trigger-manual'),
            icon: FlowIcons.hand,
            tint: FlowTints.trigger,
            title: l10n.flowsEdWhen,
            summary: l10n.flowsEdManualStart,
            onTap: onAddTrigger,
          )
        else
          for (var i = 0; i < flow.triggers.length; i++) ...[
            if (i > 0) _OrLabel(l10n.flowsEdOr),
            _NodeCard(
              key: Key('flow-trigger-$i'),
              icon: FlowIcons.forTrigger(flow.triggers[i].kind),
              tint: FlowTints.trigger,
              title: l10n.flowsEdWhen,
              summary: flowTriggerLabel(l10n, flow.triggers[i]),
              onTap: () => onEditTrigger(i),
            ),
          ],
        if (flow.triggers.length < FlowTrigger.maxPerFlow)
          _AddChip(
            key: const Key('flow-add-trigger'),
            label: l10n.flowsEdAddTrigger,
            onTap: onAddTrigger,
          ),
        const _Line(),
        if (flow.conditions.isNotEmpty ||
            flow.triggers.any((t) => !t.isManual)) ...[
          _Heading(l10n.flowsEdOnlyIf),
          for (var i = 0; i < flow.conditions.length; i++)
            _NodeCard(
              key: Key('flow-condition-$i'),
              icon: FlowIcons.forCondition(flow.conditions[i].kind),
              tint: FlowTints.condition,
              title: l10n.flowsEdOnlyIf,
              summary: flowConditionLabel(l10n, flow.conditions[i]),
              onTap: () => onEditCondition(i),
            ),
          if (flow.conditions.length < FlowCondition.maxPerFlow)
            _AddChip(
              key: const Key('flow-add-condition'),
              label: l10n.flowsEdAddCondition,
              onTap: onAddCondition,
            ),
          const _Line(),
        ],
        _Heading(l10n.flowsEdThen),
        _LaneView(
          blocks: flow.blocks,
          lane: FlowLane.root,
          autoTriggered: auto,
          onEditBlock: onEditBlock,
          onInsert: onInsert,
        ),
        const _EndPill(),
      ],
    );
  }
}

/// One lane of blocks with an insert line before, between and after them.
class _LaneView extends StatelessWidget {
  const _LaneView({
    required this.blocks,
    required this.lane,
    required this.autoTriggered,
    required this.onEditBlock,
    required this.onInsert,
  });

  final List<FlowBlock> blocks;
  final FlowLane lane;
  final bool autoTriggered;
  final void Function(FlowLane lane, int index) onEditBlock;
  final void Function(FlowLane lane, int index) onInsert;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blocks.isEmpty && lane == FlowLane.root)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l10n.flowsEdNoSteps,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FluxColors.mutedOf(context),
                  ),
            ),
          ),
        for (var i = 0; i < blocks.length; i++) ...[
          _InsertLine(
            key: Key('flow-insert-${_key(lane)}-$i'),
            onTap: () => onInsert(lane, i),
          ),
          _BlockView(
            block: blocks[i],
            lane: lane,
            index: i,
            autoTriggered: autoTriggered,
            onEditBlock: onEditBlock,
            onInsert: onInsert,
          ),
        ],
        _InsertLine(
          key: Key('flow-insert-${_key(lane)}-${blocks.length}'),
          onTap: () => onInsert(lane, blocks.length),
          last: true,
        ),
      ],
    );
  }

  static String _key(FlowLane lane) => lane.via.isEmpty
      ? 'root'
      : lane.via.map((s) => '${s.index}${s.otherwise ? 'e' : 't'}').join('-');
}

class _BlockView extends StatelessWidget {
  const _BlockView({
    required this.block,
    required this.lane,
    required this.index,
    required this.autoTriggered,
    required this.onEditBlock,
    required this.onInsert,
  });

  final FlowBlock block;
  final FlowLane lane;
  final int index;
  final bool autoTriggered;
  final void Function(FlowLane lane, int index) onEditBlock;
  final void Function(FlowLane lane, int index) onInsert;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final needsScreen = autoTriggered &&
        block.kind == FlowBlockKind.action &&
        !DeviceActionCatalog.runsInBackground(block.actionName ?? '');
    final card = _NodeCard(
      key: Key('flow-block-${_LaneView._key(lane)}-$index'),
      icon: FlowIcons.forBlock(block.kind),
      tint: FlowTints.forBlock(block.kind),
      title: flowBlockTitle(l10n, block.kind),
      summary: flowBlockSummary(context, block),
      note: needsScreen ? l10n.flowsBgNeedsScreen : null,
      onTap: () => onEditBlock(lane, index),
    );
    if (block.kind != FlowBlockKind.branch) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        _BranchLane(
          label: l10n.flowsEdYes,
          color: const Color(0xFF6BBF8C),
          child: _LaneView(
            blocks: block.then,
            lane: lane.into(index, otherwise: false),
            autoTriggered: autoTriggered,
            onEditBlock: onEditBlock,
            onInsert: onInsert,
          ),
        ),
        _BranchLane(
          label: l10n.flowsEdOtherwise,
          color: FluxColors.mutedOf(context),
          child: _LaneView(
            blocks: block.otherwise,
            lane: lane.into(index, otherwise: true),
            autoTriggered: autoTriggered,
            onEditBlock: onEditBlock,
            onInsert: onInsert,
          ),
        ),
      ],
    );
  }
}

/// The yes or otherwise lane of a branch: a labelled rail with its own steps.
class _BranchLane extends StatelessWidget {
  const _BranchLane({
    required this.label,
    required this.color,
    required this.child,
  });

  final String label;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 22, top: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 2)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(FluxRadius.pill),
                    ),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      );
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    super.key,
    required this.icon,
    required this.tint,
    required this.title,
    required this.summary,
    required this.onTap,
    this.note,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String summary;
  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      onTap: onTap,
      label: '$title. $summary',
      excludeSemantics: true,
      child: Material(
        color: FluxColors.cardOf(context),
        borderRadius: BorderRadius.circular(FluxRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(FluxRadius.md),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color.lerp(tint, Colors.white, .18)!, tint],
                      ),
                    ),
                    child: Center(
                      child:
                          FluxIcon(icon: icon, size: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.labelMedium?.copyWith(
                            color: FluxColors.mutedOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyLarge,
                        ),
                        if (note != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            note!,
                            style: theme.labelMedium?.copyWith(
                              color: FluxColors.warningOf(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: FluxColors.mutedOf(context),
                fontWeight: FontWeight.w600,
                letterSpacing: .4,
              ),
        ),
      );
}

class _OrLabel extends StatelessWidget {
  const _OrLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: FluxColors.mutedOf(context),
                ),
          ),
        ),
      );
}

/// A plain connector between sections.
class _Line extends StatelessWidget {
  const _Line();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 2,
          height: 26,
          margin: const EdgeInsets.symmetric(vertical: 2),
          color: FluxColors.lineOf(context),
        ),
      );
}

/// A connector with a "+" on it: tap to add a step at this place.
class _InsertLine extends StatelessWidget {
  const _InsertLine({super.key, required this.onTap, this.last = false});

  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final line = FluxColors.lineOf(context);
    void tap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      button: true,
      label: L10n.of(context).flowsEdInsertHere,
      onTap: tap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: tap,
        radius: 28,
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(child: Container(width: 2, height: 48, color: line)),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: FluxColors.canvasOf(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: line, width: 1.5),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 17,
                  color: FluxColors.mutedOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            button: true,
            onTap: onTap,
            label: label,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(FluxRadius.pill),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: FluxColors.mutedOf(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: FluxColors.mutedOf(context),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _EndPill extends StatelessWidget {
  const _EndPill();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: FluxColors.cardOf(context),
            borderRadius: BorderRadius.circular(FluxRadius.pill),
          ),
          child: Text(
            L10n.of(context).flowsEdEnd,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: FluxColors.mutedOf(context),
                ),
          ),
        ),
      );
}
