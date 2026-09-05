import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../l10n/l10n_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/flux_theme.dart';

abstract final class FluxIcons {
  static const add = HugeIcons.strokeRoundedAdd01;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const arrowUp01 = HugeIcons.strokeRoundedArrowUp01;
  static const arrowUp02 = HugeIcons.strokeRoundedArrowUp02;
  static const menu = HugeIcons.strokeRoundedMenu02;
  static const copy = HugeIcons.strokeRoundedCopy;
  static const exchange = HugeIcons.strokeRoundedExchange01;
  static const internet = HugeIcons.strokeRoundedInternet;
  static const sad = HugeIcons.strokeRoundedSad02;
  static const canvas = HugeIcons.strokeRoundedCanvas;
  static const you = HugeIcons.strokeRoundedRelieved02;
  static const skills = HugeIcons.strokeRoundedBookOpenText;
  static const chip = HugeIcons.strokeRoundedChip;
  static const settings = HugeIcons.strokeRoundedSettings03;
  static const edit = HugeIcons.strokeRoundedPencilEdit02;
  static const security = HugeIcons.strokeRoundedSecurityWarning;
  static const magic = HugeIcons.strokeRoundedAiMagic;
  static const lock = HugeIcons.strokeRoundedCircleLock01;
  static const download = HugeIcons.strokeRoundedDownloadCircle01;
  static const bluetooth = HugeIcons.strokeRoundedBluetooth;
  static const robot = HugeIcons.strokeRoundedMachineRobot;
  static const leaf = HugeIcons.strokeRoundedLeaf01;
  static const game = HugeIcons.strokeRoundedGameController03;
  static const refresh = HugeIcons.strokeRoundedRefresh01;
  static const loading = HugeIcons.strokeRoundedLoading03;
  static const check = HugeIcons.strokeRoundedCheckmarkCircle02;
  static const flag = HugeIcons.strokeRoundedFlag01;
  static const mic = HugeIcons.strokeRoundedMic01;
  static const micOff = HugeIcons.strokeRoundedMicOff01;
  static const voiceWaveform = HugeIcons.strokeRoundedAudioWave01;
}

abstract final class FigmaAssets {
  static const _root = 'assets/runtime';

  static const back = '$_root/icon_144_180.svg';
  static const welcomeArrow = '$_root/icon_144_170.svg';
  static const privacy = '$_root/icon_144_195.svg';
  static const magic = '$_root/icon_144_243.svg';
  static const security = '$_root/icon_149_193.svg';
  static const download = '$_root/icon_144_238.svg';
  static const menu = '$_root/icon_59_31.svg';
  static const modelChevron = '$_root/icon_59_32.svg';
  static const send = '$_root/icon_59_14.svg';
  static const activeSend = '$_root/icon_59_65.svg';
  static const add = '$_root/icon_59_19.svg';
  static const sidebarActions = '$_root/icon_98_197.svg';
  static const sidebarCreations = '$_root/icon_98_202.svg';
  static const sidebarYou = '$_root/icon_101_181.svg';
  static const sidebarSkills = '$_root/icon_101_193.svg';
  static const noHistory = '$_root/icon_114_151.svg';
  static const creationBack = '$_root/icon_178_212.svg';
  static const creationSend = '$_root/icon_178_220.svg';
  static const creationAdd = '$_root/icon_178_228.svg';
}

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
  });

  final String asset;
  final double width;
  final double height;
  final Color? color;
  final BlendMode colorBlendMode;
  final bool isNavTile;
  final bool invertForDark;

  /// Render the SVG's own colors even in dark mode. Use for icons designed to
  /// sit on light surfaces (like the white composer pill), where the automatic
  /// dark-mode tint would make them invisible.
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
        filter = ColorFilter.mode(FluxColors.darkInk, BlendMode.srcIn);
      }
    }

    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      colorFilter: filter,
    );
  }
}

class FluxIcon extends StatelessWidget {
  const FluxIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
    this.strokeWidth = 1.7,
  });

  final List<List<dynamic>> icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => HugeIcon(
        icon: icon,
        size: size,
        color: color ??
            DefaultTextStyle.of(context).style.color ??
            FluxColors.inkOf(context),
        strokeWidth: strokeWidth,
      );
}

class FluxIconButton extends StatelessWidget {
  const FluxIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 34,
    this.dark = false,
    this.tooltip,
  });

  final List<List<dynamic>> icon;
  final VoidCallback? onTap;
  final double size;
  final bool dark;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final bgColor = dark ? FluxColors.inkOf(context) : Colors.transparent;
    final fgColor =
        dark ? FluxColors.canvasOf(context) : FluxColors.inkOf(context);

    final button = SizedBox.square(
      dimension: math.max(48, size),
      child: Center(
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(size / 2),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: FluxIcon(icon: icon, size: size * .56, color: fgColor),
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class FluxPillButton extends StatelessWidget {
  const FluxPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final List<List<dynamic>>? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bgColor = onTap == null
        ? FluxColors.inkOf(context).withValues(alpha: .25)
        : FluxColors.inkOf(context);
    final fgColor = FluxColors.canvasOf(context);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(FluxRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FluxRadius.pill),
        child: SizedBox(
          height: compact ? 30 : 36,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 15 : 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: fgColor),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 7),
                  FluxIcon(icon: icon!, size: 14, color: fgColor),
                ],
              ],
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
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color:
                              FluxColors.inkOf(context).withValues(alpha: .5),
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

class FluxGlass extends StatelessWidget {
  const FluxGlass({
    super.key,
    required this.child,
    this.radius = FluxRadius.md,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final double radius;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (FluxColors.isDark(context)
            ? const Color(0xCC18181B)
            : const Color(0xD9FFFFFF));
    final effectiveBorder = borderColor ??
        (FluxColors.isDark(context)
            ? const Color(0x28FFFFFF)
            : const Color(0x18FFFFFF));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: effectiveBorder),
      ),
      child: child,
    );
  }
}

/// iOS-style bouncing with a much lighter touch. Overscroll drags meet about
/// 40% more resistance, and the bounce-back spring is stiffer and more damped,
/// so fast flings no longer throw headings or text far past the top and bottom
/// edges before settling back into view.
class FluxBouncingScrollPhysics extends BouncingScrollPhysics {
  const FluxBouncingScrollPhysics({super.parent});

  @override
  FluxBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      FluxBouncingScrollPhysics(parent: buildParent(ancestor));

  @override
  double frictionFactor(double overscrollFraction) =>
      math.pow(1 - overscrollFraction, 2) * 0.3;

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.5,
        stiffness: 200,
        // Damping ratio 1.8 against the stiffer 200 stiffness.
        damping: 36,
      );
}
