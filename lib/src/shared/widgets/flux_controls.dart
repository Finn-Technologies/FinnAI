import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

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
  static const cpu = HugeIcons.strokeRoundedCpu;
  static const error = HugeIcons.strokeRoundedAlertCircle;
  static const info = HugeIcons.strokeRoundedInformationCircle;
  static const moreHorizontal = HugeIcons.strokeRoundedMoreHorizontal;
  static const arrowRight01 = HugeIcons.strokeRoundedArrowRight01;
  static const arrowRight02 = HugeIcons.strokeRoundedArrowRight02;
  static const cloudOff = HugeIcons.strokeRoundedCloudOff;
  static const image = HugeIcons.strokeRoundedImage01;
  static const brokenImage = HugeIcons.strokeRoundedImage02;
  static const note = HugeIcons.strokeRoundedNote01;
  static const sourceCode = HugeIcons.strokeRoundedSourceCode;
  static const education = HugeIcons.strokeRoundedGraduationScroll;
  static const task = HugeIcons.strokeRoundedTask01;
  static const search = HugeIcons.strokeRoundedSearch01;
  static const alarm = HugeIcons.strokeRoundedAlarmClock;
  static const timer = HugeIcons.strokeRoundedTimer01;
  static const flashlight = HugeIcons.strokeRoundedFlashlight;
  static const volume = HugeIcons.strokeRoundedVolumeHigh;
  static const wifi = HugeIcons.strokeRoundedWifi01;
  static const calendar = HugeIcons.strokeRoundedCalendar01;
  static const navigation = HugeIcons.strokeRoundedNavigation01;
  static const camera = HugeIcons.strokeRoundedCamera01;
  static const battery = HugeIcons.strokeRoundedBatteryFull;
  static const moon = HugeIcons.strokeRoundedMoon02;
  static const sun = HugeIcons.strokeRoundedSun01;
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
    final enabled = onTap != null;
    final bgColor = dark ? FluxColors.inkOf(context) : Colors.transparent;
    final fgColor =
        dark ? FluxColors.canvasOf(context) : FluxColors.inkOf(context);

    final hit = math.max(48.0, size);
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

    final painted = Material(
      color: bgColor,
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
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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

/// A compact pill that reveals supporting detail beneath it.
///
/// Chat replies use it for the pages a turn cited and for the browser steps it
/// took, so both read as one disclosure affordance instead of two lookalikes.
///
/// The body is always laid out — clipped to an animated height factor — so its
/// full height can be measured the first time it opens.
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
  static const Duration _duration = Duration(milliseconds: 220);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    reverseDuration: _duration,
  )..addListener(_onFrame);

  late final CurvedAnimation _factor = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
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
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
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

/// A row inside a [FluxDisclosure]: a leading mark, a title line, and an
/// optional second line. Tappable — and showing its chevron — only when
/// [onTap] is provided, so a purely informational row never looks actionable.
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
          : ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
