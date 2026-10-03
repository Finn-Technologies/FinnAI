// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

/// The fixed sidebar panel, the home screen that slides over it, the scrim and
/// the one control that toggles it — the whole open/close surface, kept out of
/// `home_shell.dart` so that file stays inside its size budget.
///
/// The menu/close control is drawn *here* rather than inside [home], because
/// [home] slides aside and rounds away as the panel opens. It morphs from the
/// hamburger to the cross as [progress] moves, so it reads as one control
/// changing state instead of two buttons trading places.
class _SidebarSurface extends StatelessWidget {
  const _SidebarSurface({
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
  });

  /// The chat screen, which slides aside and rounds as the panel is uncovered.
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
                            // branch at all: 10% black on a black canvas left
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
                      // layer instead of repainting the whole chat screen
                      // every frame.
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
            child: _SidebarToggleButton(
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

/// Drives the panel from a horizontal drag, so the surface follows the finger
/// and settles open or closed on release.
extension _HomeShellSidebarDrag on _HomeShellState {
  /// How far the finger must travel, as a fraction of the panel, before a
  /// release counts as "open". Past this the panel opens however slow the
  /// flick; short of it, a flick's velocity decides.
  static const double _commitFraction = .18;

  /// Flick speed that opens or closes regardless of distance travelled.
  static const double _flickVelocity = 320;

  void _sidebarDragStart(DragStartDetails details) {
    _sidebarDragBase = _sidebarController.value;
    _sidebarController.stop();
    // The panel is built lazily on the first open; a drag that starts that
    // open has to find it already there, or it pops in only on release.
    if (!_sidebarEverOpened) setState(() => _sidebarEverOpened = true);
  }

  void _sidebarDragUpdate(DragUpdateDetails details, double travel) {
    if (travel <= 0) return;
    // Dragging right opens: the panel is uncovered from the left edge, so the
    // sheet follows the finger in the same direction.
    _sidebarController.value =
        (_sidebarDragBase + details.primaryDelta! / travel).clamp(0.0, 1.0);
  }

  void _sidebarDragEnd(DragEndDetails details, double travel) {
    if (travel <= 0) {
      _setSidebar(!_sidebar);
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final travelled = _sidebarController.value - _sidebarDragBase;
    // A positive velocity is a rightward flick, which opens.
    // From closed the finger must travel the commit distance to open; from open
    // it must travel that far back to close, so a nudge never flips the state.
    final opening = velocity.abs() > _flickVelocity
        ? velocity > 0
        : (_sidebarDragBase > .5
            ? travelled > -_commitFraction
            : travelled > _commitFraction);
    // Hand the finger's speed on to the spring so the sheet keeps its
    // momentum instead of restarting from rest.
    _setSidebar(opening, velocity: velocity / travel);
  }
}
