import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/figma_assets.dart';
import 'package:finn_ai/src/shared/widgets/flux_icons.dart';
import 'package:finn_ai/src/shared/widgets/flux_motion.dart';

export 'package:finn_ai/src/shared/widgets/figma_assets.dart';
export 'package:finn_ai/src/shared/widgets/flux_icons.dart';
export 'package:finn_ai/src/shared/widgets/flux_motion.dart'
    show FluxPressScale;
export 'package:finn_ai/src/shared/widgets/flux_scroll.dart';

class FigmaSvg extends StatelessWidget {
  const FigmaSvg({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    this.color,
    this.colorBlendMode = BlendMode.srcIn,
    this.isNavTile = false,
    this.invertForDark = false,
    this.preserveColors = false,
    this.fit = BoxFit.contain,
  });

  final String asset;
  final double width;
  final double height;

  /// How the artwork fills its box. Cards use [BoxFit.cover] so the design's
  /// photographic artwork keeps filling them on shorter screens.
  final BoxFit fit;
  final Color? color;
  final BlendMode colorBlendMode;
  final bool isNavTile;
  final bool invertForDark;

  /// Render the SVG's own colors even in dark mode, for icons designed to sit
  /// on light surfaces (like the white composer pill).
  final bool preserveColors;

  static const List<double> _darkNavTileMatrix = <double>[
    -1.082,
    0,
    0,
    0,
    310,
    0,
    -1.082,
    0,
    0,
    310,
    0,
    0,
    -1.082,
    0,
    310,
    0,
    0,
    0,
    1,
    0,
  ];
  static const List<double> _invertMatrix = <double>[
    -1,
    0,
    0,
    0,
    255,
    0,
    -1,
    0,
    0,
    255,
    0,
    0,
    -1,
    0,
    255,
    0,
    0,
    0,
    1,
    0,
  ];

  @override
  Widget build(BuildContext context) {
    final icon = FluxIcons.forDesignAsset[asset];
    if (icon != null) {
      final side = width < height ? width : height;
      return SizedBox(
        width: width,
        height: height,
        child: Center(
          child: FluxIcon(
            icon: icon,
            size: side,
            color: color ?? FluxColors.actionOf(context),
          ),
        ),
      );
    }
    final isDark = FluxColors.isDark(context);

    ColorFilter? filter;
    if (color != null) {
      filter = ColorFilter.mode(color!, colorBlendMode);
    } else if (isDark && !preserveColors) {
      if (invertForDark) {
        filter = const ColorFilter.matrix(_invertMatrix);
      } else if (isNavTile) {
        filter = const ColorFilter.matrix(_darkNavTileMatrix);
      } else {
        filter = ColorFilter.mode(FluxColors.inkOf(context), BlendMode.srcIn);
      }
    }

    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      colorFilter: filter,
    );
  }
}

/// A selectable filter pill: "All", "Apps", "Widgets", "Presentations".
///

class FluxIconButton extends StatelessWidget {
  const FluxIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 34,
    this.dark = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool dark;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bgColor = dark ? FluxColors.inkOf(context) : Colors.transparent;
    final fgColor =
        dark ? FluxColors.canvasOf(context) : FluxColors.inkOf(context);

