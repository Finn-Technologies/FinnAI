import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Interactive touch wrapper with iOS/Android home screen long-press physics:
/// - Smooth spring scale-down on press down
/// - Haptic selection click
/// - Overshoot spring on long-press trigger with medium haptic pulse
class FluxSpringPressable extends StatefulWidget {
  const FluxSpringPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDownFactor = 0.96,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDownFactor;
  final bool enabled;

  @override
  State<FluxSpringPressable> createState() => _FluxSpringPressableState();
}

class _FluxSpringPressableState extends State<FluxSpringPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: 1.0,
    end: widget.scaleDownFactor,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOutBack,
  ));

  bool _pressed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    _pressed = true;
    _controller.forward();
    HapticFeedback.selectionClick();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_pressed) return;
    _pressed = false;
    _controller.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (!_pressed) return;
    _pressed = false;
    _controller.reverse();
  }

  void _handleLongPress() {
    if (!widget.enabled || widget.onLongPress == null) return;
    _pressed = false;
    _controller.reverse();
    HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: _handleLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// An individual action item in a [FluxContextMenu].
class FluxContextMenuItem {
  const FluxContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
}

/// Opens an iOS/Android home-screen style context menu attached to [targetKey] or [targetRect].
Future<T?> showFluxContextMenu<T>({
  required BuildContext context,
  required GlobalKey targetKey,
  required Widget previewWidget,
  required List<FluxContextMenuItem> items,
  BorderRadius? targetBorderRadius,
}) {
  final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null || !renderBox.hasSize) return Future.value(null);

  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return Future.value(null);

  final targetRect =
      renderBox.localToGlobal(Offset.zero, ancestor: overlay) & renderBox.size;

  return Navigator.of(context, rootNavigator: true).push<T>(
    _FluxContextMenuRoute<T>(
      targetRect: targetRect,
      previewWidget: previewWidget,
      items: items,
      targetBorderRadius:
          targetBorderRadius ?? BorderRadius.circular(FluxRadius.md),
      isDark: FluxColors.isDark(context),
    ),
  );
}

class _FluxContextMenuRoute<T> extends PopupRoute<T> {
  _FluxContextMenuRoute({
    required this.targetRect,
    required this.previewWidget,
    required this.items,
    required this.targetBorderRadius,
    required this.isDark,
  });

  final Rect targetRect;
  final Widget previewWidget;
  final List<FluxContextMenuItem> items;
  final BorderRadius targetBorderRadius;
  final bool isDark;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss menu';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _FluxContextMenuOverlay(
      route: this,
      animation: animation,
    );
  }
}

class _FluxContextMenuOverlay extends StatelessWidget {
  const _FluxContextMenuOverlay({
    required this.route,
    required this.animation,
  });

  final _FluxContextMenuRoute<dynamic> route;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isDark = route.isDark;

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final springAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      reverseCurve: Curves.easeInCubic,
    );

    // Calculate layout geometry
    final targetRect = route.targetRect;
    final spaceBelow = screenSize.height - targetRect.bottom;
    final spaceAbove = targetRect.top;
    final showBelow = spaceBelow >= 220 || spaceBelow >= spaceAbove;

    const double menuWidth = 224.0;
    final menuHeight = (route.items.length * 48.0) + 16.0;

    // Horizontal positioning for menu: align with target or clamp within screen margins
    double menuLeft = targetRect.left;
    if (menuLeft + menuWidth > screenSize.width - 16) {
      menuLeft = screenSize.width - menuWidth - 16;
    }
    if (menuLeft < 16) {
      menuLeft = 16;
    }

    final double menuTop = showBelow
        ? math.min(
            targetRect.bottom + 10.0, screenSize.height - menuHeight - 16.0)
        : math.max(targetRect.top - menuHeight - 10.0, 16.0);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Backdrop blur + dim scrim
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: AnimatedBuilder(
                animation: curvedAnimation,
                builder: (context, _) => BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 18.0 * curvedAnimation.value,
                    sigmaY: 18.0 * curvedAnimation.value,
                  ),
                  child: ColoredBox(
                    color: (isDark ? Colors.black : Colors.black87).withValues(
                      alpha: (isDark ? 0.45 : 0.28) * curvedAnimation.value,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Elevated target snapshot / preview (STATIONARY, perfectly anchored)
          Positioned(
            left: targetRect.left,
            top: targetRect.top,
            width: targetRect.width,
            height: targetRect.height,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: curvedAnimation,
                builder: (context, child) => Container(
                  decoration: BoxDecoration(
                    borderRadius: route.targetBorderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: (isDark ? 0.42 : 0.18) * curvedAnimation.value,
                        ),
                        blurRadius: 20 * curvedAnimation.value,
                        spreadRadius: 1,
                        offset: Offset(0, 4 * curvedAnimation.value),
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: route.previewWidget,
              ),
            ),
          ),

          // 3. Floating Frosted Context Menu Card with refined spring entrance
          Positioned(
            left: menuLeft,
            top: menuTop,
            width: menuWidth,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final scale = 0.78 + 0.22 * springAnimation.value;
                final opacity = fadeAnimation.value.clamp(0.0, 1.0);
                final translateY =
                    (showBelow ? -12.0 : 12.0) * (1.0 - springAnimation.value);

                return Transform.translate(
                  offset: Offset(0, translateY),
                  child: Transform.scale(
                    scale: scale,
                    alignment: showBelow
                        ? (targetRect.left > screenSize.width / 2
                            ? Alignment.topRight
                            : Alignment.topLeft)
                        : (targetRect.left > screenSize.width / 2
                            ? Alignment.bottomRight
                            : Alignment.bottomLeft),
                    child: Opacity(
                      opacity: opacity,
                      child: child,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(FluxRadius.card),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xEB222226)
                          : const Color(0xF5FFFFFF),
                      borderRadius: BorderRadius.circular(FluxRadius.card),
                      border: Border.all(
                        color: isDark
                            ? const Color(0x33FFFFFF)
                            : const Color(0x18000000),
                        width: 0.75,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.42 : 0.14,
                          ),
                          blurRadius: 24,
                          spreadRadius: 1,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < route.items.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              thickness: 0.6,
                              indent: 10,
                              endIndent: 10,
                              color: isDark
                                  ? const Color(0x22FFFFFF)
                                  : const Color(0x15000000),
                            ),
                          _ContextMenuItemTile(
                            item: route.items[i],
                            isDark: isDark,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextMenuItemTile extends StatelessWidget {
  const _ContextMenuItemTile({
    required this.item,
    required this.isDark,
  });

  final FluxContextMenuItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = item.isDestructive
        ? (FluxColors.destructiveOf(context))
        : (isDark ? Colors.white : const Color(0xFF18181B));

    final iconColor = item.isDestructive
        ? (FluxColors.destructiveOf(context))
        : (isDark ? const Color(0xFFE4E4E7) : const Color(0xFF27272A));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop();
          item.onTap();
        },
        borderRadius: BorderRadius.circular(FluxRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              FluxIcon(
                icon: item.icon,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: 'InstrumentSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
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
