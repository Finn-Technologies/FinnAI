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

extension _HomeShellSidebarSurface on _HomeShellState {
  /// The sidebar and the home screen as one surface: a panel the home screen
  /// slides off on a phone, docked beside it on a wide window.
  Widget _sidebarSurface({
    required BoxConstraints constraints,
    required Widget homeLayer,
    required double contentLeft,
    required double sy,
    required bool docked,
  }) {
    // The panel stays put and the home screen slides aside to reveal
    // it; the design's home sheet starts 322 of 420 points across.
    final sidebarWidth = FinnLayout.sidebarWidth(constraints.maxWidth);
    final sidebarLayer = !_sidebarEverOpened && !docked
        ? const SizedBox.shrink()
        : RepaintBoundary(
            child: SizedBox(
              width: sidebarWidth,
              child: _Sidebar(
                onNewConversation: _newConversation,
                onConversation: _activateConversation,
                conversations: _conversations.conversations,
                activeConversationId: _conversations.active?.id,
                onCreations: _openCreations,
                onYou: _openYou,
                onFlows: _openSkills,
                onActions: _openDeviceActionsFromSidebar,
                onSettings: _openSettings,
              ),
            ),
          );
    return DesktopShortcuts(
      onNew: _newConversation,
      onToggleSidebar: () => _setSidebar(!_sidebar),
      onSettings: _openSettings,
      child: AnimatedBuilder(
        animation: _sidebarController,
        builder: (context, _) => FinnSidebarSurface(
          docked: docked,
          home: homeLayer,
          sidebar: sidebarLayer,
          sidebarWidth: sidebarWidth,
          progress: _sidebarController.value,
          sidebarOpen: _sidebar,
          toggleLeft: contentLeft,
          toggleTop: 70 * sy,
          onToggle: () => _setSidebar(!_sidebar),
          onDragStart: _sidebarDragStart,
          onDragUpdate: (d) => _sidebarDragUpdate(d, sidebarWidth),
          onDragEnd: (d) => _sidebarDragEnd(d, sidebarWidth),
        ),
      ),
    );
  }
}
