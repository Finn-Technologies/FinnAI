import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// Where a floating sheet rests, and how it is drawn.
///
/// Sheets float: they keep [margin] from the left, right and bottom edges so
/// what is behind them stays in view around the panel, the way a system sheet
/// floats on a modern phone. Their corners follow the display's own rounding.
abstract final class FinnSheetGeometry {
  /// Gap kept to the left, right and bottom screen edges.
  static const double margin = 10;

  /// The panel's corner radius: close to a phone display's corner, so the
  /// panel's rounding runs parallel to the glass at the bottom.
  static const double radius = 32;

  /// Widest a sheet grows on a tablet or a desktop window.
  static const double maxWidth = 560;

  /// Distance from the panel's bottom edge to the screen's bottom edge.
  ///
  /// Sits above a keyboard when one is open, and above the navigation bar
  /// (or gesture handle) when not, never closer than [margin].
  static double bottomOf(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    if (keyboard > 0) return keyboard + margin;
    return math.max(margin, media.viewPadding.bottom + 4);
  }
}

/// The rectangle [key]'s widget occupies on screen, transforms included, or
/// null when it is not laid out. This is the origin a morphing sheet grows
/// from: a scaled-down composer reports its scaled-down button.
Rect? globalRectOf(GlobalKey key) {
  final context = key.currentContext;
  return context == null ? null : globalRectOfContext(context);
}

