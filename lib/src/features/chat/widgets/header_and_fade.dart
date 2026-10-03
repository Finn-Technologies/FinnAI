part of '../home_shell.dart';

/// The screen's top row: the conversation title beside the control slot, and
/// the new-chat control on the right while a conversation is on screen.
///
/// The menu/close control itself is *not* here — it is drawn by the sidebar
/// overlay so it can stay above the scrim and morph as the panel opens. This
/// row keeps its [menuSlotWidth] so the title does not shift under it.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    this.title,
    this.onNewChat,
    this.onTitleTap,
  });

  /// Width the menu/close control occupies at the row's start.
  static const double menuSlotWidth = _SidebarToggleButton.dimension;

  /// Conversation title; null on the empty screen and while listening.
  final String? title;

  /// Starts a new conversation; null hides the control.
  final VoidCallback? onNewChat;

  /// Opens the chat's options; null leaves the title inert.
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          const SizedBox(width: menuSlotWidth),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(width: 20),
            Expanded(
              child: Semantics(
                button: onTitleTap != null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTitleTap,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (onNewChat != null)
            Semantics(
              button: true,
              label: L10n.of(context).chatNewChat,
              onTap: onNewChat,
              excludeSemantics: true,
              child: FluxPressScale(
                child: Material(
                  color: FluxColors.controlOf(context),
                  shape: const CircleBorder(),
                  child: SizedBox.square(
                    key: const ValueKey('home-new-chat-button'),
                    dimension: 50,
                    child: InkWell(
                      onTap: onNewChat,
                      customBorder: const CircleBorder(),
                      child: const Center(
                        child: FigmaSvg(
                          asset: FigmaAssets.appNewChat,
                          width: 25,
                          height: 25,
                        ),
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

/// The single control that opens the sidebar and closes it again.
///
/// One button, not two: the design's hamburger and its "X" are the same 25-unit
/// grid of 2px round strokes, so the glyph is interpolated between them by
/// [progress] rather than swapped. 0 is the menu, 1 is the close.
class _SidebarToggleButton extends StatelessWidget {
  const _SidebarToggleButton({
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

/// Height of the chat's top scroll-fade band, in logical pixels.
///
/// Declared once because the gradient's opaque stretch is a fraction of it:
/// the band and the gradient stops have to stay in step.
const double _chatTopFadeHeight = 210;

/// Depth of the fully opaque stretch at the top of the fade band.
///
/// The brand row must stay readable while messages scroll beneath it, so the
/// fade is opaque wherever the header can sit. `_HomeHeader` is 50 tall at
/// `top: 71 * sy`, and `sy` is clamped to 1.08, so its bottom edge reaches
/// (71 + 50) * 1.08 ≈ 130.7.
const double _chatTopFadeOpaqueDepth = 134;

/// A static soft-edge fade that sits over the scrolling chat list so messages
/// appear to slide beneath the header at the top and fade into the very bottom
/// edge of the screen below the composer. It replaces the old progressive
/// backdrop blur with a plain gradient — effectively free per scroll frame.
/// The header and composer are drawn above these fades in the shell Stack, so
/// they stay crisp and tappable.
///
/// The top band is *fully* opaque across the brand row and only then ramps to
/// transparent. At anything less than opaque, scrolled message text stays
/// legible straight through the app title, which reads as a rendering fault
/// rather than as depth. The bottom band has no content drawn over it, so it
/// keeps the softer profile that lets the last row dissolve into the composer.
class _ChatEdgeFade extends StatelessWidget {
  const _ChatEdgeFade({super.key, required this.top});

  /// True for the fade under the header at the top of the screen, false for
  /// the fade hugging the very bottom edge of the screen.
  final bool top;

  @override
  Widget build(BuildContext context) {
    // The fade has to end on the same colour as the surface it sits on. The chat
    // canvas is tileOf (#18181C in dark), not canvasOf (#101014), so fading to
    // darkCanvas left a visible dark band along the header and footer.
    final color = FluxColors.tileOf(context);
    final stops = top
        ? const <double>[
            0.0,
            _chatTopFadeOpaqueDepth / _chatTopFadeHeight,
            0.80,
            1.0,
          ]
        : const <double>[0.0, 0.35, 0.7, 1.0];
    final colors = top
        ? <Color>[
            // Opaque across the brand row; the ramp starts below it.
            color,
            color,
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.0),
          ]
        : <Color>[
            color.withValues(alpha: 0.93),
            color.withValues(alpha: 0.64),
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.0),
          ];
    return DecoratedBox(
      decoration: BoxDecoration(
        // Progressive: mostly transparent across the band and easing smoothly
        // to near-opaque only at the screen edge, so there is no hard line.
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          stops: stops,
          colors: colors,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Cold-start welcome shown when the active conversation has no messages yet:
/// the greeting alone, centred on the screen — no chips, no brand mark.
class _ConversationEmpty extends StatelessWidget {
  const _ConversationEmpty({required this.greeting});

  /// The design greets a listening session differently from a typed one.
  final String greeting;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Text(
            greeting,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'InstrumentSans',
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
}
