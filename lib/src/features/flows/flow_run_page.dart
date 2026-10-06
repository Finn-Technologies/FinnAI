import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_edit.dart';
import 'package:finn_ai/src/features/flows/flow_icons.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// What one run did, step by step. Never what the model said: the run log
/// records what happened, and the answer lives in the chat it was written to.
class FlowRunPage extends StatelessWidget {
  const FlowRunPage({
    super.key,
    required this.flow,
    required this.run,
    required this.actions,
  });

  final FinnFlow flow;
  final FlowRun run;
  final FlowsActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final seconds = (run.durationMs / 1000).round();
    final wrote = run.steps.any(
      (s) =>
          s.kind == FlowBlockKind.saveToChat &&
          s.outcome == FlowRunOutcome.completed &&
          s.detail == 'saved',
    );
    final finished = run.outcome == FlowRunOutcome.completed
        ? (seconds > 0
            ? l10n.flowsRunFinishedIn(seconds)
            : l10n.flowsRunFinished)
        : flowRunStatus(l10n, run.outcome);
    return FinnPage(
      title: flowWhen(context, run.startedAt, withTime: true),
      footer: Row(
        children: [
          if (wrote && actions.onOpenResult != null) ...[
            Expanded(
              child: FinnButton(
                label: l10n.flowsOpenResult,
                secondary: true,
                onTap: actions.onOpenResult,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FinnButton(
              label: l10n.flowsRunAgain,
              onTap: () async {
                final next = await actions.run(context, flow);
                if (next == null || !context.mounted) return;
                await Navigator.of(context).pushReplacement(
                  FinnPageRoute<void>(
                    child: FlowRunPage(flow: flow, run: next, actions: actions),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      children: [
        FinnCaption('$finished · ${flowRunLine(l10n, run).split(' · ').last}'),
        for (var i = 0; i < run.steps.length; i++)
          FinnReveal(
            index: i,
            child: _StepTile(
              flow: flow,
              step: run.steps[i],
              l10n: l10n,
            ),
          ),
        if (run.steps.isEmpty) FinnCaption(flowRunStatus(l10n, run.outcome)),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.flow,
    required this.step,
    required this.l10n,
  });

  final FinnFlow flow;
  final FlowStepResult step;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final block = FlowEdit.atPath(flow.blocks, step.path);
    final title = block == null
        ? flowBlockTitle(l10n, step.kind)
        : flowBlockSummary(context, block);
    return FinnTile(
      icon: FlowIcons.forBlock(step.kind),
      title: title,
      subtitle: flowRunStatus(l10n, step.outcome),
      chevron: false,
      trailing: step.outcome == FlowRunOutcome.completed
          ? FluxIcon(
              icon: FluxIcons.check,
              size: 22,
              color: FluxColors.actionOf(context),
            )
          : null,
    );
  }
}
