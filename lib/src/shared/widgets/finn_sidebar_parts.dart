import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

// The sidebar's brand row belongs with its other parts, so a screen that builds
// a sidebar imports one library.
export 'package:finn_ai/src/shared/config/app_mode.dart';
export 'package:finn_ai/src/shared/widgets/finn_brand_switcher.dart';

/// A circular shortcut in the sidebar: the destinations under the brand row.
///
/// Either an [asset] from the design file or a [icon] from [FluxIcons].
class FinnSidebarTile extends StatelessWidget {
  const FinnSidebarTile({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.asset,
    this.size = 70,
  }) : assert(icon != null || asset != null);

  final List<List<dynamic>>? icon;
  final String? asset;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: FluxPressScale(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(FluxRadius.sm),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(FluxRadius.sm),
              child: SizedBox(
                width: size,
                height: size + 22,
                child: Column(
                  children: [
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: FluxColors.tileOf(context),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: asset != null
                            ? FigmaSvg(
                                asset: asset!,
                                width: size * .57,
                                height: size * .57,
                              )
                            : FluxIcon(
                                icon: icon!,
                                size: size * 0.42,
                                color: FluxColors.inkOf(context),
                              ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 17,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'InstrumentSans',
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                            color: FluxColors.inkOf(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// One entry in the sidebar's history grid: a chat in FinnAI, a coding session
/// in FinnAI Code.
///
/// Both apps had their own copy of this card — same fill, same radius, same
/// press, same two-line title, same dimming rule on the corner badge — which is
/// how the two sidebars drifted apart. Only the [badge] differs: a timestamp in
/// FinnAI, a pin in FinnAI Code.
class FinnSidebarHistoryTile extends StatelessWidget {
  const FinnSidebarHistoryTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.badge,
    this.badgeKey,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// What sits in the top-right corner. Give it [badgeInk] as its colour so a
  /// badge on a selected tile dims with the rest of it.
  final Widget? badge;

  /// Anchors a context menu to this tile.
  final Key? badgeKey;

  /// The colour a [badge] should be painted in: the selected tile's ink at 70%,
  /// so the badge steps back behind the title, or the timestamp grey otherwise.
  static Color badgeInk(BuildContext context, bool selected) => selected
      ? FluxColors.actionInkOf(context).withValues(alpha: .7)
      : FluxColors.timestampOf(context);

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? FluxColors.actionInkOf(context) : FluxColors.inkOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      onTap: onTap,
      excludeSemantics: true,
      child: FluxPressScale(
        scale: .96,
        child: Material(
          color: selected
              ? FluxColors.actionOf(context)
              : FluxColors.tileOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.card),
          child: InkWell(
            key: badgeKey,
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(FluxRadius.card),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    // Reserves the row even with no badge, so the title keeps
                    // the same baseline whether or not a tile is pinned.
                    child: badge ?? const SizedBox(height: 16),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular icon-only control, e.g. close, new chat or settings.
class FinnSidebarCircleButton extends StatelessWidget {
  const FinnSidebarCircleButton({
    super.key,
    required this.tooltip,
    required this.background,
    required this.onTap,
    this.icon,
    this.asset,
  }) : assert(icon != null || asset != null);

  final List<List<dynamic>>? icon;
  final String? asset;
  final String tooltip;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          onTap: onTap,
          excludeSemantics: true,
          child: FluxPressScale(
            child: Material(
              color: background,
              shape: const CircleBorder(),
              child: SizedBox.square(
                dimension: 50,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: asset != null
                        ? FigmaSvg(asset: asset!, width: 25, height: 25)
                        : FluxIcon(
                            icon: icon!,
                            size: 22,
                            color: FluxColors.inkOf(context),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
