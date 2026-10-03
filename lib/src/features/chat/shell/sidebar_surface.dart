// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

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