/// [globalRectOf] for the widget that owns [context] (a `Builder`'s, say).
Rect? globalRectOfContext(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

/// A floating panel that grows out of the control that opened it.
///
/// At [progress] 0 the panel is exactly [origin] — the button's own rectangle,
/// corner radius and fill — and at 1 it is this widget's laid-out bounds. In
/// between, the shape travels and grows on one curve, the fill turns from the
/// button's colour to the panel's, and [child] (always laid out at the final
/// size) fades in once the shape has room for it. Closing runs the same path
/// back into the button, so the panel visibly *is* the button, enlarged.
///
/// Without an [origin] the panel rises a short way from below and fades in.
class FinnMorphSurface extends StatelessWidget {
  const FinnMorphSurface({
    super.key,
    required this.progress,
    required this.child,
    this.origin,
    this.originColor,
    this.originRadius,
    this.radius = FinnSheetGeometry.radius,
  });

  /// 0 = collapsed into [origin], 1 = fully open. May overshoot 1 a little.
  final Animation<double> progress;
  final Widget child;

  /// The opener's rectangle in global coordinates.
  final Rect? origin;

  /// The opener's fill, which the panel starts from. Defaults to the glass.
  final Color? originColor;

  /// The opener's corner radius. Defaults to a circle of [origin]'s height.
  final double? originRadius;
  final double radius;

  /// The panel's fill: the frosted tint as it reads over the canvas, made
  /// opaque. It used to be that tint over a 28-sigma backdrop blur, which
  /// re-blurred the whole sheet's area on every frame of the morph (the
  /// "+" sheet's dropped frames); the panel now looks as it did at rest
  /// over a quiet screen, and costs a flat fill.
  static Color glassOf(BuildContext context) => Color.alphaBlend(
        FluxColors.isDark(context)
            ? const Color(0xD91E1E24)
            : const Color(0xE0FFFFFF),
        FluxColors.canvasOf(context),
      );

  /// The panel's 1px edge: a light rim on dark, a soft shade on light.
  static Color rimOf(BuildContext context) => FluxColors.isDark(context)
      ? const Color(0x1FFFFFFF)
      : const Color(0x14000000);

  @override
  Widget build(BuildContext context) {
    final glass = glassOf(context);
    final from = originColor ?? glass;
    final rim = rimOf(context);
    final dark = FluxColors.isDark(context);
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final t = progress.value;
        final unit = t.clamp(0.0, 1.0);
        // The fill settles on glass while the shape is still small, so the
        // button's colour is only seen where the button was.
        final fill = Color.lerp(
          from,
          glass,
          Curves.easeOut.transform((unit / .55).clamp(0.0, 1.0)),
        )!;
        // Content waits until the panel has grown enough to hold it, and
        // on the way back leaves first, so the shrinking shape never crops a
        // still-legible sheet.
        final closing = progress.status == AnimationStatus.reverse;
        final reveal = Curves.easeOut.transform(
          (closing ? (unit - .62) / .38 : (unit - .32) / .68).clamp(0.0, 1.0),
        );
        return _MorphClip(
          t: t,
          origin: origin,
          originRadius: originRadius,
          radius: radius,
          shadow: Colors.black.withValues(alpha: (dark ? .45 : .14) * unit),
          rim: rim,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(child: ColoredBox(color: fill)),
              Opacity(
                opacity: reveal,
                child: Transform.scale(
                  scale: .97 + .03 * reveal,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MorphClip extends SingleChildRenderObjectWidget {
  const _MorphClip({
    required this.t,
    required this.origin,
    required this.originRadius,
    required this.radius,
    required this.shadow,
    required this.rim,
    required super.child,
  });

  final double t;
  final Rect? origin;
  final double? originRadius;
  final double radius;
  final Color shadow;
  final Color rim;

  @override
  _RenderMorphClip createRenderObject(BuildContext context) => _RenderMorphClip(
        t: t,
        origin: origin,
        originRadius: originRadius,
        radius: radius,
        shadow: shadow,
        rim: rim,
      );

  @override
  void updateRenderObject(BuildContext context, _RenderMorphClip renderObject) {
    renderObject
      ..t = t
      ..origin = origin
      ..originRadius = originRadius
      ..radius = radius
      ..shadow = shadow
      ..rim = rim;
  }
}

class _RenderMorphClip extends RenderProxyBox {
  _RenderMorphClip({
    required double t,
    required Rect? origin,
    required double? originRadius,
    required double radius,
    required Color shadow,
    required Color rim,
  })  : _t = t,
        _origin = origin,
        _originRadius = originRadius,
        _radius = radius,
        _shadow = shadow,
        _rim = rim;

  double _t;
  set t(double value) {
    if (value == _t) return;
    _t = value;
    markNeedsPaint();
  }

  Rect? _origin;
  set origin(Rect? value) {
    if (value == _origin) return;
    _origin = value;
    markNeedsPaint();
  }

  double? _originRadius;
  set originRadius(double? value) {
    if (value == _originRadius) return;
    _originRadius = value;
    markNeedsPaint();
  }

  double _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  Color _shadow;
  set shadow(Color value) {
    if (value == _shadow) return;
    _shadow = value;
    markNeedsPaint();
  }

  Color _rim;
  set rim(Color value) {
    if (value == _rim) return;
    _rim = value;
    markNeedsPaint();
  }

  /// The start shape in local coordinates.
  Rect _start() {
    final full = Offset.zero & size;
    final origin = _origin;
    if (origin == null) {
      // No opener: a slightly smaller panel a little below the final one.
      return Rect.fromCenter(
        center: full.center.translate(0, 36),
        width: full.width * .94,
        height: full.height * .94,
      );
    }
    final toLocal = Matrix4.tryInvert(getTransformTo(null));
    if (toLocal == null) return full;
    return MatrixUtils.transformRect(toLocal, origin);
  }

  RRect _shape() {
    final full = Offset.zero & size;
    final start = _start();
    final t = _t;
    // Width leads, height follows: the panel spreads sideways out of the
    // button before it rises, which reads as growing *from* it.
    final tx =
        Curves.easeOutCubic.transform(t.clamp(0.0, 1.0)) + (t > 1 ? t - 1 : 0);
    final ty = t;
    final rect = Rect.fromLTRB(
      ui.lerpDouble(start.left, full.left, tx)!,
      ui.lerpDouble(start.top, full.top, ty)!,
      ui.lerpDouble(start.right, full.right, tx)!,
      ui.lerpDouble(start.bottom, full.bottom, ty)!,
    );
    final from =
        _origin == null ? _radius : (_originRadius ?? start.shortestSide / 2);
    final r = math.min(
      ui.lerpDouble(from, _radius, t.clamp(0.0, 1.0))!,
      rect.shortestSide / 2,
    );
    return RRect.fromRectAndRadius(rect, Radius.circular(math.max(0, r)));
  }

  ClipRRectLayer? _clip() =>
      layer is ClipRRectLayer ? layer! as ClipRRectLayer : null;

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_shape().contains(position)) return false;
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _t <= 0) {
      layer = null;
      return;
    }
    final shape = _shape();
    final canvas = context.canvas;
    if (_shadow.a > 0) {
      canvas.drawRRect(
        shape.shift(offset + const Offset(0, 10)),
        Paint()
          ..color = _shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
    }
    layer = context.pushClipRRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      shape,
      (context, offset) {
        context.paintChild(child!, offset);
        context.canvas.drawRRect(
          shape.shift(offset).deflate(.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = _rim,
        );
      },
      oldLayer: _clip(),
    );
  }
}

/// Shows [builder]'s content as a floating sheet that grows out of [origin]
/// (when given) and shrinks back into it on close. A tap outside or a drag
/// down puts it away.
Future<T?> showFinnMorphSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Rect? origin,
  Color? originColor,
  double? originRadius,
  String? barrierLabel,
}) {
  HapticFeedback.selectionClick();
  return Navigator.of(context).push<T>(
    _MorphSheetRoute<T>(
      builder: builder,
      origin: origin,
      originColor: originColor,
      originRadius: originRadius,
      barrierLabel: barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: FluxColors.isDark(context)
          ? const Color(0x59000000)
          : const Color(0x24000000),
    ),
  );
}

class _MorphSheetRoute<T> extends PopupRoute<T> {
  _MorphSheetRoute({
    required this.builder,
    required this.origin,
    required this.originColor,
    required this.originRadius,
    required this.barrierLabel,
    required this.barrierColor,
  });

  final WidgetBuilder builder;
  final Rect? origin;
  final Color? originColor;
  final double? originRadius;

  @override
  final String barrierLabel;

  @override
  final Color barrierColor;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => FluxMotion.morphDuration;

  @override
  Duration get reverseTransitionDuration => FluxMotion.morphReverseDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      FinnFloatingSheet(
        animation: animation,
        origin: origin,
        originColor: originColor,
        originRadius: originRadius,
        onDismiss: () => Navigator.of(context).maybePop(),
        child: Builder(builder: builder),
      );
}

/// A sheet resting at the bottom of the screen with [FinnSheetGeometry]'s
/// margins, drawn by [FinnMorphSurface] and dismissed by a drag down.
class FinnFloatingSheet extends StatefulWidget {
  const FinnFloatingSheet({
    super.key,
    required this.animation,
    required this.child,
    required this.onDismiss,
    this.origin,
    this.originColor,
    this.originRadius,
    this.maxWidth = FinnSheetGeometry.maxWidth,
    this.bottom,
  });

  /// Linear 0..1 open progress (a route's animation or a controller).
  final Animation<double> animation;
  final Widget child;
  final VoidCallback onDismiss;
  final Rect? origin;
  final Color? originColor;
  final double? originRadius;
  final double maxWidth;

  /// Overrides [FinnSheetGeometry.bottomOf].
  final double? bottom;

  @override
  State<FinnFloatingSheet> createState() => _FinnFloatingSheetState();
}

class _FinnFloatingSheetState extends State<FinnFloatingSheet> {
  double _drag = 0;
  late CurvedAnimation _curve = _curved();

  CurvedAnimation _curved() => CurvedAnimation(
        parent: widget.animation,
        curve: FluxMotion.morphCurve,
        reverseCurve: FluxMotion.morphReverseCurve,
      );

  @override
  void didUpdateWidget(covariant FinnFloatingSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _curve.dispose();
      _curve = _curved();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = widget.bottom ?? FinnSheetGeometry.bottomOf(context);
    const margin = FinnSheetGeometry.margin;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        Positioned(
          left: margin,
          right: margin,
          bottom: bottom,
          top: media.padding.top + margin,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxWidth),
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: GestureDetector(
                  onVerticalDragUpdate: (d) =>
                      setState(() => _drag = math.max(0, _drag + d.delta.dy)),
                  onVerticalDragEnd: (d) {
                    if (_drag > 80 || (d.primaryVelocity ?? 0) > 600) {
                      widget.onDismiss();
                    } else {
                      setState(() => _drag = 0);
                    }
                  },
                  child: FinnMorphSurface(
                    progress: reduced ? widget.animation : _curve,
                    origin: widget.origin,
                    originColor: widget.originColor,
                    originRadius: widget.originRadius,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The small pill at the top of a floating sheet that says "drag me down".
class FinnSheetHandle extends StatelessWidget {
  const FinnSheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: FluxColors.inkOf(context).withValues(alpha: .16),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
}
