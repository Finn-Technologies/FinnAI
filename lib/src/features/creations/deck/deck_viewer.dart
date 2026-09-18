import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_palette.dart';
import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Browses a generated deck slide by slide.
///
/// The same [DeckSpec] drives both this viewer and the `.pptx` export, so what
/// the user reviews on device is what lands in the file.
class DeckViewer extends StatefulWidget {
  const DeckViewer({
    super.key,
    required this.title,
    required this.deck,
    required this.onBack,
    this.onExport,
  });

  final String title;
  final DeckSpec deck;
  final VoidCallback onBack;

  /// Triggered by the export action; hidden when null.
  final VoidCallback? onExport;

  @override
  State<DeckViewer> createState() => _DeckViewerState();
}

class _DeckViewerState extends State<DeckViewer> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.deck.slides.length - 1);
    if (next == _index) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.deck.slides;
    return Scaffold(
      floatingActionButton: widget.onExport == null
          ? null
          : FloatingActionButton.small(
              onPressed: widget.onExport,
              tooltip: L10n.of(context).creationsExportDeck,
              backgroundColor: FluxColors.surfaceOf(context),
              foregroundColor: FluxColors.inkOf(context),
              elevation: 0,
              child: const FluxIcon(icon: FluxIcons.download, size: 19),
            ),
      body: AmbientBackground(
        intensity: .6,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = FinnPageHeaderMetrics.forHeight(
              constraints.maxHeight,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      SizedBox(height: metrics.contentTop + 6),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: slides.length,
                          onPageChanged: (index) =>
                              setState(() => _index = index),
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: _SlideCard(
                                    slide: slides[index],
                                    accent: CreationPalette.tileFor(
                                      CreationKind.presentation,
                                    ),
                                    isTitleSlide: index == 0,
                                  ),
                                ),
                                if (slides[index].notes.trim().isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    slides[index].notes,
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: FluxColors.mutedOf(context),
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      _DeckFooter(
                        index: _index,
                        count: slides.length,
                        onPrevious: _index == 0 ? null : () => _go(-1),
                        onNext:
                            _index == slides.length - 1 ? null : () => _go(1),
                      ),
                      // The export FAB floats over the bottom-right corner, so
                      // the footer reserves its height when it is present.
                      SizedBox(
                        height: MediaQuery.paddingOf(context).bottom +
                            (widget.onExport == null ? 18 : 64),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: FinnPageHeader(
                    title: widget.title,
                    onBack: widget.onBack,
                    metrics: metrics,
                    scrollOffset: const RestingHeaderOffset(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({
    required this.slide,
    required this.accent,
    required this.isTitleSlide,
  });

  final DeckSlide slide;
  final Color accent;
  final bool isTitleSlide;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          padding: EdgeInsets.all(isTitleSlide ? 26 : 22),
          decoration: BoxDecoration(
            color: FluxColors.cardOf(context),
            borderRadius: BorderRadius.circular(FluxRadius.card),
            border: Border.all(
              color: FluxColors.lineOf(context).withValues(alpha: .8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(FluxRadius.pill),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                slide.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (isTitleSlide
                        ? Theme.of(context).textTheme.headlineLarge
                        : Theme.of(context).textTheme.titleLarge)
                    ?.copyWith(height: 1.2),
              ),
              if (slide.bullets.isNotEmpty) ...[
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final bullet in slide.bullets)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: FluxColors.mutedOf(context),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    bullet,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckFooter extends StatelessWidget {
  const _DeckFooter({
    required this.index,
    required this.count,
    required this.onPrevious,
    required this.onNext,
  });

  final int index;
  final int count;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // The only arrow glyph available points right, so the "previous"
          // control mirrors it: a right-pointing arrow for stepping back read
          // as "next".
          Transform.rotate(
            angle: math.pi,
            child: FluxIconButton(
              icon: FluxIcons.arrowRight01,
              tooltip: L10n.of(context).creationsPreviousSlide,
              onTap: onPrevious,
              dark: true,
            ),
          ),
          Expanded(
            child: Semantics(
              label: L10n.of(context).creationsSlideOf(index + 1, count),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var dot = 0; dot < count; dot++)
                    Container(
                      width: dot == index ? 7 : 5,
                      height: dot == index ? 7 : 5,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: dot == index
                            ? FluxColors.inkOf(context)
                            : FluxColors.lineOf(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          FluxIconButton(
            icon: FluxIcons.arrowRight01,
            tooltip: L10n.of(context).creationsNextSlide,
            onTap: onNext,
            dark: true,
          ),
        ],
      ),
    );
  }
}
