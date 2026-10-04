// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

extension _HomeShellNavigation on _HomeShellState {
  void _stopReply() {
    HapticFeedback.mediumImpact();
    if (_preparing) {
      setState(() => _preparing = false);
      debugPrint('FINN_SEND cancelled during preparing');
    }
    unawaited(_voice.interrupt());
    unawaited(_generation.stop());
  }

  void _activateConversation(String id) {
    unawaited(_generation.flushActive());
    _conversations.activate(id);
    _setSidebar(false);
    setState(() {});
  }

  void _newConversation() {
    unawaited(_generation.flushActive());
    // Compose just shows the blank slate — no conversation is created until
    // the user actually sends a first message.
    _conversations.clearActive();
    _setSidebar(false);
    setState(() {});
  }

  /// Pushes [page] from a sidebar destination.
  ///
  /// The page is pushed at once and the panel closes *behind* it when the push
  /// has settled, so the move is one motion from the panel to the page. Closing
  /// the panel first would slide the chat back into view for a moment and only
  /// then open the page, which read as two animations.
  Future<void> _pushFromSidebar(Widget page) {
    if (!mounted) return Future.value();
    return Navigator.of(context)
        .push(
          FinnPageRoute<void>(
            child: page,
            onSettled: _dismissSidebarBehindPage,
          ),
        )
        .whenComplete(_focusComposerOnDesktop);
  }

  /// Closes the panel without animating: a page already covers it.
  void _dismissSidebarBehindPage() {
    if (!mounted || (!_sidebar && _sidebarController.value == 0)) return;
    _sidebarController.stop();
    _sidebarController.value = 0;
    setState(() => _sidebar = false);
  }

  Future<void> _openCreations() => _pushFromSidebar(const CreationsPage());

  /// Starts building something from the plus menu.
  void _startCreate(String kind) {
    _closeAttachmentMenu();
    if (kind == 'flow') {
      unawaited(_openSkills(startNew: true));
      return;
    }
    final creation = switch (kind) {
      'widget' => CreationKind.widget,
      'presentation' => CreationKind.presentation,
      _ => CreationKind.app,
    };
    Navigator.of(context).push(
      FinnPageRoute<void>(child: CreationsPage(initialKind: creation)),
    );
  }

  Future<void> _openYou() => _pushFromSidebar(
        YouPage(onBack: () => Navigator.of(context).pop()),
      );

  Future<void> _openSkills({bool startNew = false}) => _pushFromSidebar(
        FlowsPage(
          onBack: () => Navigator.of(context).pop(),
          runner: _flows.runner,
          scheduler: _flows.scheduler,
          onOpenResult: _openFlowResult,
          startNew: startNew,
        ),
      );

  Future<void> _openSettings() => _pushFromSidebar(
        SettingsPage(
          onBack: () => Navigator.of(context).pop(),
          onOpenActions: _openDeviceActions,
          onOpenYou: _openYou,
        ),
      );

  Future<void> _openDeviceActions() {
    if (!mounted) return Future.value();
    return Navigator.of(context).push(
      FinnPageRoute<void>(
        child: DeviceActionsPage(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  Future<void> _openDeviceActionsFromSidebar() => _pushFromSidebar(
        DeviceActionsPage(onBack: () => Navigator.of(context).pop()),
      );

  /// Opens or closes the panel. [velocity] is the release speed of a drag in
  /// panels per second (positive opens), so a flick carries on at its own pace.
  void _setSidebar(bool open, {double velocity = 0}) {
    if (_sidebar != open) {
      HapticFeedback.selectionClick();
      setState(() {
        _sidebar = open;
        if (open) _sidebarEverOpened = true;
      });
    }
    _settleSidebar(open, velocity: velocity);
  }

  /// Settles the panel with a critically damped spring: no overshoot, and the
  /// same motion whether it was tapped or released from a drag mid-way.
  TickerFuture _settleSidebar(bool open, {double velocity = 0}) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _sidebarController.value = open ? 1 : 0;
      return TickerFuture.complete();
    }
    // ScrollSpringSimulation lands exactly on the target, so the sheet never
    // rests a fraction of a pixel short of open or closed.
    return _sidebarController.animateWith(
      ScrollSpringSimulation(
        SpringDescription.withDampingRatio(
          mass: 1,
          stiffness: 550,
          ratio: 1,
        ),
        _sidebarController.value,
        open ? 1 : 0,
        velocity,
        tolerance: const Tolerance(distance: .002, velocity: .05),
      ),
    );
  }
}
