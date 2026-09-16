import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Geometry shared by Finn's secondary pages.
///
/// These values intentionally mirror the established Settings page so every
/// destination opens with the back control, title, and first content block on
/// the same visual anchors.
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
    const headerHeight = 34.0;
    final headerTop = 71 * scaleY;
    final initialTitleTop = headerTop + headerHeight + 10 * scaleY;
    const pinnedTitleTopOffset = 0.0;
    const titleHeight = 30.0;
    return FinnPageHeaderMetrics._(
      scaleY: scaleY,
      headerTop: headerTop,
      initialTitleTop: initialTitleTop,
      pinnedTitleTop: headerTop + pinnedTitleTopOffset,
      titleTravelDistance: initialTitleTop - headerTop,
      contentTop: initialTitleTop + titleHeight + 10,
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

/// Settings-aligned back control and collapsing page title.
///
/// Place this in a full-size [Stack]. Native views and scrolling content stay
/// outside this layer, so the animation remains inexpensive.
class FinnPageHeader extends StatelessWidget {
  const FinnPageHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.metrics,
    required this.scrollOffset,
  });

  final String title;
  final VoidCallback onBack;
  final FinnPageHeaderMetrics metrics;
  final ValueListenable<double> scrollOffset;

  @override
  Widget build(BuildContext context) {
    const titleHeight = 30.0;
    return Stack(
      children: [
        ValueListenableBuilder<double>(
          valueListenable: scrollOffset,
          builder: (context, offset, _) {
            final scrollUp = math.max(0.0, offset);
            final coverProgress = (scrollUp / 24).clamp(0.0, 1.0);
            final coverHeight = coverProgress == 0
                ? 0.0
                : metrics.pinnedTitleTop + titleHeight + 14 * metrics.scaleY;
            return Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: coverHeight,
              child: IgnorePointer(
                child: coverProgress == 0
                    ? const SizedBox.shrink()
                    : ColoredBox(
                        color: FluxColors.canvasOf(
                          context,
                        ).withValues(alpha: .96),
                      ),
              ),
            );
          },
        ),
        Positioned(
          left: 20,
          right: 20,
          top: metrics.headerTop,
          height: 34,
          child: ValueListenableBuilder<double>(
            valueListenable: scrollOffset,
            builder: (context, offset, child) {
              final pullDown = offset < 0 ? -offset : 0.0;
              final scrollUp = math.max(0.0, offset);
              final opacity =
                  (1 - scrollUp / math.max(1, metrics.titleTravelDistance * .5))
                      .clamp(0.0, 1.0);
              return IgnorePointer(
                ignoring: opacity < .5,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, pullDown * .2),
                    child: child,
                  ),
                ),
              );
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: BackControl(onTap: onBack),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: metrics.initialTitleTop,
          height: titleHeight,
          child: ValueListenableBuilder<double>(
            valueListenable: scrollOffset,
            builder: (context, offset, child) {
              final shift = offset < 0
                  ? -offset * .7
                  : -math.min(metrics.titleTravelDistance, offset);
              return Transform.translate(
                offset: Offset(0, shift),
                child: child,
              );
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
