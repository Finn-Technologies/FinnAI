import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// Placeholder rows shaped like the list that is loading, with a soft light
/// sweeping across them: the page reads as "almost here" rather than as an
/// empty screen with a spinner. One controller for the whole group, and a
/// still frame when the system asks for reduced motion.
class FinnSkeletonList extends StatefulWidget {
  const FinnSkeletonList({
    super.key,
    this.rows = 4,
    this.rowHeight = 76,
    this.spacing = 10,
  });

  final int rows;
  final double rowHeight;
  final double spacing;

  @override
  State<FinnSkeletonList> createState() => _FinnSkeletonListState();
}

class _FinnSkeletonListState extends State<FinnSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      // Rewind as well as stop: stopping alone froze the band wherever the
      // sweep happened to be, which reads as a broken placeholder rather than
      // as the still frame it is meant to be.
      _sweep
        ..stop()
        ..value = _sweep.lowerBound;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = FluxColors.controlOf(context);
    final shine = Color.lerp(base, FluxColors.inkOf(context), .06)!;
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final x = -1.5 + 3 * _sweep.value;
            return LinearGradient(
              begin: Alignment(x - .6, -.2),
              end: Alignment(x + .6, .2),
              colors: [base, shine, base],
            ).createShader(bounds);
          },
          child: child,
        ),
        child: Column(
          key: const ValueKey('finn-skeleton'),
          children: [
            for (var i = 0; i < widget.rows; i++) ...[
              if (i > 0) SizedBox(height: widget.spacing),
              Container(
                height: widget.rowHeight,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(FluxRadius.card),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: FluxColors.tileOf(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bar(context, widthFactor: .55),
                          const SizedBox(height: 8),
                          _bar(context, widthFactor: .35),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, {required double widthFactor}) =>
      FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 10,
          decoration: BoxDecoration(
            color: FluxColors.tileOf(context),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      );
}
