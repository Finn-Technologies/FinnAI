import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The fixed sidebar panel, the home screen that slides over it, the scrim and
/// the one control that toggles it — the whole open/close surface.
///
/// Both FinnAI and FinnAI Code draw their shell with this, so the two modes
/// open, close and drag identically. The menu/close control is drawn *here*
/// rather than inside [home], because [home] slides aside and rounds away as
/// the panel opens. It morphs from the hamburger to the cross as [progress]
/// moves, so it reads as one control changing state instead of two buttons
/// trading places.
class FinnSidebarSurface extends StatelessWidget {
  const FinnSidebarSurface({
    super.key,
    required this.home,
    required this.sidebar,
    required this.sidebarWidth,
    required this.progress,
    required this.sidebarOpen,
    required this.toggleLeft,
    required this.toggleTop,
    required this.onToggle,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.docked = false,
  });

  /// True when the window is wide enough to keep the panel beside the home
  /// screen. There is then nothing to slide, scrim or toggle: the panel is
  /// always open and [progress], the drag callbacks and [toggleLeft] go unused.
  final bool docked;

  /// The main screen, which slides aside and rounds as the panel is uncovered.
  final Widget home;

  /// The panel. Empty until it has been opened once, so a first-run install
  /// never builds the conversation grid.
  final Widget sidebar;

  /// Width of the panel, and so the distance the home screen slides by. The
  /// panel itself never moves.
  final double sidebarWidth;

  /// 0 = closed, 1 = open. Drives the shift, the rounding, the morph and the
  /// gesture-driven drag, so they can never disagree.
  final double progress;
  final bool sidebarOpen;

  /// Where the toggle sits: aligned with the home header's reserved slot.
  final double toggleLeft;
  final double toggleTop;

