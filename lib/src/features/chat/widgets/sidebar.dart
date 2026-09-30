part of '../home_shell.dart';

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.onClose,
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

  final VoidCallback onClose;
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _scrollOffset.value = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: FluxColors.controlOf(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double sy = (constraints.maxHeight / 912).clamp(0.72, 1.3);
          const double headerHeight = 50;
          final double headerTop = 70 * sy;
          // Three 70px destinations with the design's 30px gutters.
          final double navSize = ((constraints.maxWidth - 50 - 60) / 3).clamp(
            56.0,
            80.0,
          );
          final double navHeight = navSize + 22;
          final double navTop = 139 * sy;
          final double titleTop = 262 * sy;
          const double titleHeight = 24;
          final double historyTopAtRest = titleTop + titleHeight + 8;
          final double pinnedTitleTop = headerTop + 14;
          final double titleTravelDistance = math.max(
            1.0,
            titleTop - pinnedTitleTop,
          );
          final double bottomBarHeight = 50 + 20 + safeBottom;

          return Stack(
            children: [
              // 1. Chat history, scrolling beneath the pinned header.
              Positioned.fill(
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
                      sliver: widget.conversations.isEmpty
                          ? SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                            color: FluxColors.mutedOf(context),
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
                                  final conversation =
                                      widget.conversations[index];
                                  final card = _SidebarConversationTile(
                                    key: ValueKey(conversation.id),
                                    conversation: conversation,
                                    selected: conversation.id ==
                                        widget.activeConversationId,
                                    onTap: () =>
                                        widget.onConversation(conversation.id),
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
                                childCount: widget.conversations.length,
                              ),
                            ),
                    ),
                  ],
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
                  final double coverHeight = coverProgress <= 0
                      ? 0.0
                      : (pinnedTitleTop + titleHeight + 18 * sy);

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

              // 3. Brand row with the close control.
              Positioned(
                left: 25,
                right: 25,
                top: headerTop,
                height: headerHeight,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, child) {
                    final double pullDown = offset < 0 ? -offset : 0.0;
                    final double shift = pullDown * 0.20;
                    final double scrollUp = math.max(0.0, offset);
                    final double opacity =
                        (1.0 - (scrollUp / (titleTravelDistance * 0.5))).clamp(
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
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            L10n.of(context).appBrandFinnAI,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ),
                      ),
                      _SidebarCircleButton(
                        asset: FigmaAssets.appClose,
                        tooltip: L10n.of(context).commonClose,
                        background: FluxColors.controlOf(context),
                        onTap: widget.onClose,
                      ),
                    ],
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
                        (1.0 - (scrollUp / (titleTravelDistance * 0.7))).clamp(
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
                      _SidebarCircleTile(
                        asset: FigmaAssets.tileCreations,
                        label: L10n.of(context).creationsTitle,
                        onTap: widget.onCreations,
                        size: navSize,
                      ),
                      _SidebarCircleTile(
                        asset: FigmaAssets.tileFlows,
                        label: L10n.of(context).flowsTitle,
                        onTap: widget.onFlows,
                        size: navSize,
                      ),
                      _SidebarCircleTile(
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                          ),
                    ),
                  ),
                ),
              ),

              // 6. The two shortcuts that used to sit in the header.
              Positioned(
                left: 25,
                bottom: safeBottom + 3,
                height: 50,
                child: Row(
                  children: [
                    _SidebarCircleButton(
                      asset: FigmaAssets.appNewChat,
                      tooltip: L10n.of(context).chatNewChat,
                      background: FluxColors.tileOf(context),
                      onTap: widget.onNewConversation,
                    ),
                    const SizedBox(width: 11),
                    _SidebarCircleButton(
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
    );
  }
}
