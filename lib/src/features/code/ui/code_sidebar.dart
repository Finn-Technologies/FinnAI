import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_sidebar_parts.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The panel behind FinnAI Code: the same layout as FinnAI's — brand row, three
/// destinations, a staggered history — with sessions in place of chats and
/// Files, Terminal and Models in place of Creations, Flows and You.
class CodeSidebar extends StatefulWidget {
  const CodeSidebar({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.onSession,
    required this.onSessionOptions,
    required this.onNewSession,
    required this.onFiles,
    required this.onTerminal,
    required this.onModels,
    required this.onSettings,
  });

  final List<CodeSession> sessions;
  final String? activeSessionId;
  final ValueChanged<String> onSession;
  final ValueChanged<CodeSession> onSessionOptions;
  final VoidCallback onNewSession;
  final VoidCallback onFiles;
  final VoidCallback onTerminal;
  final VoidCallback onModels;
  final VoidCallback onSettings;

  @override
  State<CodeSidebar> createState() => _CodeSidebarState();
}

class _CodeSidebarState extends State<CodeSidebar> {
  late final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  /// How far the brand row's reveal has pushed the rest of the panel down.
  /// Shared with the switcher so the two resize on the same frame.
  final BrandExpansion _brand = BrandExpansion();

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
    _brand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final safeBottom = FluxBottomInset.bottomOf(context);
    final sessions = widget.sessions;

