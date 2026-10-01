import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';

/// Geometry shared by Finn's secondary pages.
///
/// The design puts a 50dp circular back button and an 18dp title beside it on one
/// row at y=71, with content starting 20dp below it. Every destination uses
/// these anchors so the header never jumps between pages.
@immutable
class FinnPageHeaderMetrics {
  const FinnPageHeaderMetrics._({
    required this.scaleY,
    required this.headerTop,
    required this.initialTitleTop,
    required this.pinnedTitleTop,
    required this.titleTravelDistance,
    required this.contentTop,
  });

  factory FinnPageHeaderMetrics.forHeight(double height) {
    final scaleY = (height / 844).clamp(.7, 1.3);
    final headerTop = 71 * scaleY;
    return FinnPageHeaderMetrics._(
      scaleY: scaleY,
      headerTop: headerTop,
      initialTitleTop: headerTop,
      pinnedTitleTop: headerTop,
      titleTravelDistance: 0,
      contentTop: headerTop + FinnPageHeader.barHeight + 20,
    );
  }

  final double scaleY;
  final double headerTop;
  final double initialTitleTop;
  final double pinnedTitleTop;
  final double titleTravelDistance;
  final double contentTop;
}

/// A [ValueListenable] that always reports zero.
///
/// For headers over content that has no vertical scroll of its own — a paged
/// deck, for example. Using this instead of a per-page notifier keeps the
/// header honest: there is nothing to listen to, so nothing claims to be.
class RestingHeaderOffset implements ValueListenable<double> {
  const RestingHeaderOffset();

  @override
  double get value => 0;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Circular back control with the page title beside it and optional actions.
///
/// Place this in a full-size [Stack]. Native views and scrolling content stay
/// outside this layer; once content scrolls under the bar a soft cover keeps
/// the title legible.
class FinnPageHeader extends StatelessWidget {
  const FinnPageHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.metrics,
    required this.scrollOffset,
    this.actions = const [],
  });

  static const double barHeight = 50;

  final String title;
  final VoidCallback onBack;
  final FinnPageHeaderMetrics metrics;
  final ValueListenable<double> scrollOffset;

  /// Up to two trailing circle controls (see [FinnCircleButton]).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final coverHeight = metrics.headerTop + barHeight + 10;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: coverHeight,
          child: IgnorePointer(
            child: ValueListenableBuilder<double>(
              valueListenable: scrollOffset,
              builder: (context, offset, _) {
                final progress = (offset / 24).clamp(0.0, 1.0);
                return progress == 0
                    ? const SizedBox.shrink()
                    : ColoredBox(
                        color: FluxColors.canvasOf(context)
                            .withValues(alpha: .94 * progress),
                      );
              },
            ),
          ),
        ),
        Positioned(
          left: 25,
          right: 25,
          top: metrics.headerTop,
          height: barHeight,
          child: Row(
            children: [
              FinnCircleButton(
                key: const ValueKey('page-back-button'),
                glyph: const FigmaSvg(
                  asset: FigmaAssets.back,
                  width: 25,
                  height: 25,
                ),
                label: L10n.of(context).commonBack,
                onTap: onBack,
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                actions[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
