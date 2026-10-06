import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// Replays a short pop whenever [swapKey] changes: the control under it
/// scales up from 80% with a little overshoot and fades in. For a button that
/// changes what it does (send → stop, run → running) so the change is seen,
/// not just swapped.
class FluxSwap extends StatefulWidget {
  const FluxSwap({super.key, required this.swapKey, required this.child});

  final Object swapKey;
  final Widget child;

  @override
  State<FluxSwap> createState() => _FluxSwapState();
}

class _FluxSwapState extends State<FluxSwap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  late final Animation<double> _pop =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(covariant FluxSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.swapKey == widget.swapKey) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => Opacity(
          // Never fully transparent, so semantics survive the animation.
          opacity: (.2 + .8 * _fade.value).clamp(0.0, 1.0),
          child: Transform.scale(scale: .8 + .2 * _pop.value, child: child),
        ),
      );
}

/// Brings a newly added item in once: it fades, rises [rise] logical pixels
/// and grows from 96% toward [alignment]: a message from the user grows out
/// of the right, a reply out of the left. Does nothing under reduced motion.
class FluxEntrance extends StatefulWidget {
  const FluxEntrance({
    super.key,
    required this.child,
    this.alignment = Alignment.bottomCenter,
    this.rise = 14,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Alignment alignment;
  final double rise;
  final Duration delay;

  @override
  State<FluxEntrance> createState() => _FluxEntranceState();
}

class _FluxEntranceState extends State<FluxEntrance>
    with SingleTickerProviderStateMixin {
  static const _run = Duration(milliseconds: 420);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _run + widget.delay,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    // The delay is part of one animation, so no timer outlives the widget.
    curve: Interval(
      widget.delay.inMilliseconds / (_run + widget.delay).inMilliseconds,
      1,
      curve: const Cubic(.2, .9, .25, 1),
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final t = _curve.value;
        return Opacity(
          alwaysIncludeSemantics: true,
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.rise * (1 - t)),
            child: Transform.scale(
              scale: .96 + .04 * t,
              alignment: widget.alignment,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Scales whatever it wraps down slightly while a finger is on it.
///
/// Observes pointers with a [Listener] rather than a gesture recogniser, so the
/// wrapped control keeps its own tap handling and ink ripple.
class FluxPressScale extends StatefulWidget {
  const FluxPressScale({
    super.key,
    required this.child,
    this.scale = .94,
    this.enabled = true,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  /// The point it shrinks toward. Defaults to the centre; a control wider than
  /// it is tall — the brand row — names an edge so the glyph does not drift
  /// sideways on press.
  final Alignment alignment;

  @override
  State<FluxPressScale> createState() => _FluxPressScaleState();
}

class _FluxPressScaleState extends State<FluxPressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FluxMotion.pressIn,
    reverseDuration: FluxMotion.pressOut,
  );
  late final Animation<double> _scale =
      Tween<double>(begin: 1, end: widget.scale).animate(
    CurvedAnimation(
      parent: _controller,
      curve: FluxMotion.pressCurve,
      reverseCurve: FluxMotion.pressReturnCurve,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    if (widget.enabled) _controller.forward();
  }

  void _release(PointerEvent _) => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final scale = _scale; // made while mounted; dispose must not be first
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: _release,
      onPointerCancel: _release,
      child: ScaleTransition(
        scale: scale,
        alignment: widget.alignment,
        child: widget.child,
      ),
    );
  }
}