    return ColoredBox(
      color: FluxColors.controlOf(context),
      // Outside the LayoutBuilder, so a change to the brand reveal recomputes
      // every offset derived from it. The panel's geometry is all sized off the
      // constraints, so it has to be rebuilt, not just the Stack.
      child: ListenableBuilder(
        listenable: _brand,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final sy = (constraints.maxHeight / 912).clamp(0.72, 1.3);
            final headerTop = 70 * sy;
            const headerHeight = FinnBrandSwitcher.rowHeight;
            final navSize =
                ((constraints.maxWidth - 50 - 60) / 3).clamp(56.0, 80.0);
            final navHeight = navSize + 22;
            final navTop = 139 * sy + _brand.height;
            final titleTop = 262 * sy + _brand.height;
            const titleHeight = 24.0;
            final historyTopAtRest = 262 * sy + titleHeight + 8;
            final pinnedTitleTop = headerTop + 14;
            final titleTravel = math.max(1.0, (262 * sy) - pinnedTitleTop);
            final bottomBarHeight = 50 + 20 + safeBottom;

            // The brand row and the destinations fade as the history scrolls up
            // under them; the title rides up to take their place.
            //
            // The brand row is exempt while its reveal is open: fading it would
            // fade the reveal too, leaving half a control over text the user is
            // still reading.
            Widget fading(
              double opacityOver,
              double pullFactor,
              Widget child, {
              bool exempt = false,
            }) =>
                ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, child) {
                    final pullDown = offset < 0 ? -offset : 0.0;
                    final scrollUp = math.max(0.0, offset);
                    final opacity = exempt && _brand.height > 0
                        ? 1.0
                        : (1.0 - scrollUp / (titleTravel * opacityOver))
                            .clamp(0.0, 1.0);
                    return IgnorePointer(
                      ignoring: opacity < 0.5,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, pullDown * pullFactor),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: child,
                );

            return Stack(
              children: [
                // The history slides down with the brand reveal rather than
                // having its top padding changed: padding is part of the scroll
                // extent, so growing it would shift content under a finger that
                // is already scrolling.
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
                          sliver: sessions.isEmpty
                              ? SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 40),
                                    child: Column(
                                      children: [
                                        const FigmaSvg(
                                          asset: FigmaAssets.noHistory,
                                          width: 40,
                                          height: 40,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          l10n.codeNoSessions,
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
                                      final session = sessions[index];
                                      final selected =
                                          session.id == widget.activeSessionId;
                                      final tile = FinnSidebarHistoryTile(
                                        key: ValueKey(
                                            'code-session-${session.id}'),
                                        title: session.title.isEmpty
                                            ? '…'
                                            : session.title,
                                        selected: selected,
                                        onTap: () =>
                                            widget.onSession(session.id),
                                        onLongPress: () =>
                                            widget.onSessionOptions(session),
                                        badge: session.pinned
                                            ? FluxIcon(
                                                icon: CodeIcons.pin,
                                                size: 16,
                                                strokeWidth: 1.5,
                                                color: FinnSidebarHistoryTile
                                                    .badgeInk(
                                                  context,
                                                  selected,
                                                ),
                                              )
                                            : null,
                                      );
                                      // The design's staggered grid: the right
                                      // column starts half a card lower.
                                      return index.isOdd
                                          ? Transform.translate(
                                              offset: const Offset(0, 55),
                                              child: tile,
                                            )
                                          : tile;
                                    },
                                    childCount: sessions.length,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, _) {
                    final coverProgress =
                        (math.max(0.0, offset) / 24.0).clamp(0.0, 1.0);
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: coverProgress <= 0
                          ? 0
                          : pinnedTitleTop +
                              titleHeight +
                              18 * sy +
                              _brand.height,
                      child: IgnorePointer(
                        child: coverProgress <= 0
                            ? const SizedBox()
                            : ColoredBox(
                                color: FluxColors.controlOf(context)
                                    .withValues(alpha: .96),
                              ),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 25,
                  right: 25,
                  top: headerTop,
                  // Kept at the design height when closed and grown when the reveal
                  // opens, so the wordmark's text stays at the top of its own band:
                  // the history title rides up to `pinnedTitleTop` to replace it,
                  // and that handover has to land in the same place every time.
                  height: headerHeight + _brand.height,
                  child: fading(
                    .5,
                    .20,
                    Align(
                      // Centred in its own 50dp band when closed, as the design
                      // has it; top-aligned once the reveal opens so the band
                      // grows downward rather than moving the wordmark.
                      alignment: _brand.height > 0
                          ? Alignment.topLeft
                          : Alignment.centerLeft,
                      child: FinnBrandSwitcher(
                        current: FinnAppMode.code,
                        expansion: _brand,
                      ),
                    ),
                    exempt: true,
                  ),
                ),
                Positioned(
                  left: 25,
                  right: 25,
                  top: navTop,
                  height: navHeight,
                  child: fading(
                    .7,
                    .45,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FinnSidebarTile(
                          icon: CodeIcons.folder,
                          label: l10n.codeFilesTitle,
                          onTap: widget.onFiles,
                          size: navSize,
                        ),
                        FinnSidebarTile(
                          icon: CodeIcons.terminal,
                          label: l10n.codeTerminalTitle,
                          onTap: widget.onTerminal,
                          size: navSize,
                        ),
                        FinnSidebarTile(
                          icon: FluxIcons.chip,
                          label: l10n.codeModelsTitle,
                          onTap: widget.onModels,
                          size: navSize,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 25,
                  right: 25,
                  top: titleTop,
                  height: titleHeight,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _scrollOffset,
                    builder: (context, offset, child) {
                      final shift = offset < 0
                          ? -offset * 0.70
                          : -math.min(titleTravel, offset);
                      return Transform.translate(
                        offset: Offset(0, shift),
                        child: child,
                      );
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.codeSessionsTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 18),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 25,
                  bottom: math.max(safeBottom + 3, 38 * sy),
                  height: 50,
                  child: Row(
                    children: [
                      FinnSidebarCircleButton(
                        asset: FigmaAssets.appNewChat,
                        tooltip: l10n.codeNewSession,
                        background: FluxColors.tileOf(context),
                        onTap: widget.onNewSession,
                      ),
                      const SizedBox(width: 11),
                      FinnSidebarCircleButton(
                        asset: FigmaAssets.appSettings,
                        tooltip: l10n.codeSettingsTitle,
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
