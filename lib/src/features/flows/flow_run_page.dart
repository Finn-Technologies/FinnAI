import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
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
    final wrote = flow.steps.any((s) => s.kind == FlowStepKind.prompt) &&
        run.outcome == FlowRunOutcome.completed;
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
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        FlowRunPage(flow: flow, run: next, actions: actions),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      children: [
        FinnCaption(finished),
        for (var i = 0; i < flow.steps.length; i++)
          FinnReveal(
            index: i,
            child: FinnTile(
              icon: switch (flow.steps[i].kind) {
                FlowStepKind.browse => FluxIcons.internet,
                FlowStepKind.deviceAction => FluxIcons.alarm,
                FlowStepKind.notify => FluxIcons.alarm,
                FlowStepKind.prompt => FluxIcons.magic,
              },
              title: flowStepLabel(l10n, flow.steps[i]),
              subtitle: _resultFor(l10n, i),
              chevron: false,
              trailing: _resultOutcome(i) == FlowRunOutcome.completed
                  ? FluxIcon(
                      icon: FluxIcons.check,
                      size: 22,
                      strokeWidth: 1.5,
                      color: FluxColors.actionOf(context),
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  FlowRunOutcome? _resultOutcome(int index) {
    for (final step in run.steps) {
      if (step.index == index) return step.outcome;
    }
    return null;
  }

  String? _resultFor(AppLocalizations l10n, int index) {
    final outcome = _resultOutcome(index);
    return outcome == null ? null : flowRunStatus(l10n, outcome);
  }
}
