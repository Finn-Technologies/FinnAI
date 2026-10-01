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

  Future<void> _openCreations() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(FinnPageRoute<void>(child: const CreationsPage()));
  }

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

  Future<void> _openYou() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      FinnPageRoute<void>(
        child: YouPage(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  Future<void> _openSkills({bool startNew = false}) async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      FinnPageRoute<void>(
        child: FlowsPage(
          onBack: () => Navigator.of(context).pop(),
          runner: _flowRunner,
          scheduler: _flowScheduler,
          onOpenResult: _openFlowResult,
          startNew: startNew,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      FinnPageRoute<void>(
        child: SettingsPage(
          onBack: () => Navigator.of(context).pop(),
          onOpenActions: _openDeviceActions,
          onOpenYou: _openYou,
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      FinnPageRoute<void>(
        child: FinnSearchPage(
          onOpenChat: (id) {
            Navigator.of(context).pop();
            _activateConversation(id);
          },
          onOpenCreations: () {
            Navigator.of(context).pop();
            unawaited(_openCreations());
          },
          onOpenYou: () {
            Navigator.of(context).pop();
            unawaited(_openYou());
          },
        ),
      ),
    );
  }

  Future<void> _openDeviceActions() async {
    if (!mounted) return;
    Navigator.of(context).push(
      FinnPageRoute<void>(
        child: DeviceActionsPage(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  Future<void> _openDeviceActionsFromSidebar() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    await _openDeviceActions();
  }

  void _setSidebar(bool open) {
    if (_sidebar == open) return;
    HapticFeedback.selectionClick();
    setState(() {
      _sidebar = open;
      if (open) _sidebarEverOpened = true;
    });
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _sidebarController.value = open ? 1 : 0;
    } else if (open) {
      _sidebarController.forward();
    } else {
      _sidebarController.reverse();
    }
  }

  Future<void> _closeSidebarForNavigation() async {
    if (!_sidebar) return;
    setState(() {
      _sidebar = false;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _sidebarController.value = 0;
    } else {
      await _sidebarController.reverse();
    }
  }
}
