// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

/// The screen behind the sidebar panel, the scrim, the panel itself and the one
/// control that toggles it — the whole open/close surface, kept out of
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

  /// The chat screen, shifted and rounded away as the panel opens.
  final Widget home;

  /// The panel. Empty until it has been opened once, so a first-run install
  /// never builds the conversation grid.
  final Widget sidebar;

  /// Width of the panel, and so the distance the home screen slides by.
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
          ExcludeSemantics(
            excluding: sidebarOpen,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                // The design outlines the home sheet with a hairline, so the
                // sliver beside the panel reads as an edge rather than as the
                // panel simply stopping. It fades in with the sheet's rounding.
                border: Border.all(
                  color: FluxColors.panelEdgeOf(context).withValues(
                    alpha: motion,
                  ),
                  width: 1,
                ),
                boxShadow: [
                  if (motion > 0)
                    BoxShadow(
                      // The only shadow in the app that had no dark branch at
                      // all: 10% black on a black canvas left the home sheet
                      // with no lift, so the sidebar looked like a flat wipe.
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
                child: Transform.translate(
                  // The panel covers three quarters of the screen; the home
                  // screen stays visible beside it, rounded and lifted, as in
                  // the design.
                  offset: Offset(sidebarWidth * motion, 0),
                  child: home,
                ),
              ),
            ),
          ),
          IgnorePointer(
            ignoring: !sidebarOpen,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onToggle(),
              child: const SizedBox.expand(),
            ),
          ),
          IgnorePointer(
            ignoring: !sidebarOpen,
            child: ExcludeSemantics(
              excluding: !sidebarOpen,
              child: FractionalTranslation(
                translation: Offset(-1 + motion, 0),
                child: sidebar,
              ),
            ),
          ),
          // Above the scrim and the panel, so it stays reachable in both states.
          // It rides the home screen's own travel: the design shows the
          // control sliding off to the right with the surface it belongs to,
          // rather than staying put over the incoming panel.
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
  }

  void _sidebarDragUpdate(DragUpdateDetails details, double travel) {
    if (travel <= 0) return;
    // Dragging right opens: the panel comes from the left edge, so it follows
    // the finger in the same direction rather than the opposite one.
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
    final opening = velocity.abs() > _flickVelocity
        ? velocity > 0
        : travelled > _commitFraction;
    _setSidebar(opening);
  }
}
