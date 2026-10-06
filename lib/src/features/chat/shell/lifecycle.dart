// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

extension _HomeShellLifecycle on _HomeShellState {
  /// With a keyboard in front of them the user expects to type at once, as in
  /// any chat app, and the window shortcuts (Ctrl+N, Ctrl+B) only work while
  /// focus is somewhere in the shell. So the composer takes focus back whenever
  /// nothing else holds it: at start, after a reply (the field is disabled
  /// while a turn is prepared, which drops its focus) and after a page closes.
  /// A phone keeps its keyboard down until the field is tapped.
  void _focusComposerOnDesktop() {
    if (!isDesktop) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _sidebar ||
          _composer.text.isNotEmpty && _focusNode.hasFocus) {
        return;
      }
      if (ModalRoute.of(context)?.isCurrent != true) return;
      final holder = FocusManager.instance.primaryFocus?.context;
      // Leave a text field the user is typing in (rename, edit) alone.
      if (holder?.findAncestorWidgetOfExactType<EditableText>() != null) return;
      _focusNode.requestFocus();
    });
  }

  Future<void> _checkPendingProcessText() async {
    try {
      final text =
          await _HomeShellState._processTextChannel.invokeMethod<String>(
        'getPendingText',
      );
      if (text != null && text.trim().isNotEmpty) {
        _handleIncomingProcessText(text.trim());
      }
    } catch (_) {}
  }

  void _handleIncomingProcessText(String text) {
    if (!mounted) return;
    _newConversation();
    _composer.text = selectedTextPrompt(text);
    unawaited(_send());
  }

  void _stopVoiceForLifecycle() {
    if (!_voice.active && !_voice.live) return;
    unawaited(_voice.reset());
  }

  Future<void> _initializeStores() async {
    final started = DateTime.now();
    // This future is what unlocks the composer, so a store that throws must
    // not be allowed to leave the field permanently disabled with no
    // explanation: each initializer is isolated, the gate is always released,
    // and a failure is reported instead of swallowed.
    final failed = <String>[];
    Future<void> guard(String name, Future<void> Function() initialize) async {
      try {
        await initialize();
      } catch (error, stack) {
        failed.add(name);
        debugPrint('FINN_STORES_ERROR $name $error');
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'finn stores',
            context: ErrorDescription('initializing the $name store'),
          ),
        );
      }
    }

    await Future.wait([
      guard('conversations', _conversations.initialize),
      guard('you', YouProfileStore.instance.initialize),
      guard('you-memory', YouMemoryStore.instance.initialize),
      guard('flows', FlowsStore.instance.initialize),
      guard('voice', VoiceSettingsStore.instance.initialize),
      guard('consent', ContextConsentStore.instance.initialize),
    ]);
    debugPrint(
      'FINN_STORES_READY ms=${DateTime.now().difference(started).inMilliseconds} '
      'failed=${failed.isEmpty ? 'none' : failed.join(',')}',
    );
    if (!mounted) return;
    // Every cold start lands on the welcome slate instead of dropping the
    // user back into the last conversation. History stays in the sidebar;
    // tapping a past chat re-activates it.
    _conversations.clearActive();
    setState(() {
      _storesReady = true;
      // Chatting still works when the history file cannot be opened — replies
      // just live in memory — but the user has to be told that.
      _historyUnavailable =
          failed.contains('conversations') || _conversations.storageError;
    });
    _focusComposerOnDesktop();
    unawaited(_flowsReady());
    _schedulePrewarm();
  }

  void _releaseMemoryWhenIdle() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (_inference.isGeneratingReply) {
      _memoryReleaseTimer = Timer(
        const Duration(seconds: 10),
        _releaseMemoryWhenIdle,
      );
      return;
    }
    unawaited(_inference.releaseMemory());
  }

  void _conversationChanged() {
    if (mounted) setState(() {});
  }

  void _onChatScroll() {
    if (!_chatScrollController.hasClients) return;
    final position = _chatScrollController.position;
    _chatScrolledAway.value = position.hasContentDimensions &&
        position.pixels > _HomeShellState._chatBottomThreshold;
  }

  void _returnToLatest() {
    if (!_chatScrollController.hasClients || !_chatScrolledAway.value) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _chatScrollController.jumpTo(0);
    } else {
      unawaited(
        _chatScrollController.animateTo(
          0,
          duration: FluxMotion.modalDuration,
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _schedulePrewarm() {
    _prewarmTimer?.cancel();
    final profile = _inference.deviceProfile;
    if (profile != null && DeviceProfiler.isLowEnd(profile)) {
      return;
    }
    _prewarmTimer = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_inference.prewarm()),
    );
  }

  String _generationSignature() {
    final job = _generation.job;
    return '${job?.generationId}|${job?.state.name}|${job?.sources.length}|'
        '${_generation.toolActivities.length}|${_generation.busy}';
  }

  void _generationChanged() {
    if (!mounted) return;
    final signature = _generationSignature();
    if (signature != _lastGenerationSignature) {
      _lastGenerationSignature = signature;
      setState(() {});
      if (!_generation.busy) _focusComposerOnDesktop();
    }
    _pumpVoiceReply();
    final trace = _generation.activeTrace;
    if (trace?.hasUiPaintScheduled == true &&
        trace?.hasUiPaintCompleted == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generation.markFirstVisiblePaintCompleted();
      });
    }
  }

  void _warnIfMultimodalMissing(String path) {
    // Fire-and-forget check: if user attached an image but mmproj is absent,
    // surface a toast immediately so expectation is set.
    if (!_isImageAttachmentPath(path)) return;
    // Best-effort: FinnInference mirrors FinnAccelerator; check via inference
    // without importing engine internals. Use a microtask to avoid build-time.
    Future.microtask(() async {
      try {
        // FinnAccelerator exposes multimodalLoaded via engine; check via isMmprojInstalled
        // as a lightweight file probe does not need the engine to be warm.
        final hasMmproj = await _inference.hasMmprojFile();
        if (!hasMmproj && mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(L10n.of(context).chatImageAnalysisUnavailable),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      } catch (_) {}
    });
  }
}
