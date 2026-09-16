import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The browser work a turn did, told inline with the answer it belongs to.
///
/// While the turn runs this is the "searching" signal — a spinner and the live
/// steps as they land — and once it finishes it stays under the reply as the
/// collapsed record of what was searched and read. The pill deliberately
/// matches the sources disclosure so the two read as one cluster of evidence
/// under the answer rather than two unrelated widgets.
class ToolActivityIndicator extends StatelessWidget {
  const ToolActivityIndicator({
    super.key,
    required this.activities,
    required this.busy,
  });

  final List<ToolActivity> activities;

  /// True while the turn that produced [activities] is still running.
  final bool busy;

  /// Rows revealed while collapsed are kept to the latest one so a long
  /// research pass cannot push the answer off screen.
  static const int collapsedRows = 1;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();

    final total = activities.length;
    final canExpand = total > collapsedRows;

    return FluxDisclosure(
      leading: busy
          ? const _ActivitySpinner()
          : FluxIcon(
              icon: FluxIcons.internet,
              size: 14,
              color: FluxColors.mutedOf(context),
            ),
      label: busy
          ? L10n.of(context).chatSearchingInline
          : L10n.of(context).chatSearchedInline,
      // While running, the count is still climbing, so it only appears once the
      // turn is done and the number means something.
      trailing:
          busy || !canExpand ? null : L10n.of(context).chatBrowsingSteps(total),
      expandLabel: L10n.of(context).chatShowSearchSteps,
      collapseLabel: L10n.of(context).chatBrowsingHide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final activity in activities)
            FluxDisclosureRow(
              leading: FluxIcon(
                icon: _iconFor(activity.kind),
                size: 14,
                color: FluxColors.mutedOf(context),
              ),
              title: labelFor(context, activity),
              subtitle: activity.detail.isEmpty ? null : activity.detail,
            ),
        ],
      ),
    );
  }

  static List<List<dynamic>> _iconFor(ToolActivityKind kind) => switch (kind) {
        ToolActivityKind.search => FluxIcons.internet,
        ToolActivityKind.open => FluxIcons.note,
        ToolActivityKind.find => FluxIcons.search,
      };

  /// The display line for one browser tool call.
  static String labelFor(BuildContext context, ToolActivity activity) =>
      switch (activity.kind) {
        ToolActivityKind.search =>
          L10n.of(context).chatBrowsingSearch(activity.label),
        ToolActivityKind.open =>
          L10n.of(context).chatBrowsingOpen(activity.label),
        ToolActivityKind.find =>
          L10n.of(context).chatBrowsingFind(activity.label),
      };
}

/// The small turning mark that says "still working" next to the steps.
class _ActivitySpinner extends StatefulWidget {
  const _ActivitySpinner();

  @override
  State<_ActivitySpinner> createState() => _ActivitySpinnerState();
}

class _ActivitySpinnerState extends State<_ActivitySpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = .15;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _animation,
        child: FluxIcon(
          icon: FluxIcons.loading,
          size: 14,
          color: FluxColors.mutedOf(context),
        ),
      );
}
