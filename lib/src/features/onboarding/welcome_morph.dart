import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/onboarding/starfield.dart';
import 'package:finn_ai/src/features/onboarding/wide_step.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_window_frame.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Tells a step page that it is being revealed by the welcome morph rather
/// than shown on its own.
///
/// While [progress] runs from 0 to 1 the welcome card is travelling into the
/// step's artwork card, so the step hides its own card (the travelling one
/// stands in for it), marks it with [cardKey] so the morph knows where to
/// land, and brings its copy and controls in behind the card.
class StepReveal extends InheritedWidget {
  const StepReveal({
    super.key,
    required this.progress,
    required this.cardKey,
    required super.child,
  });

  final double progress;
  final GlobalKey cardKey;

  static StepReveal? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StepReveal>();

  /// [child] faded and lifted in over the part of the reveal from [start].
  Widget enter(Widget child, {double start = .5, double rise = 22}) {
    final x = Curves.easeOutCubic.transform(
      ((progress - start) / (1 - start)).clamp(0.0, 1.0),
    );
    return Opacity(
      opacity: x,
      child:
          Transform.translate(offset: Offset(0, rise * (1 - x)), child: child),
    );
  }

  @override
  bool updateShouldNotify(StepReveal old) =>
      old.progress != progress || old.cardKey != cardKey;
}

/// The welcome screen, and the move from it to the first step.
///
/// The pink card at the bottom of the welcome screen *becomes* the first
/// step's artwork card: a swipe up lifts and enlarges it into place while the
/// night sky gives way to the step's canvas and the step's copy rises in
/// beneath. The swipe drives the motion directly, so the card follows the
/// thumb; letting go past a sixth of the way (or with a flick) finishes it,
/// otherwise it settles back. [progress] belongs to the flow, which also
/// plays it backwards when the first step's Back returns here.
class WelcomeMorphPage extends StatefulWidget {
  const WelcomeMorphPage({
    super.key,
    required this.progress,
    required this.step,
    required this.artwork,
    required this.stepTitle,
    required this.onAdvance,
  });

  /// 0 = the welcome screen, 1 = the first step. Owned by the flow.
  final AnimationController progress;

  /// The first step, drawn under the welcome screen and revealed by the
  /// morph. It is exactly the page that replaces this one at 1.
  final Widget step;

  /// The first step's artwork and title, which the card turns into.
  final String artwork;
  final String stepTitle;

  /// Finishes the move (from a tap, a key, or a committed swipe).
  final VoidCallback onAdvance;

  @override
  State<WelcomeMorphPage> createState() => _WelcomeMorphPageState();
}

class _WelcomeMorphPageState extends State<WelcomeMorphPage> {
  final _stackKey = GlobalKey();
  final _cardKey = GlobalKey();
  double? _dragExtent;

  Rect? _cardRect() {
    final card = _cardKey.currentContext?.findRenderObject();
    final stack = _stackKey.currentContext?.findRenderObject();
    if (card is! RenderBox || stack is! RenderBox) return null;
    if (!card.hasSize || !stack.hasSize) return null;
    return card.localToGlobal(Offset.zero, ancestor: stack) & card.size;
  }

  void _dragStart(DragStartDetails _) {
    widget.progress.stop();
    _dragExtent = math.max(240, (context.size?.height ?? 800) * .55);
  }

  void _dragUpdate(DragUpdateDetails d) {
    final extent = _dragExtent;
    if (extent == null) return;
    widget.progress.value =
        (widget.progress.value - d.delta.dy / extent).clamp(0.0, 1.0);
  }