    // The painted disc stays at [size]; the hit box is always at least
    // [FluxMotion.minTapTarget] so a 34dp icon is still a comfortable thumb
    // target on a phone.
    final hit = math.max(FluxMotion.minTapTarget, size);
    final button = SizedBox.square(
      dimension: hit,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(hit / 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(hit / 2),
          child: Center(
            child: Material(
              color: bgColor,
              borderRadius: BorderRadius.circular(size / 2),
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: FluxIcon(icon: icon, size: size * .56, color: fgColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final tooltipMessage = tooltip;
    final labelled = tooltipMessage == null
        ? button
        : Tooltip(
            message: tooltipMessage,
            excludeFromSemantics: true,
            child: button,
          );
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltipMessage,
      onTap: onTap,
      excludeSemantics: true,
      child: enabled ? labelled : Opacity(opacity: .4, child: labelled),
    );
  }
}

class FluxPillButton extends StatelessWidget {
  const FluxPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.compact = false,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool compact;

  /// The quiet choice beside a primary one (Cancel, Reject): the control
  /// fill with ink, so the two are told apart by more than their words.
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    // Disabled must be quieter than enabled: ink at 25% was near-white on black.
    final bgColor = onTap == null
        ? FluxColors.mutedOf(context).withValues(alpha: .32)
        : secondary
            ? FluxColors.controlOf(context)
            : FluxColors.actionOf(context);
    final fgColor =
        secondary ? FluxColors.inkOf(context) : FluxColors.actionInkOf(context);

    final painted = Material(
      color: bgColor,
      shape: StadiumBorder(
        side: secondary
            ? BorderSide(color: FluxColors.lineOf(context))
            : BorderSide.none,
      ),
      child: SizedBox(
        height: compact ? 36 : 44,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: fgColor),
              ),
              if (icon != null) ...[
                const SizedBox(width: 7),
                FluxIcon(icon: icon!, size: 14, color: fgColor),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: FluxMotion.minTapTarget,
          minHeight: FluxMotion.minTapTarget,
        ),
        child: FluxPressScale(
          scale: .95,
          enabled: onTap != null,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(FluxRadius.pill),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(FluxRadius.pill),
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                alignment: Alignment.center,
                child: painted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BackControl extends StatelessWidget {
  const BackControl({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: L10n.of(context).commonBack,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FluxRadius.card),
        child: SizedBox(
          width: 82,
          height: 48,
          child: Row(
            children: [
              Transform.rotate(
                angle: 0,
                child: const FigmaSvg(
                  asset: FigmaAssets.back,
                  width: 24,
                  height: 24,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 36,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    L10n.of(context).commonBack,
                    // 50%-alpha ink measured 3.47:1 on the canvas — below AA for
                    // body-size text. [FluxColors.mutedOf] is a solid token at
                    // 5.20:1 light / 7.33:1 dark and still reads as de-emphasised
                    // next to full-strength ink.
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: FluxColors.mutedOf(context),
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact pill that reveals supporting detail beneath it.
///
/// Chat replies use it for cited pages and browser steps, so both read as one
/// disclosure affordance instead of two lookalikes. The body is always laid out
/// — clipped to an animated height factor — so its height can be measured the
/// first time it opens.
class FluxDisclosure extends StatefulWidget {
  const FluxDisclosure({
    super.key,
    required this.leading,
    required this.label,
    required this.child,
    this.trailing,
    this.onHeightDelta,
    this.expandLabel,
    this.collapseLabel,
  });

  /// Glyph before [label]: a status spinner or the thing's own mark.
  final Widget leading;

  /// Primary text on the pill.
  final String label;

  /// Optional de-emphasised text after [label], e.g. `+2` or `3 steps`.
  final String? trailing;

  /// Revealed under the pill.
  final Widget child;

  /// Per-frame growth (or shrink) of the revealed area in pixels, so callers
  /// can keep surrounding content anchored while it animates.
  final ValueChanged<double>? onHeightDelta;

  /// Accessibility labels for the two states.
  final String? expandLabel;
  final String? collapseLabel;

  @override
  State<FluxDisclosure> createState() => _FluxDisclosureState();
}

class _FluxDisclosureState extends State<FluxDisclosure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FluxMotion.modalDuration,
    reverseDuration: FluxMotion.modalDuration,
  )..addListener(_onFrame);

  late final CurvedAnimation _factor = CurvedAnimation(
    parent: _controller,
    curve: FluxMotion.modalCurve,
  );

  final GlobalKey _contentKey = GlobalKey();
  double? _fullHeight;
  double _lastHeight = 0;

  bool get _expanded => _controller.value > 0;

  void _onFrame() {
    final full = _fullHeight;
    if (full == null) return;
    final current = full * _factor.value;
    final delta = current - _lastHeight;
    if (delta == 0) return;
    _lastHeight = current;
    widget.onHeightDelta?.call(delta);
    setState(() {});
  }

  void _toggle() {
    final size = _contentKey.currentContext?.size;
    if (size == null) return;
    _fullHeight = size.height;
    _lastHeight = size.height * _controller.value;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _controller.value = _expanded ? 0 : 1);
    } else if (_controller.isAnimating) {
      _controller.reverse();
    } else if (_controller.isDismissed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _factor.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = FluxColors.mutedOf(context);
    final trailing = widget.trailing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: _expanded
              ? widget.collapseLabel ?? widget.label
              : widget.expandLabel ?? widget.label,
          onTap: _toggle,
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: FluxMotion.minTapTarget,
              minHeight: FluxMotion.minTapTarget,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(FluxRadius.pill),
              child: InkWell(
                onTap: _toggle,
                borderRadius: BorderRadius.circular(FluxRadius.pill),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
                    decoration: BoxDecoration(
                      color: FluxColors.disclosureOf(context),
                      borderRadius: BorderRadius.circular(FluxRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        widget.leading,
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: FluxColors.inkOf(context),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            trailing,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _expanded ? 0.25 : 0.0,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : FluxMotion.revealDuration,
                          curve: FluxMotion.revealCurve,
                          child: FluxIcon(
                            icon: FluxIcons.arrowRight01,
                            size: 14,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // The list is always laid out (so its full height can be measured)
        // but clipped to the animated height factor: it grows downward from
        // the button without a card background. Semantics are excluded while
        // collapsed so the hidden rows are not announced.
        ExcludeSemantics(
          excluding: !_expanded,
          child: ClipRect(
            child: Align(
              heightFactor: _factor.value,
              alignment: Alignment.topCenter,
              child: Column(
                key: _contentKey,
                mainAxisSize: MainAxisSize.min,
                children: [widget.child],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A row inside a [FluxDisclosure]: a leading mark, a title, an optional second
/// line. Tappable — and showing its chevron — only when [onTap] is given, so an
/// informational row never looks actionable.
class FluxDisclosureRow extends StatelessWidget {
  const FluxDisclosureRow({
    super.key,
    required this.leading,
    required this.title,
    this.onTap,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final onTap = this.onTap;
    final radius = BorderRadius.circular(FluxRadius.sm);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle ??
                      Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                FluxIcon(
                  icon: FluxIcons.arrowRight01,
                  size: 13,
                  color: FluxColors.mutedOf(context),
                ),
              ],
            ],
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle ??
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: FluxColors.mutedOf(context),
                        fontSize: 12,
                        height: 1.3,
                      ),
            ),
          ],
        ],
      ),
    );

    final painted = Container(
      decoration: BoxDecoration(
        color: FluxColors.disclosureRowOf(context),
        borderRadius: radius,
      ),
      child: content,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: onTap == null
          ? painted
          : Semantics(
              button: true,
              label: title,
              onTap: onTap,
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: FluxMotion.minTapTarget,
                  minHeight: FluxMotion.minTapTarget,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: radius,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: radius,
                    child: Align(
                      widthFactor: 1,
                      heightFactor: 1,
                      alignment: Alignment.center,
                      child: painted,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
