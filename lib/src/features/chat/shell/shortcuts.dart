// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

/// Pinned launcher shortcuts: a mini app on the home screen opens straight
/// into itself, not into the chat.
extension _HomeShellShortcuts on _HomeShellState {
  void _listenForShortcuts() {
    final service = HomeScreenService.instance;
    service.listenForShortcuts((id) => unawaited(_openShortcut(id)));
    // A cold start through a shortcut leaves the id waiting for us.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = await service.takeLaunchCreation();
      if (id != null && mounted) await _openShortcut(id);
    });
  }

  void _stopListeningForShortcuts() =>
      HomeScreenService.instance.stopListeningForShortcuts();

  Future<void> _openShortcut(String creationId) async {
    if (!mounted) return;
    final opened = await CreationLauncher.open(context, creationId);
    // A creation that no longer exists (deleted since it was pinned) lands on
    // the gallery rather than on a screen that explains nothing.
    if (!opened && mounted) unawaited(_openCreations());
  }
}
