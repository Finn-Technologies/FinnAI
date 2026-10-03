import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
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
    this.semanticLabel,
    this.expandHitArea = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDownFactor;
  final bool enabled;

  /// What a screen reader announces. Required for any control whose painted
  /// content is only an icon or an image — without it the node is announced as
  /// an unlabelled button.
  final String? semanticLabel;

  /// Pads the gesture area out to [FluxMotion.minTapTarget] in both axes. Off
  /// by default because the widget also wraps large surfaces (chat bubbles,
  /// cards) that must not grow.
  final bool expandHitArea;

  @override
  State<FluxSpringPressable> createState() => _FluxSpringPressableState();
}

class _FluxSpringPressableState extends State<FluxSpringPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FluxMotion.pressIn,
    reverseDuration: FluxMotion.pressOut,
  );
  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: 1.0,
    end: widget.scaleDownFactor,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: FluxMotion.pressCurve,
    reverseCurve: FluxMotion.pressReturnCurve,
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
    final enabled = widget.enabled;
    Widget content = enabled
        ? GestureDetector(
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
          )
        : widget.child;

    if (widget.expandHitArea) {
      content = Align(
        widthFactor: 1,
        heightFactor: 1,
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: FluxMotion.minTapTarget,
            minHeight: FluxMotion.minTapTarget,
          ),
          child: content,
        ),
      );
    }

    final label = widget.semanticLabel;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: label != null,
      onTap: enabled ? widget.onTap : null,
      onLongPress: enabled ? widget.onLongPress : null,
      child: content,
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
      barrierLabel: L10n.of(context).commonDismiss,
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
    required this.barrierLabel,
  });

  final Rect targetRect;
  final Widget previewWidget;
  final List<FluxContextMenuItem> items;
  final BorderRadius targetBorderRadius;
  final bool isDark;

  @override
  final String? barrierLabel;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => FluxMotion.modalDuration;

  @override
  Duration get reverseTransitionDuration => FluxMotion.modalDuration;

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

class _FluxContextMenuOverlay extends StatefulWidget {
  const _FluxContextMenuOverlay({
    required this.route,
    required this.animation,
  });

  final _FluxContextMenuRoute<dynamic> route;
  final Animation<double> animation;

  @override
  State<_FluxContextMenuOverlay> createState() =>
      _FluxContextMenuOverlayState();
}

class _FluxContextMenuOverlayState extends State<_FluxContextMenuOverlay> {
  late final CurvedAnimation curvedAnimation = CurvedAnimation(
    parent: widget.animation,
    curve: FluxMotion.modalCurve,
    reverseCurve: FluxMotion.modalReverseCurve,
  );

  late final CurvedAnimation springAnimation = CurvedAnimation(
    parent: widget.animation,
    curve: Curves.easeOutBack,
    reverseCurve: FluxMotion.modalReverseCurve,
  );

  late final CurvedAnimation fadeAnimation = CurvedAnimation(
    parent: widget.animation,
    curve: const Interval(0.0, 0.65, curve: FluxMotion.modalCurve),
    reverseCurve: FluxMotion.modalReverseCurve,
  );

  @override
  void dispose() {
    curvedAnimation.dispose();
    springAnimation.dispose();
    fadeAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final screenSize = MediaQuery.sizeOf(context);
    final isDark = route.isDark;

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
                builder: (context, _) => ColoredBox(
                  // Through [FluxColors.scrimOf]: a black scrim over the
                  // near-black canvas barely registers, so in dark the menu opened
                  // with no dimming and no sense of being modal.
                  color: FluxColors.scrimOf(
                    context,
                    alpha: (isDark ? 0.45 : 0.10) * curvedAnimation.value,
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
                        color: FluxColors.elevationOf(context).withValues(
                          alpha: (isDark ? 0.22 : 0.18) * curvedAnimation.value,
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
              animation: widget.animation,
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
                borderRadius: BorderRadius.circular(FluxRadius.sheet + 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: FluxColors.controlOf(context),
                    borderRadius: BorderRadius.circular(FluxRadius.sheet + 1),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < route.items.length; i++) ...[
                        _ContextMenuItemTile(item: route.items[i]),
                      ],
                    ],
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
  const _ContextMenuItemTile({required this.item});

  final FluxContextMenuItem item;

  @override
  Widget build(BuildContext context) {
    // The item's own text token, so the same label has the same contrast
    // wherever the menu is opened from. Previously a raw #18181B / white pair
    // that ignored the active theme.
    final textColor = item.isDestructive
        ? FluxColors.destructiveOf(context)
        : FluxColors.inkOf(context);

    final iconColor = item.isDestructive
        ? FluxColors.destructiveOf(context)
        : FluxColors.actionOf(context);

    return Semantics(
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: FluxMotion.minTapTarget,
            minHeight: FluxMotion.minTapTarget,
          ),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop();
              item.onTap();
            },
            borderRadius: BorderRadius.circular(FluxRadius.sm),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    FluxIcon(
                      icon: item.icon,
                      size: 22,
                      strokeWidth: 1.5,
                      color: iconColor,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: 'InstrumentSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