  void _dragEnd(DragEndDetails d) {
    _dragExtent = null;
    final v = d.primaryVelocity ?? 0;
    final commit = v < -350 || (v < 350 && widget.progress.value > .15);
    if (commit) {
      HapticFeedback.selectionClick();
      widget.onAdvance();
    } else {
      widget.progress.animateBack(
        0,
        // The morph giving its surface back: `morphReverseDuration` and
        // `morphReverseCurve` are the tokens for exactly that.
        duration: FluxMotion.morphReverseDuration,
        curve: FluxMotion.morphReverseCurve,
      );
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _dragStart,
        onVerticalDragUpdate: _dragUpdate,
        onVerticalDragEnd: _dragEnd,
        onVerticalDragCancel: () => _dragEnd(DragEndDetails()),
        child: FinnBlackScreen(
          child: LayoutBuilder(
            builder: (context, constraints) => AnimatedBuilder(
              animation: widget.progress,
              builder: (context, _) => _frame(
                context,
                constraints,
                widget.progress.value,
              ),
            ),
          ),
        ),
      );

  Widget _frame(BuildContext context, BoxConstraints constraints, double t) {
    // Only the sky bleeds; content stays inside the safe area.
    final padding = MediaQuery.paddingOf(context);
    final avail = constraints.maxHeight - padding.top - padding.bottom;
    final sy = stepScale(avail, morph: true);
    final wide = wideStepFits(constraints);
    final glowInset = welcomeGlowInset(constraints);
    final start = Rect.fromLTRB(
      glowInset,
      constraints.maxHeight - padding.bottom - 20 * sy - 106 * sy,
      constraints.maxWidth - glowInset,
      constraints.maxHeight - padding.bottom - 20 * sy,
    );
    double phase(double from, double to) =>
        ((t - from) / (to - from)).clamp(0.0, 1.0);
    // The canvas arrives under the card while it travels; the sky leaves
    // upward, a little slower than the card, so the card reads as rising
    // through it.
    final canvas = Curves.easeInOut.transform(phase(.12, .7));
    final skyOut = Curves.easeIn.transform(phase(0, .6));
    final copyOut = Curves.easeOut.transform(phase(0, .35));
    final travel = Curves.easeInOutCubic.transform(t);
    final end = _cardRect();
    final rect = end == null ? start : Rect.lerp(start, end, travel)!;
    final startRadius = welcomeGlowRadius(constraints);
    final radius = BorderRadius.lerp(
      BorderRadius.circular(startRadius),
      wide
          ? BorderRadius.circular(FinnWindowFrame.cornerRadius)
          : const BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
      travel,
    )!;
    final photo = Curves.easeInOut.transform(phase(.18, .78));
    final title = Curves.easeOut.transform(phase(.6, 1));

    return Stack(
      key: _stackKey,
      children: [
        // The step, drawn where it will be, revealed over the black. Not
        // built at rest, and never read out: it is a picture of the next
        // screen until it becomes it.
        if (t > 0)
          Positioned.fill(
            child: ExcludeSemantics(
                child: IgnorePointer(
              child: Opacity(
                opacity: canvas,
                child: canvas > .5
                    ? AnnotatedRegion<SystemUiOverlayStyle>(
                        value: FluxTheme.systemUiOverlayStyle(context),
                        child: _step(t),
                      )
                    : _step(t),
              ),
            )),
          ),
        if (skyOut < 1)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 1 - skyOut,
                child: Transform.translate(
                  offset: Offset(0, -80 * skyOut),
                  child: const Starfield(),
                ),
              ),
            ),
          ),
        // Brand bloom from the bottom edge, bottom-anchored so tall screens
        // grow the empty middle (wash bleeds 65px past it).
        if (skyOut < 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: -65 * sy - 120 * skyOut,
            height: 276 * sy,
            child: IgnorePointer(
              child: Opacity(
                opacity: .7 * (1 - skyOut),
                child: Image.asset(FigmaAssets.welcomeGlow, fit: BoxFit.fill),
              ),
            ),
          ),
        if (copyOut < 1)
          Positioned(
            top: padding.top + 441 * sy - 60 * copyOut,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 1 - copyOut,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 6 * copyOut,
                  sigmaY: 6 * copyOut,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      L10n.of(context).onboardingWelcome,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (copyOut < 1)
          Positioned(
            bottom: padding.bottom + 156 * sy + 30 * copyOut,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 1 - Curves.easeOut.transform(phase(0, .2)),
              child: wide
                  ? WelcomeStartButton(onTap: widget.onAdvance)
                  : Column(
                      children: [
                        const _FloatingArrow(color: Colors.white),
                        const SizedBox(height: 15),
                        Text(
                          L10n.of(context).onboardingSwipeToStart,
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 17,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                            color: Color(0x80FFFFFF),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        // The card: the welcome glow on its way to becoming the artwork.
        Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            child: _fadeWithoutLanding(
                end == null,
                canvas,
                ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (photo < 1) WelcomeGlowCard(radius: 0),
                      if (photo > 0)
                        Opacity(
                          opacity: photo,
                          child: Image.asset(
                            widget.artwork,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            excludeFromSemantics: true,
                          ),
                        ),
                      if (photo > 0)
                        Opacity(
                          opacity: photo,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0x59000000), Color(0x00666666)],
                              ),
                            ),
                          ),
                        ),
                      if (title > 0)
                        Positioned(
                          left: 25,
                          right: 25,
                          bottom: 30 - 12 * (1 - title),
                          child: Opacity(
                            opacity: title,
                            child: Text(
                              widget.stepTitle,
                              style: const TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 24,
                                height: 1.2,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )),
          ),
        ),
      ],
    );
  }

  /// A wide window lays the step out in its own panes and marks no card to
  /// land on; there the welcome card simply gives way to the step.
  Widget _fadeWithoutLanding(bool fade, double canvas, Widget card) =>
      fade ? Opacity(opacity: 1 - canvas, child: card) : card;

  Widget _step(double t) =>
      StepReveal(progress: t, cardKey: _cardKey, child: widget.step);
}

class _FloatingArrow extends StatefulWidget {
  const _FloatingArrow({this.color});

  /// Tint for the glyph. The asset ships black, so screens drawn on a dark
  /// backdrop pass their own colour.
  final Color? color;

  @override
  State<_FloatingArrow> createState() => _FloatingArrowState();
}

class _FloatingArrowState extends State<_FloatingArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final Animation<double> _animation = Tween<double>(
    begin: 0,
    end: -6,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));

  // Under reduced motion the arrow is drawn still, and the controller must
  // not run either: a ticker nobody listens to still asks for every frame.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arrow = FluxIcon(
      icon: FluxIcons.chevronUp,
      size: 26,
      color: widget.color,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return arrow;
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: child,
      ),
      child: arrow,
    );
  }
}
