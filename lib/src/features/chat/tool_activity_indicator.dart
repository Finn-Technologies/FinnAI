import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/chat/from_you_sheet.dart';
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
            icon: _iconFor(activity.kind),
            label: labelFor(context, activity),
            done: true,
            onTap: activity.kind == ToolActivityKind.you
                ? () => unawaited(showFromYouSheet(context, activity))
                : null,
          ),
        if (busy)
          _ActivityRow(
            icon: FluxIcons.search,
            label: L10n.of(context).chatSearchingInline,
            done: false,
          ),
      ],
    );
  }

  static IconData _iconFor(ToolActivityKind kind) => switch (kind) {
        ToolActivityKind.search => FluxIcons.internet,
        ToolActivityKind.open => FluxIcons.note,
        ToolActivityKind.find => FluxIcons.search,
        ToolActivityKind.you => FluxIcons.you,
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
        ToolActivityKind.you => L10n.of(context).chatUsedFromYou(
            int.tryParse(activity.label) ?? 0,
          ),
      };
}

/// One step row, as the design draws it: a 24dp dark tile with a white glyph,
/// a 14dp label, and a check once the step has finished (a spinner before).
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.label,
    required this.done,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = FluxColors.actionOf(context);
    final row = Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: FluxIcon(
              icon: icon,
              size: 16,
              color: FluxColors.actionInkOf(context),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ink),
          ),
        ),
        const SizedBox(width: 10),
        if (done)
          FluxIcon(icon: FluxIcons.check, size: 18, color: ink)
        else
          const _ActivitySpinner(),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          FluxIcon(
            icon: FluxIcons.arrowRight01,
            size: 16,
            color: FluxColors.mutedOf(context),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: onTap == null
          ? row
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: row,
            ),
    );
  }
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
