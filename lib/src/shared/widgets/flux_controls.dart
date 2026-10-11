import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/figma_assets.dart';
import 'package:finn_ai/src/shared/widgets/flux_icons.dart';
import 'package:finn_ai/src/shared/widgets/flux_motion.dart';

export 'package:finn_ai/src/shared/widgets/figma_assets.dart';
export 'package:finn_ai/src/shared/widgets/flux_disclosure.dart';
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
