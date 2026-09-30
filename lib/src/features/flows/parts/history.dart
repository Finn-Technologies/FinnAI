part of '../flows_page.dart';

/// What an automation did, and whether the user or the schedule did it.
///
/// A flow that runs by itself is something that happened *to* the user, so
/// being able to see that it did — and what it did — is the difference between
/// an automation and a surprise.
class _RunHistory extends StatelessWidget {
  const _RunHistory({required this.runs});

  final List<FlowRun> runs;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.flowsHistoryTitle,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: FluxColors.mutedOf(context),
              ),
        ),
        const SizedBox(height: 6),
        for (final run in runs.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                FluxIcon(
                  icon: run.outcome == FlowRunOutcome.completed
                      ? FluxIcons.check
                      : FluxIcons.error,
                  size: 14,
                  color: run.outcome == FlowRunOutcome.completed
                      ? FluxColors.successOf(context)
                      : FluxColors.warningOf(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_outcomeLabel(context, run.outcome)} · '
                    '${run.triggeredBy == 'schedule' ? l10n.flowsRunBySchedule : l10n.flowsRunByYou}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FluxColors.secondaryInkOf(context),
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _outcomeLabel(BuildContext context, FlowRunOutcome outcome) {
    final l10n = L10n.of(context);
    return switch (outcome) {
      FlowRunOutcome.completed => l10n.flowsRunCompleted,
      FlowRunOutcome.declined => l10n.flowsRunDeclined,
      FlowRunOutcome.failed => l10n.flowsRunFailed,
      FlowRunOutcome.interrupted => l10n.flowsRunInterrupted,
      // The one a user can act on: the flow wanted to run by itself and was
      // not allowed to.
      FlowRunOutcome.needsGrant => l10n.flowsNeedsGrant,
    };
  }
}
