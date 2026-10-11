import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// Step progress: the filled span, an 8px gap, then the remaining track.
class StepProgressBar extends StatefulWidget {
  const StepProgressBar({super.key, required this.quarters});

  /// Filled quarters of the 200px track, 1..4.
  final int quarters;

  static const double _track = 200;
  static const double _gap = 8;

  @override
  State<StepProgressBar> createState() => StepProgressBarState();
}

class StepProgressBarState extends State<StepProgressBar> {
  /// What the bar last showed. A step's bar grows on from the previous
  /// step's instead of from empty, so the bar reads as one bar filling up
  /// while the steps fade through each other.
  ///
  /// Deliberately per-instance rather than `static`: a static made a second
  /// pass through the flow — or the upgrade screen, which reuses this bar in
  /// the same process — begin from the previous pass's final value, so the
  /// bar animated *downwards* from a stale fill.
  double _shown = 0;

  @override
  void didUpdateWidget(StepProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The bar only ever grows.
    if (widget.quarters < oldWidget.quarters) _shown = 0;
  }

  @override
  Widget build(BuildContext context) {
    // The design carves the gap out of the fill so each step lands on a
    // quarter of the track: 46 / 96 / 146 px for steps one to three. The bar
    // fills up to that point as each step appears, so the flow reads as
    // progress rather than as a bar that is simply replaced.
    final target = (StepProgressBar._track * widget.quarters / 4 - 4)
        .clamp(0.0, StepProgressBar._track);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _shown, end: target),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, filled, _) {
        _shown = filled;
        final track = StepProgressBar._track;
        final gap = StepProgressBar._gap;
        final rest = (track - filled - (filled > 0 && filled < track ? gap : 0))
            .clamp(0.0, track);
        Widget bar(Color color) => ClipRRect(
              borderRadius: BorderRadius.circular(FluxRadius.pill),
              child: ColoredBox(color: color),
            );
        // The remaining track used to be painted in the tile fill, which on
        // the page's own white card is a 1.10:1 rule — a nub floating in
        // nothing. A 12% ink wash matches the wide layout and clears the 3:1
        // a non-text indicator needs.
        final ink = FluxColors.inkOf(context);
        return SizedBox(
          width: track,
          height: 6,
          child: Row(
            // Stretch so the bars fill the track's height: a childless
            // ColoredBox collapses to nothing under loose cross-axis
            // constraints.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (filled > 0) SizedBox(width: filled, child: bar(ink)),
              if (filled > 0 && rest > 0) SizedBox(width: gap),
              if (rest > 0)
                SizedBox(width: rest, child: bar(ink.withValues(alpha: .12))),
            ],
          ),
        );
      },
    );
  }
}