  final VoidCallback onToggle;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    if (docked) {
      return Row(
        children: [
          SizedBox(width: sidebarWidth, child: sidebar),
          ColoredBox(
            color: FluxColors.panelEdgeOf(context),
            child: const SizedBox(width: 1, height: double.infinity),
          ),
          Expanded(child: RepaintBoundary(child: home)),
        ],
      );
    }
    final motion = progress;
    final radius = BorderRadius.circular(50 * motion);
    return GestureDetector(
      // Horizontal only: the chat list underneath scrolls vertically and must
      // keep doing so, and the recognizer only accepts once the finger has
      // travelled sideways past the touch slop.
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: onDragStart,
      onHorizontalDragUpdate: onDragUpdate,
      onHorizontalDragEnd: onDragEnd,
      child: Stack(
        children: [
          // The panel never moves. It sits behind the home screen at the left
          // edge and is uncovered as the home screen slides away, so opening
          // and closing only ever animate one surface.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Offstage(
              offstage: motion == 0 && !sidebarOpen,
              child: IgnorePointer(
                ignoring: !sidebarOpen,
                child: ExcludeSemantics(
                  excluding: !sidebarOpen,
                  child: sidebar,
                ),
              ),
            ),
          ),
          // The home screen, shifted aside, rounded and lifted as the panel
          // is uncovered. The scrim that closes the panel rides with it, so
          // a tap on the sliver of home screen still closes it while taps on
          // the panel itself reach the panel.
          Transform.translate(
            offset: Offset(sidebarWidth * motion, 0),
            child: Stack(
              children: [
                ExcludeSemantics(
                  excluding: sidebarOpen,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      // The design outlines the home sheet with a hairline, so
                      // the sliver beside the panel reads as an edge rather
                      // than as the panel simply stopping. It fades in with
                      // the sheet's rounding.
                      border: Border.all(
                        color: FluxColors.panelEdgeOf(context).withValues(
                          alpha: motion,
                        ),
                        width: 1,
                      ),
                      boxShadow: [
                        if (motion > 0)
                          BoxShadow(
                            // The only shadow in the app that had no dark
                            // branch at all: 10% black on a near-black canvas left
                            // the home sheet with no lift.
                            color: FluxColors.elevationOf(context).withValues(
                              alpha: 0.10,
                            ),
                            blurRadius: 55,
                            offset: const Offset(-10, 0),
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      // Rasterised once: sliding the sheet then moves a cached
                      // layer instead of repainting the whole screen every
                      // frame.
                      child: RepaintBoundary(child: home),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !sidebarOpen,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onToggle(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Above the panel and the home screen, so it stays reachable in both
          // states. It rides the home screen's own travel: the design shows
          // the control sliding off to the right with the surface it belongs
          // to, rather than staying put over the panel.
          Positioned(
            left: toggleLeft + sidebarWidth * motion,
            top: toggleTop,
            child: FinnSidebarToggleButton(
              progress: motion,
              onToggle: onToggle,
              openTooltip: L10n.of(context).chatOpenMenuTooltip,
              closeTooltip: L10n.of(context).commonClose,
            ),
          ),
        ],
      ),
    );
  }
}

/// Owns the open/close animation and drag handling of a [FinnSidebarSurface]
/// for a screen that is not the chat shell.
///
/// The chat shell keeps its own copy of this logic inside its state; a new
/// screen builds on this instead of repeating it. `0` is closed and `1` open;
/// the value is read without an easing curve so a drag tracks the finger
/// one-to-one, and releases settle with a critically damped spring.
class FinnSidebarMotion {
  FinnSidebarMotion({required TickerProvider vsync, required this.onChanged})
      : controller = AnimationController(vsync: vsync);

  final AnimationController controller;

  /// Called when [open] or [everOpened] changes, so the host can `setState`.
  final VoidCallback onChanged;

  bool open = false;

  /// The panel is only built once it has been opened, so a first-run screen
  /// never pays for it.
  bool everOpened = false;

  double _dragBase = 0;

  /// Fraction of the panel the finger must travel for a release to count.
  static const double commitFraction = .18;

  /// Flick speed that opens or closes regardless of distance travelled.
  static const double flickVelocity = 320;

  void dragStart(DragStartDetails details) {
    _dragBase = controller.value;
    controller.stop();
    if (!everOpened) {
      everOpened = true;
      onChanged();
    }
  }

  void dragUpdate(DragUpdateDetails details, double travel) {
    if (travel <= 0) return;
    controller.value =
        (_dragBase + details.primaryDelta! / travel).clamp(0.0, 1.0);
  }

  void dragEnd(BuildContext context, DragEndDetails details, double travel) {
    if (travel <= 0) {
      set(context, !open);
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final travelled = controller.value - _dragBase;
    final opening = velocity.abs() > flickVelocity
        ? velocity > 0
        : (_dragBase > .5
            ? travelled > -commitFraction
            : travelled > commitFraction);
    set(context, opening, velocity: velocity / travel);
  }

  /// Opens or closes the panel. [velocity] is the release speed of a drag in
  /// panels per second (positive opens).
  void set(BuildContext context, bool value, {double velocity = 0}) {
    if (open != value) {
      HapticFeedback.selectionClick();
      open = value;
      if (value) everOpened = true;
      onChanged();
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = value ? 1 : 0;
      return;
    }
    controller.animateWith(
      ScrollSpringSimulation(
        SpringDescription.withDampingRatio(mass: 1, stiffness: 550, ratio: 1),
        controller.value,
        value ? 1 : 0,
        velocity,
        tolerance: const Tolerance(distance: .002, velocity: .05),
      ),
    );
  }

  /// Closes the panel without animating: a page already covers it.
  void snapClosed() {
    if (!open && controller.value == 0) return;
    controller.stop();
    controller.value = 0;
    open = false;
    onChanged();
  }

  void dispose() => controller.dispose();
}

/// The single control that opens the sidebar and closes it again.
///
/// One button, not two: the design's hamburger and its "X" are the same 25-unit
/// grid of 2px round strokes, so the glyph is interpolated between them by
/// [progress] rather than swapped. 0 is the menu, 1 is the close.
class FinnSidebarToggleButton extends StatelessWidget {
  const FinnSidebarToggleButton({
    super.key,
    required this.progress,
    required this.onToggle,
    required this.openTooltip,
    required this.closeTooltip,
  });

  /// Size of the circular control.
  static const double dimension = 50;

  /// Glyph edge length, matching the design's icon at both ends.
  static const double _glyph = 25;

  /// 0 = menu, 1 = close. Driven by the sidebar's own animation, so a tap and
  /// a drag both move it.
  final double progress;
  final VoidCallback onToggle;
  final String openTooltip;
  final String closeTooltip;

  @override
  Widget build(BuildContext context) {
    final open = progress < .5;
    final tooltip = open ? openTooltip : closeTooltip;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        onTap: onToggle,
        excludeSemantics: true,
        child: FluxPressScale(
          child: Material(
            color: FluxColors.controlOf(context),
            shape: const CircleBorder(),
            child: SizedBox.square(
              key: const ValueKey('home-menu-button'),
              dimension: dimension,
              child: InkWell(
                onTap: onToggle,
                customBorder: const CircleBorder(),
                child: Center(
                  child: SizedBox.square(
                    dimension: _glyph,
                    child: CustomPaint(
                      painter: _SidebarGlyphPainter(
                        progress: progress,
                        color: FluxColors.inkOf(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Interpolates the hamburger/close pair in [FigmaAssets.appMenu] and
/// [FigmaAssets.appClose].
///
/// Both icons are 2px round-capped strokes on the same 25-unit grid, so each
/// pair of endpoints lerps point-for-point: the middle rule rotates into one
/// diagonal of the cross while the top and bottom rules pull inward and rotate
/// onto the other. Painting them keeps the two states one continuous motion
/// rather than a cross-fade between two separate assets.
class _SidebarGlyphPainter extends CustomPainter {
  const _SidebarGlyphPainter({required this.progress, required this.color});

  /// 0 = menu, 1 = close.
  final double progress;
  final Color color;

  /// Half-length of the middle rule: the design's widest stroke.
  static const double _fullHalfLength = 8.33;

  /// Half-length of the menu's shorter top and bottom rules.
  static const double _shortHalfLength = 5.21;

  /// Distance of the menu's top and bottom rules from the glyph centre, and the
  /// span the cross's endpoints settle on.
  static const double _offset = 7.29;

  /// Half of the close cross's span, matching the design's 6.25 inset.
  static const double _crossHalfSpan = 6.25;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final t = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    // Distance the outer rules still sit from the centre; at t=1 both have
    // collapsed onto it, which is what lets them become the two diagonals.
    final ruleOffset = _offset * (1 - t);

    // The middle rule turns one way, the outer pair the other, so the two
    // diagonals of the cross cross rather than lying parallel.
    void drawRule({
      required double verticalOffset,
      required double angle,
      required double halfLength,
      required double alpha,
    }) {
      canvas.save();
      canvas.translate(centre.dx, centre.dy + verticalOffset);
      canvas.rotate(angle);
      canvas.drawLine(
        Offset(-halfLength, 0),
        Offset(halfLength, 0),
        stroke..color = color.withValues(alpha: alpha),
      );
      canvas.restore();
    }

    drawRule(
      verticalOffset: 0,
      angle: -math.pi / 4 * t,
      halfLength: _fullHalfLength + (_crossHalfSpan - _fullHalfLength) * t,
      alpha: 1,
    );
    for (final sign in const <double>[-1, 1]) {
      drawRule(
        verticalOffset: sign * ruleOffset,
        angle: math.pi / 4 * t,
        halfLength: _shortHalfLength + (_crossHalfSpan - _shortHalfLength) * t,
        // The design draws the outer rules at half opacity; the cross does
        // not, so they gain their opacity as they turn.
        alpha: 0.5 + 0.5 * t,
      );
    }
  }

  @override
  bool shouldRepaint(_SidebarGlyphPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
