import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/creations/deck/slide_card.dart';
import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
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

  Future<void> _present() => Navigator.of(context).push(
        FinnPageRoute<void>(
          child: _PresentPage(deck: widget.deck, startAt: _index),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final slides = widget.deck.slides;
    return Scaffold(
      body: AmbientBackground(
        intensity: .6,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = FinnPageHeaderMetrics.forHeight(
              constraints.maxHeight,
              constraints.maxWidth,
            );
            final bottom = FluxBottomInset.bottomOf(context);
            return Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      SizedBox(height: metrics.contentTop),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          physics: const FluxBouncingScrollPhysics(),
                          children: [
                            SizedBox(
                              height: 230,
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: slides.length,
                                onPageChanged: (index) =>
                                    setState(() => _index = index),
                                itemBuilder: (context, index) => DeckSlideCard(
                                  slide: slides[index],
                                  theme: widget.deck.theme,
                                  index: index,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FinnCaption(
                              l10n.creationsSlideOf(_index + 1, slides.length),
                            ),
                            if (slides.isNotEmpty &&
                                slides[_index].notes.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: FluxColors.controlOf(context),
                                  borderRadius:
                                      BorderRadius.circular(FluxRadius.card),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.creationsSpeakerNotes,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: FluxColors.actionOf(context),
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      slides[_index].notes,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(25, 10, 25, 20 + bottom),
                        child: Row(
                          children: [
                            Transform.rotate(
                              angle: math.pi,
                              child: FinnCircleButton.icon(
                                icon: FluxIcons.arrowRight01,
                                label: l10n.creationsPreviousSlide,
                                onTap: _index == 0 ? null : () => _go(-1),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FinnButton(
                                label: l10n.creationsPresent,
                                icon: FluxIcons.arrowRight02,
                                onTap: slides.isEmpty ? null : _present,
                              ),
                            ),
                            const SizedBox(width: 10),
                            FinnCircleButton.icon(
                              icon: FluxIcons.arrowRight01,
                              label: l10n.creationsNextSlide,
                              onTap: _index >= slides.length - 1
                                  ? null
                                  : () => _go(1),
                            ),
                          ],
                        ),
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
                    actions: [
                      if (widget.onExport != null)
                        FinnCircleButton.icon(
                          icon: FluxIcons.arrowUp01,
                          label: l10n.creationsExportDeck,
                          onTap: widget.onExport,
                        ),
                    ],
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

/// Full-screen slideshow: tap or swipe to move on, back to leave.
class _PresentPage extends StatefulWidget {
  const _PresentPage({required this.deck, required this.startAt});

  final DeckSpec deck;
  final int startAt;

  @override
  State<_PresentPage> createState() => _PresentPageState();
}

class _PresentPageState extends State<_PresentPage> {
  late final PageController _controller =
      PageController(initialPage: widget.startAt);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _controller.nextPage(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                ),
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.deck.slides.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: DeckSlideCard(
                        slide: widget.deck.slides[index],
                        theme: widget.deck.theme,
                        index: index,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  tooltip: L10n.of(context).commonClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
}
