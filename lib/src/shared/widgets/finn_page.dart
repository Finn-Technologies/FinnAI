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

  @override
  State<FinnPage> createState() => _FinnPageState();
}

class _FinnPageState extends State<FinnPage> {
  final ScrollController _controller = ScrollController();
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
    _controller.dispose();
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
                            itemCount: widget.children.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: widget.spacing),
                            itemBuilder: (_, i) => widget.children[i],
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
