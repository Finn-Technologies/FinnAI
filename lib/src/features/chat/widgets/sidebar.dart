part of '../home_shell.dart';

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.onNewConversation,
    required this.onConversation,
    required this.conversations,
    required this.activeConversationId,
    required this.onCreations,
    required this.onYou,
    required this.onFlows,
    required this.onActions,
    required this.onSettings,
  });

  final VoidCallback onNewConversation;
  final ValueChanged<String> onConversation;
  final List<FinnConversation> conversations;
  final String? activeConversationId;
  final VoidCallback onCreations;
  final VoidCallback onYou;
  final VoidCallback onFlows;
  final VoidCallback onActions;
  final VoidCallback onSettings;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  late final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  /// How far the brand row's reveal has pushed the rest of the panel down. The
  /// reveal is part of the sidebar, not a layer over it, so everything below
  /// the wordmark moves with it. Shared with the switcher so the two resize on
  /// the same frame.
  final BrandExpansion _brand = BrandExpansion();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    PinnedChatsStore.instance
      ..addListener(_onPinsChanged)
      ..initialize();
  }

  void _onPinsChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _scrollOffset.value = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    PinnedChatsStore.instance.removeListener(_onPinsChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    _brand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double safeBottom = FluxBottomInset.bottomOf(context);
    final ordered = PinnedChatsStore.instance.sorted(
      widget.conversations,
      (chat) => chat.id,
    );

    return ColoredBox(
      color: FluxColors.controlOf(context),
      // Outside the LayoutBuilder, so a change to the brand reveal recomputes
      // every offset derived from it. The panel's geometry is sized off the
      // constraints, so it has to be rebuilt, not just the Stack.
      child: ListenableBuilder(
        listenable: _brand,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final double sy = FinnLayout.scaleY(
              constraints.maxHeight,
              MediaQuery.sizeOf(context).width,
              max: 1.3,
              wideCap: .85,
            );
            final double headerTop = 70 * sy;
            // Three 70px destinations with the design's 30px gutters.
            final double navSize = ((constraints.maxWidth - 50 - 60) / 3).clamp(
              56.0,
              80.0,
            );
            final double navHeight = navSize + 22;
            final double navTop = 139 * sy + _brand.height;
            final double titleTop = 262 * sy + _brand.height;
            const double headerHeight = FinnBrandSwitcher.rowHeight;
            const double titleHeight = 24;
            final double historyTopAtRest = 262 * sy + titleHeight + 8;
            final double pinnedTitleTop = headerTop + 14;
            final double titleTravelDistance = math.max(
              1.0,
              (262 * sy) - pinnedTitleTop,
            );
            final double bottomBarHeight = 50 + 20 + safeBottom;

            return Stack(
              children: [
                // 1. Chat history, scrolling beneath the pinned header.
                //
                // It slides down with the reveal rather than having its top
                // padding changed: padding is part of the scroll extent, so
                // growing it would shift the content under a finger that is
                // already scrolling.
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(0, _brand.height),
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const FluxBouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.only(
                            left: 25,
                            right: 25,
                            top: historyTopAtRest,
                            bottom: bottomBarHeight + 40,
                          ),
                          sliver: ordered.isEmpty
                              ? SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 40,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const FigmaSvg(
                                          asset: FigmaAssets.noHistory,
                                          width: 40,
                                          height: 40,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          L10n.of(context).chatNoHistory,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color:
                                                    FluxColors.mutedOf(context),
                                                fontSize: 10,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    mainAxisExtent: 100,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final conversation = ordered[index];
                                      final card = _SidebarConversationTile(
                                        key: ValueKey(conversation.id),
                                        conversation: conversation,
                                        selected: conversation.id ==
                                            widget.activeConversationId,
                                        onTap: () => widget
                                            .onConversation(conversation.id),
                                      );
                                      // The design's staggered grid: the right
                                      // column starts half a card lower than the
                                      // left one.
                                      return index.isOdd
                                          ? Transform.translate(
                                              offset: const Offset(0, 55),
                                              child: card,
                                            )
                                          : card;
                                    },
                                    childCount: ordered.length,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Lightweight pinned-header surface. A solid surface avoids
                // per-frame backdrop filtering while preserving legibility.
                ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, _) {
                    final double scrollUp = math.max(0.0, offset);
                    final double coverProgress = (scrollUp / 24.0).clamp(
                      0.0,
                      1.0,
                    );
                    // Grows to include the brand reveal, so the panel's own
                    // backing reaches under it. The reveal blurs what scrolls
                    // past; without this a light chat card sliding underneath
                    // would leave the option's text sitting on white with nothing
                    // to hold it.
                    final double coverHeight = coverProgress <= 0
                        ? 0.0
                        : (pinnedTitleTop +
                            titleHeight +
                            18 * sy +
                            _brand.height);

                    return Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: coverHeight,
                      child: IgnorePointer(
                        child: coverProgress <= 0
                            ? const SizedBox()
                            : ColoredBox(
                                color: FluxColors.controlOf(
                                  context,
                                ).withValues(alpha: .96),
                              ),
                      ),
                    );
                  },
                ),

                // 3. Brand row. The design has the wordmark alone: the single
                // menu/close control rides the home screen's travel and ends up
                // on the far side of the panel. Tapping the name reveals FinnAI
                // Code under it, and this reports how much room that took so the
                // destinations below can move down instead of being covered.
                Positioned(
                  left: 25,
                  right: 25,
                  top: headerTop,
                  // The row keeps its design height when closed and grows when the
                  // reveal opens. It cannot simply be unbounded: the history title
                  // rides up to `pinnedTitleTop` and takes the wordmark's place on
                  // screen, so the wordmark's text has to stay where it was — at
                  // the top of the row's own 50dp band — for that handover to land
                  // in the same place it always did.
                  height: headerHeight + _brand.height,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _scrollOffset,
                    builder: (context, offset, child) {
                      final double pullDown = offset < 0 ? -offset : 0.0;
                      final double shift = pullDown * 0.20;
                      final double scrollUp = math.max(0.0, offset);
                      // While the reveal is open the row stays put and opaque.
                      // Fading it out mid-scroll is what lets the history title
                      // ride up and take its place, and it would also take the
                      // reveal with it — half a control, over text the user is in
                      // the middle of reading.
                      final double opacity = _brand.height > 0
                          ? 1.0
                          : (1.0 - (scrollUp / (titleTravelDistance * 0.5)))
                              .clamp(0.0, 1.0);

                      return IgnorePointer(
                        ignoring: opacity < 0.5,
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(0, shift),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Align(
                      // Centred in its own 50dp band when closed, which is where
                      // the design puts the wordmark; top-aligned once the reveal
                      // opens, so the band grows downward instead of the wordmark
                      // drifting toward its middle.
                      alignment: _brand.height > 0
                          ? Alignment.topLeft
                          : Alignment.centerLeft,
                      child: FinnBrandSwitcher(
                        current: FinnAppMode.chat,
                        expansion: _brand,
                      ),
                    ),
                  ),
                ),

                // 4. Local feature destinations.
                Positioned(
                  left: 25,
                  right: 25,
                  top: navTop,
                  height: navHeight,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _scrollOffset,
                    builder: (context, offset, child) {
                      final double pullDown = offset < 0 ? -offset : 0.0;
                      final double shift = pullDown * 0.45;
                      final double scrollUp = math.max(0.0, offset);
                      final double opacity =
                          (1.0 - (scrollUp / (titleTravelDistance * 0.7)))
                              .clamp(
                        0.0,
                        1.0,
                      );

                      return IgnorePointer(
                        ignoring: opacity < 0.5,
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(0, shift),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FinnSidebarTile(
                          asset: FigmaAssets.tileCreations,
                          label: L10n.of(context).creationsTitle,
                          onTap: widget.onCreations,
                          size: navSize,
                        ),
                        FinnSidebarTile(
                          asset: FigmaAssets.tileFlows,
                          label: L10n.of(context).flowsTitle,
                          onTap: widget.onFlows,
                          size: navSize,
                        ),
                        FinnSidebarTile(
                          asset: FigmaAssets.tileYou,
                          label: L10n.of(context).youTitle,
                          onTap: widget.onYou,
                          size: navSize,
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Chat History Title - lifts up on scroll all the way to
                // headerTop replacing content beneath, spring overscroll on pull
                // down.
                Positioned(
                  left: 25,
                  right: 25,
                  top: titleTop,
                  height: titleHeight,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _scrollOffset,
                    builder: (context, offset, child) {
                      double shift;
                      if (offset < 0) {
                        final double pullDown = -offset;
                        shift = pullDown * 0.70;
                      } else {
                        shift = -math.min(titleTravelDistance, offset);
                      }
                      return Transform.translate(
                        offset: Offset(0, shift),
                        child: child,
                      );
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        L10n.of(context).chatHistory,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontSize: 18,
                                ),
                      ),
                    ),
                  ),
                ),

                // 6. The two shortcuts that used to sit in the header.
                // The design leaves 38px under these circles on its 912pt canvas.
                // That is a design-canvas gap, so it scales with everything else
                // here, and the system inset only raises it further when the
                // navigation bar is actually taller than the design assumed.
                Positioned(
                  left: 25,
                  bottom: math.max(safeBottom + 3, 38 * sy),
                  height: 50,
                  child: Row(
                    children: [
                      FinnSidebarCircleButton(
                        asset: FigmaAssets.appNewChat,
                        tooltip: L10n.of(context).chatNewChat,
                        background: FluxColors.tileOf(context),
                        onTap: widget.onNewConversation,
                      ),
                      const SizedBox(width: 11),
                      FinnSidebarCircleButton(
                        asset: FigmaAssets.appSettings,
                        tooltip: L10n.of(context).settingsTitle,
                        background: FluxColors.tileOf(context),
                        onTap: widget.onSettings,
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
