import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// A secondary page in the design's layout: circular back button and title on
/// one row, then a scrolling column of [children] on 25dp gutters.
///
/// Most destinations are exactly this, so they build on it instead of each
/// carrying their own scaffold, scroll listener and header wiring.
class FinnPage extends StatefulWidget {
  const FinnPage({
    super.key,
    required this.title,
    required this.children,
    this.onBack,
    this.actions = const [],
    this.footer,
    this.spacing = 10,
    this.resizeForKeyboard = true,
    this.controller,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// Pinned below the scrolling content (a primary button, a composer).
  final Widget? footer;

  /// Vertical gap between [children].
  final double spacing;
  final bool resizeForKeyboard;

  /// Scrolls the content; for a page that follows what it appends (a
  /// terminal). The page makes its own when none is given.
  final ScrollController? controller;

  @override
  State<FinnPage> createState() => _FinnPageState();
}

class _FinnPageState extends State<FinnPage> {
  late final ScrollController _controller =
      widget.controller ?? ScrollController();
  final ValueNotifier<double> _offset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.hasClients) _offset.value = _controller.offset;
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: widget.resizeForKeyboard,
        body: AmbientBackground(
          intensity: 1,
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
                        Expanded(
                          child: ListView.separated(
                            controller: _controller,
                            physics: const FluxBouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              25,
                              metrics.contentTop,
                              25,
                              widget.footer == null ? 30 + bottom : 20,
                            ),
                            itemCount: widget.children.length + 1,
                            separatorBuilder: (_, i) => SizedBox(
                              height: i == 0 ? 0 : widget.spacing,
                            ),
                            itemBuilder: (_, i) => i == 0
                                ? FinnLargeTitle(
                                    title: widget.title,
                                    scrollOffset: _offset,
                                  )
                                : widget.children[i - 1],
                          ),
                        ),
                        if (widget.footer != null)
                          Padding(
                            padding:
                                EdgeInsets.fromLTRB(25, 0, 25, 25 + bottom),
                            child: widget.footer,
                          ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: FinnPageHeader(
                      title: widget.title,
                      onBack: widget.onBack ??
                          () => Navigator.of(context).maybePop(),
                      metrics: metrics,
                      scrollOffset: _offset,
                      actions: widget.actions,
                      largeTitle: true,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
}

/// A short sentence under a page title or between groups: 14dp, secondary ink.
class FinnCaption extends StatelessWidget {
  const FinnCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                // Secondary ink, as documented. This read through actionOf,
                // which is the *fill* token: in dark that is near-white
                // (#F5F5F7), so a caption came out brighter than the title above
                // it, and in light it was #414141 rather than #121212.
                color: FluxColors.secondaryInkOf(context),
              ),
        ),
      );
}

/// The page's name, large, at the top of its content. Pages that build their
/// own scaffold around [FinnPageHeader] put it first in their scroll view and
/// pass `largeTitle: true` to the header, so every page reads the same.
///
/// It drifts up a little slower than the content and fades as it goes under
/// the bar, where the compact title takes over.
class FinnLargeTitle extends StatelessWidget {
  const FinnLargeTitle({
    super.key,
    required this.title,
    required this.scrollOffset,
  });

  final String title;
  final ValueListenable<double> scrollOffset;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: FinnPageHeader.largeTitleExtent,
        child: ValueListenableBuilder<double>(
          valueListenable: scrollOffset,
          builder: (context, offset, child) {
            final progress =
                (offset / FinnPageHeader.largeTitleExtent).clamp(0.0, 1.0);
            // Pulled down past the top it grows a touch, like a sheet.
            final stretch =
                offset < 0 ? (1 + (-offset / 900)).clamp(1.0, 1.08) : 1.0;
            return Opacity(
              opacity: 1 - Curves.easeIn.transform(progress),
              child: Transform.translate(
                offset: Offset(0, offset > 0 ? offset * .25 : 0),
                child: Transform.scale(
                  scale: stretch,
                  alignment: Alignment.centerLeft,
                  child: child,
                ),
              ),
            );
          },
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.8,
                  ).copyWith(color: FluxColors.inkOf(context)),
                ),
              ),
            ),
          ),
        ),
      );
}
