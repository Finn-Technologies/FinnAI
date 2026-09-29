import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The browser work a turn did, told inline with the answer it belongs to.
///
/// While the turn runs this is the "searching" signal and once it finishes it
/// stays under the reply as the record of what was searched and read. The rows
/// are the design's: a 24px mark and a muted 14px label, with no surface of
/// their own, so they read as annotations of the answer above them.
class ToolActivityIndicator extends StatelessWidget {
  const ToolActivityIndicator({
    super.key,
    required this.activities,
    required this.busy,
  });

  final List<ToolActivity> activities;

  /// True while the turn that produced [activities] is still running.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty && !busy) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final activity in activities)
          _ActivityRow(
            leading: FluxIcon(
              icon: _iconFor(activity.kind),
              size: 21,
              color: FluxColors.mutedOf(context),
            ),
            label: labelFor(context, activity),
          ),
        if (busy)
          _ActivityRow(
            leading: const _ActivitySpinner(),
            label: L10n.of(context).chatSearchingInline,
          ),
      ],
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

/// One step row: the mark, then the muted label on the design's 15px rhythm.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.leading, required this.label});

  final Widget leading;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 24,
              child: Center(child: leading),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'InstrumentSans',
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                  color: FluxColors.inkOf(context).withValues(alpha: .55),
                ),
              ),
            ),
          ],
        ),
      );
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
