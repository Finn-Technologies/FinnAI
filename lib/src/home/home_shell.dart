import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/banner_ad_widget.dart';
import '../conversations/conversation_store.dart';
import '../creations/creations_page.dart';
import '../generation/chat_generation_controller.dart';
import '../inference/bonsai_inference.dart';
import '../inference/residency_policy.dart';
import '../privacy/ad_consent_service.dart';
import '../reporting/report_dialog.dart';
import '../settings/settings_page.dart';
import '../skills/skills_page.dart';
import '../skills/skills_store.dart';
import '../theme/flux_theme.dart';
import '../you/you_page.dart';
import '../you/you_profile_store.dart';
import '../widgets/ambient_background.dart';
import '../widgets/flux_controls.dart';
import '../widgets/safe_markdown_text.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.generationController,
    this.conversationStore,
    this.inference,
    this.initializeServices = true,
  });

  final ChatGenerationController? generationController;
  final ConversationStore? conversationStore;
  final BonsaiInference? inference;
  @visibleForTesting
  final bool initializeServices;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _focusNode = FocusNode();
  late final _inference = widget.inference ?? BonsaiInference.instance;
  late final _conversations =
      widget.conversationStore ?? ConversationStore.instance;
  late final _generation =
      widget.generationController ?? ChatGenerationController.instance;
  Timer? _memoryReleaseTimer;
  Timer? _prewarmTimer;
  bool _sidebar = false;
  bool _sidebarEverOpened = false;
  bool _sidebarAdVisible = false;
  bool _preparing = false;
  late bool _storesReady = !widget.initializeServices;
  late final AnimationController _sidebarController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    reverseDuration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _sidebarAnimation = CurvedAnimation(
    parent: _sidebarController,
    curve: Curves.easeInOutCubicEmphasized,
    reverseCurve: Curves.easeInCubic,
  );

  bool get _busy => _preparing || _generation.busy;

  @override
  void initState() {
    super.initState();
    _generation.addListener(_generationChanged);
    _conversations.addListener(_conversationChanged);
    WidgetsBinding.instance.addObserver(this);
    if (widget.initializeServices) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initializeStores());
        unawaited(AdConsentService.instance.initializeConsentAndAds());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final residencyAction = residencyActionFor(switch (state) {
      AppLifecycleState.detached => ResidencyLifecycleEvent.detached,
      AppLifecycleState.paused => ResidencyLifecycleEvent.paused,
      AppLifecycleState.resumed => ResidencyLifecycleEvent.resumed,
      _ => ResidencyLifecycleEvent.inactive,
    });
    if (residencyAction == ResidencyLifecycleAction.releaseNow) {
      _memoryReleaseTimer?.cancel();
      _prewarmTimer?.cancel();
      unawaited(_generation.flushActive());
      unawaited(_inference.releaseMemory());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _prewarmTimer?.cancel();
      unawaited(_generation.flushActive());
      if (residencyAction !=
          ResidencyLifecycleAction.scheduleBackgroundRelease) {
        return;
      }
      _memoryReleaseTimer?.cancel();
      final profile = _inference.deviceProfile;
      final constrained =
          profile?.lowMemory == true ||
          (profile?.availableRamBytes ?? 1 << 40) < 1800 * 1024 * 1024;
      _memoryReleaseTimer = Timer(
        Duration(seconds: constrained ? 5 : 35),
        _releaseMemoryWhenIdle,
      );
    } else if (state == AppLifecycleState.resumed) {
      _memoryReleaseTimer?.cancel();
      _schedulePrewarm();
    }
  }

  @override
  void didHaveMemoryPressure() {
    _prewarmTimer?.cancel();
    _memoryReleaseTimer?.cancel();
    if (!_generation.busy) {
      unawaited(_inference.handleMemoryPressure());
    }
  }

  Future<void> _initializeStores() async {
    await Future.wait([
      _conversations.initialize(),
      YouProfileStore.instance.initialize(),
      SkillsStore.instance.initialize(),
    ]);
    if (!mounted) return;
    setState(() => _storesReady = true);
    _schedulePrewarm();
  }

  void _releaseMemoryWhenIdle() {
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

  @override
  void dispose() {
    _generation.removeListener(_generationChanged);
    _conversations.removeListener(_conversationChanged);
    WidgetsBinding.instance.removeObserver(this);
    _memoryReleaseTimer?.cancel();
    _prewarmTimer?.cancel();
    _sidebarController.dispose();
    unawaited(_generation.flushActive());
    _composer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _schedulePrewarm() {
    _prewarmTimer?.cancel();
    _prewarmTimer = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_inference.prewarm()),
    );
  }

  void _generationChanged() {
    if (!mounted) return;
    setState(() {});
    final trace = _generation.activeTrace;
    if (trace?.hasUiPaintScheduled == true &&
        trace?.hasUiPaintCompleted == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generation.markFirstVisiblePaintCompleted();
      });
    }
  }

  Future<void> _send() async {
    final value = _composer.text.trim();
    if (value.isEmpty || _busy) return;
    if (_inference.isGeneratingReply) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Finn AI is finishing another local task.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    final timing = _generation.createTtftTrace(
      _conversations.active?.id ?? 'new-conversation',
    );
    _prewarmTimer?.cancel();

    setState(() => _preparing = true);
    await Future.wait([
      _conversations.initialize(),
      YouProfileStore.instance.initialize(),
      SkillsStore.instance.initialize(),
    ]);
    if (!mounted) return;
    _storesReady = true;
    final systemContext = [
      YouProfileStore.instance.promptContext,
      SkillsStore.instance.promptContextFor(value),
    ].where((item) => item.trim().isNotEmpty).join('\n\n');
    final missing = <BonsaiModel>[];
    for (final model in _inference.requiredModels) {
      if (!await _inference.isInstalled(model)) missing.add(model);
    }
    if (missing.isNotEmpty && mounted) {
      final bytes = missing.fold<int>(
        0,
        (total, model) => total + model.expectedBytes,
      );
      final size = bytes >= 1000 * 1000 * 1000
          ? '${(bytes / 1000 / 1000 / 1000).toStringAsFixed(2)} GB'
          : '${(bytes / 1000 / 1000).round()} MB';
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: FluxColors.cardOf(context),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: Text(
            missing.length == 1
                ? 'Download the local model?'
                : 'Download the adaptive model set?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w400),
          ),
          content: Text(
            '$size downloads once. Finn AI will automatically use the '
            'smallest model capable of answering each request, entirely on '
            'this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Download'),
            ),
          ],
        ),
      );
      if (accepted != true) {
        if (mounted) setState(() => _preparing = false);
        return;
      }
    }
    if (mounted) setState(() => _preparing = false);
    if (!mounted) return;

    final profile = _inference.deviceProfile;
    final thermal = thermalPolicyForStatus(
      profile?.thermalStatus,
      profile?.thermalHeadroom,
    );
    if (thermal.message != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(thermal.message!),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    final conversation = _conversations.active ?? _conversations.startNew();
    final history = [
      for (final message in conversation.messages)
        if (message.text.trim().isNotEmpty)
          LocalChatTurn(role: message.role.name, content: message.text),
    ];

    _focusNode.unfocus();
    _composer.clear();
    await _generation.start(
      conversationId: conversation.id,
      prompt: value,
      history: history,
      systemContext: systemContext,
      trace: timing,
    );
  }

  Future<void> _continueReply(ConversationMessage assistant) async {
    if (_busy ||
        assistant.status != ConversationMessageStatus.tokenLimited ||
        assistant.continuationCount >= 1) {
      return;
    }
    final conversation = _conversations.active;
    if (conversation == null) return;
    final assistantIndex = conversation.messages.indexWhere(
      (message) => message.id == assistant.id,
    );
    if (assistantIndex <= 0) return;
    final latestUser = conversation.messages
        .take(assistantIndex)
        .toList(growable: false)
        .reversed
        .where((message) => message.role == ConversationRole.user)
        .firstOrNull;
    if (latestUser == null) return;
    final history = [
      for (final message in conversation.messages)
        if (message.text.trim().isNotEmpty)
          LocalChatTurn(role: message.role.name, content: message.text),
    ];
    final systemContext = [
      YouProfileStore.instance.promptContext,
      SkillsStore.instance.promptContextFor(latestUser.text),
    ].where((item) => item.trim().isNotEmpty).join('\n\n');
    await _generation.continueResponse(
      conversationId: conversation.id,
      assistantMessageId: assistant.id,
      originalPrompt: latestUser.text,
      history: history,
      systemContext: systemContext,
    );
  }

  void _stopReply() => unawaited(_generation.stop());

  void _activateConversation(String id) {
    unawaited(_generation.flushActive());
    _conversations.activate(id);
    _setSidebar(false);
    setState(() {});
  }

  void _newConversation() {
    unawaited(_generation.flushActive());
    _conversations.startNew();
    _setSidebar(false);
    setState(() {});
  }

  Future<void> _openCreations() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(_FinnPageRoute(child: const CreationsPage()));
  }

  Future<void> _openYou() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      _FinnPageRoute(child: YouPage(onBack: () => Navigator.of(context).pop())),
    );
  }

  Future<void> _openSkills() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      _FinnPageRoute(
        child: SkillsPage(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  Future<void> _openSettings() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      _FinnSettingsRoute(
        child: SettingsPage(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  void _setSidebar(bool open) {
    if (_sidebar == open) return;
    setState(() {
      _sidebar = open;
      if (open) _sidebarEverOpened = true;
      if (!open) _sidebarAdVisible = false;
    });
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _sidebarController.value = open ? 1 : 0;
      if (open && mounted) setState(() => _sidebarAdVisible = true);
    } else if (open) {
      _sidebarController.forward().whenComplete(() {
        if (mounted && _sidebar && _sidebarController.value == 1) {
          setState(() => _sidebarAdVisible = true);
        }
      });
    } else {
      _sidebarController.reverse();
    }
  }

  Future<void> _closeSidebarForNavigation() async {
    if (!_sidebar) return;
    setState(() {
      _sidebar = false;
      _sidebarAdVisible = false;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _sidebarController.value = 0;
    } else {
      await _sidebarController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sidebar,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _sidebar) _setSidebar(false);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final sy = constraints.maxHeight / 844;
            final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
            final homeLayer = RepaintBoundary(
              child: AmbientBackground(
                intensity: 1,
                child: Stack(
                  children: [
                    Positioned(
                      left: 20,
                      top: 71 * sy,
                      child: _HomeHeader(onMenu: () => _setSidebar(true)),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 125 * sy,
                      bottom: 92 + safeBottom,
                      child: _Conversation(
                        messages: _conversations.active?.messages ?? const [],
                        activeConversationId: _conversations.active?.id,
                        generation: _generation,
                        conversations: _conversations,
                        onStop: _stopReply,
                        onContinue: _continueReply,
                        onOpenConversation: _activateConversation,
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom:
                          safeBottom + (constraints.maxHeight < 650 ? 20 : 30),
                      child: ChatComposer(
                        controller: _composer,
                        focusNode: _focusNode,
                        blocked: _busy || !_storesReady,
                        onSend: _send,
                      ),
                    ),
                  ],
                ),
              ),
            );
            final sidebarLayer = !_sidebarEverOpened
                ? const SizedBox.shrink()
                : RepaintBoundary(
                    child: _Sidebar(
                      onClose: () => _setSidebar(false),
                      onNewConversation: _newConversation,
                      onConversation: _activateConversation,
                      conversations: _conversations.conversations,
                      activeConversationId: _conversations.active?.id,
                      onCreations: _openCreations,
                      onYou: _openYou,
                      onSkills: _openSkills,
                      onSettings: _openSettings,
                      showAd: _sidebarAdVisible && !_generation.busy,
                    ),
                  );
            return AnimatedBuilder(
              animation: _sidebarAnimation,
              builder: (context, _) {
                final motion = _sidebarAnimation.value;
                final scale = 1.0 - (.04 * motion);
                return Stack(
                  children: [
                    ExcludeSemantics(
                      excluding: _sidebar,
                      child: Transform.translate(
                        offset: Offset(constraints.maxWidth * .14 * motion, 0),
                        child: Transform.scale(scale: scale, child: homeLayer),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: !_sidebar,
                      child: GestureDetector(
                        onTap: () => _setSidebar(false),
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: .18 * motion),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: !_sidebar,
                      child: ExcludeSemantics(
                        excluding: !_sidebar,
                        child: FractionalTranslation(
                          translation: Offset(-1 + motion, 0),
                          child: sidebarLayer,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onMenu});
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 158,
    height: 34,
    child: Row(
      children: [
        Tooltip(
          message: 'Open menu',
          child: InkWell(
            onTap: onMenu,
            borderRadius: BorderRadius.circular(17),
            child: const FigmaSvg(
              asset: FigmaAssets.menu,
              width: 34,
              height: 34,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 114,
          height: 24,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Finn AI',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w400),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.messages,
    required this.activeConversationId,
    required this.generation,
    required this.conversations,
    required this.onStop,
    required this.onContinue,
    required this.onOpenConversation,
  });
  final List<ConversationMessage> messages;
  final String? activeConversationId;
  final ChatGenerationController generation;
  final ConversationStore conversations;
  final VoidCallback onStop;
  final ValueChanged<ConversationMessage> onContinue;
  final ValueChanged<String> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final activeJob = generation.activeJob;
    final ownsGeneration =
        activeJob != null && activeJob.conversationId == activeConversationId;
    final terminalJob = generation.job;
    final visibleError =
        terminalJob?.conversationId == activeConversationId &&
            terminalJob?.state == ChatGenerationState.error
        ? terminalJob?.errorMessage
        : null;
    if (messages.isEmpty && activeJob == null && visibleError == null) {
      return const SizedBox();
    }
    final streamingMessageId = ownsGeneration
        ? activeJob.assistantMessageId
        : null;
    final visibleMessages = messages
        .where(
          (message) =>
              message.text.isNotEmpty && message.id != streamingMessageId,
        )
        .toList(growable: false);
    return ListView.builder(
      reverse: true,
      physics: const BouncingScrollPhysics(),
      itemCount: visibleMessages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ownsGeneration && activeJob.responseText.isNotEmpty)
                _CompleteReply(
                  text: activeJob.responseText,
                  showActions: false,
                  selectable: false,
                ),
              if (ownsGeneration)
                _ModelResponseLoader(
                  key: ValueKey(activeJob.state),
                  label: generation.progressLabel,
                  stopping: activeJob.state == ChatGenerationState.stopping,
                  onStop: onStop,
                )
              else if (activeJob != null)
                OtherChatGenerationNotice(
                  title:
                      conversations
                          .conversationById(activeJob.conversationId)
                          ?.title ??
                      'another chat',
                  onOpen: () => onOpenConversation(activeJob.conversationId),
                  onStop: onStop,
                )
              else if (visibleError != null)
                _ErrorReply(key: const ValueKey('error'), text: visibleError),
              if (visibleMessages.isNotEmpty) const SizedBox(height: 14),
            ],
          );
        }
        final message = visibleMessages[visibleMessages.length - index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: message.role == ConversationRole.user
              ? Align(
                  alignment: Alignment.centerRight,
                  child: _Bubble(
                    text: message.text,
                    user: true,
                    modelTier: 'User message',
                  ),
                )
              : _CompleteReply(
                  text: message.text,
                  userPrompt:
                      (visibleMessages.length - index - 1 >= 0 &&
                          visibleMessages[visibleMessages.length - index - 1]
                                  .role ==
                              ConversationRole.user)
                      ? visibleMessages[visibleMessages.length - index - 1].text
                      : null,
                  modelTier: message.modelTier,
                  status: message.status,
                  showActions: true,
                  selectable: true,
                  onContinue:
                      message.status ==
                              ConversationMessageStatus.tokenLimited &&
                          message.continuationCount < 1
                      ? () => onContinue(message)
                      : null,
                ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    this.user = false,
    this.modelTier = 'Finn AI',
  });

  final String text;
  final bool user;
  final String modelTier;

  @override
  Widget build(BuildContext context) {
    return _MessageBubble(
      text: text,
      user: user,
      modelTier: modelTier,
      childBuilder: (selecting) => Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: user ? FluxColors.canvasOf(context) : null,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.text,
    required this.user,
    required this.modelTier,
    required this.childBuilder,
    this.userPrompt,
  });

  final String text;
  final bool user;
  final String modelTier;
  final String? userPrompt;
  final Widget Function(bool selecting) childBuilder;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _actionsVisible = false;
  bool _selecting = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _actionsVisible = false);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(milliseconds: 900),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .82,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.user
            ? FluxColors.inkOf(context)
            : FluxColors.cardOf(context),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(19),
          topRight: const Radius.circular(19),
          bottomLeft: Radius.circular(widget.user ? 19 : 5),
          bottomRight: Radius.circular(widget.user ? 5 : 19),
        ),
        border: widget.user
            ? null
            : Border.all(color: FluxColors.lineOf(context)),
      ),
      child: _selecting
          ? SelectionArea(child: widget.childBuilder(true))
          : widget.childBuilder(false),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.user
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: _selecting
              ? null
              : () => setState(() => _actionsVisible = !_actionsVisible),
          child: Semantics(
            button: !_selecting,
            hint: _selecting ? null : 'Press and hold for message actions',
            child: bubble,
          ),
        ),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axis: Axis.vertical,
              alignment: Alignment.topCenter,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -.16),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
          ),
          child: !_actionsVisible
              ? const SizedBox(key: ValueKey('message-actions-hidden'))
              : Padding(
                  key: const ValueKey('message-actions-visible'),
                  padding: const EdgeInsets.only(top: 8),
                  child: Material(
                    color: FluxColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 178,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: FluxColors.lineOf(context)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _InlineMessageAction(
                            icon: FluxIcons.copy,
                            label: 'Copy',
                            onTap: _copy,
                          ),
                          Divider(height: 1, color: FluxColors.lineOf(context)),
                          _InlineMessageAction(
                            icon: FluxIcons.edit,
                            label: 'Select',
                            onTap: () => setState(() {
                              _selecting = true;
                              _actionsVisible = false;
                            }),
                          ),
                          Divider(height: 1, color: FluxColors.lineOf(context)),
                          _InlineMessageAction(
                            icon: FluxIcons.flag,
                            label: 'Report',
                            onTap: () {
                              setState(() => _actionsVisible = false);
                              ReportDialog.show(
                                context,
                                assistantResponse: widget.text,
                                userPrompt: widget.userPrompt,
                                modelTier: widget.modelTier,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _InlineMessageAction extends StatelessWidget {
  const _InlineMessageAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(17),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          FluxIcon(icon: icon, size: 18),
          const SizedBox(width: 11),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    ),
  );
}

class _ModelResponseLoader extends StatefulWidget {
  const _ModelResponseLoader({
    super.key,
    required this.label,
    required this.stopping,
    required this.onStop,
  });

  final String label;
  final bool stopping;
  final VoidCallback onStop;

  @override
  State<_ModelResponseLoader> createState() => _ModelResponseLoaderState();
}

class _ModelResponseLoaderState extends State<_ModelResponseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = .42;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    hint: widget.stopping ? null : 'Tap to stop generation',
    button: true,
    enabled: !widget.stopping,
    liveRegion: true,
    child: Align(
      alignment: Alignment.centerLeft,
      child: RepaintBoundary(
        child: Material(
          color: FluxColors.cardOf(context).withValues(alpha: .7),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: widget.stopping ? null : widget.onStop,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              constraints: const BoxConstraints(minHeight: 42, maxWidth: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: FluxColors.lineOf(context)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(3, (index) {
                          final wave =
                              (math.sin(
                                    _controller.value * math.pi * 2 -
                                        index * .8,
                                  ) +
                                  1) /
                              2;
                          return Transform.scale(
                            scale: .72 + wave * .3,
                            child: Opacity(
                              opacity: .28 + wave * .72,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: FluxColors.inkOf(context),
                                  shape: BoxShape.circle,
                                ),
                                child: const SizedBox.square(dimension: 6),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  if (!widget.stopping) ...[
                    const SizedBox(width: 7),
                    FluxIcon(
                      icon: FluxIcons.close,
                      size: 15,
                      color: FluxColors.mutedOf(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

@visibleForTesting
class OtherChatGenerationNotice extends StatelessWidget {
  const OtherChatGenerationNotice({
    super.key,
    required this.title,
    required this.onOpen,
    required this.onStop,
  });

  final String title;
  final VoidCallback onOpen;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Generating in another chat',
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: FluxColors.cardOf(context).withValues(alpha: .78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FluxColors.lineOf(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Generating in $title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          TextButton(onPressed: onOpen, child: const Text('Open')),
          TextButton(onPressed: onStop, child: const Text('Stop')),
        ],
      ),
    ),
  );
}

class _CompleteReply extends StatelessWidget {
  const _CompleteReply({
    required this.text,
    this.userPrompt,
    this.modelTier = 'Finn AI',
    this.status = ConversationMessageStatus.complete,
    this.showActions = true,
    this.selectable = true,
    this.onContinue,
  });

  final String text;
  final String? userPrompt;
  final String modelTier;
  final ConversationMessageStatus status;
  final bool showActions;
  final bool selectable;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _MessageBubble(
        text: text,
        user: false,
        modelTier: modelTier,
        userPrompt: userPrompt,
        childBuilder: (_) => _ReplyText(text: text),
      ),
      if (showActions) ...[
        const SizedBox(height: 5),
        Text(
          switch (status) {
            ConversationMessageStatus.complete => 'Answered using $modelTier',
            ConversationMessageStatus.stopped =>
              'Stopped by you · partial response',
            ConversationMessageStatus.interrupted =>
              'Interrupted · partial response preserved',
            ConversationMessageStatus.tokenLimited =>
              'Length limit reached · partial response preserved',
            ConversationMessageStatus.failed =>
              'Generation failed · partial response preserved',
            ConversationMessageStatus.generating =>
              'Generating using $modelTier',
          },
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: FluxColors.mutedOf(context)),
        ),
        if (onContinue != null)
          TextButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.arrow_forward, size: 17),
            label: const Text('Continue'),
          ),
      ],
    ],
  );
}

class _ReplyText extends StatelessWidget {
  const _ReplyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => SafeMarkdownText(text: text);
}

class _FinnPageRoute<T> extends PageRouteBuilder<T> {
  _FinnPageRoute({required Widget child})
    : super(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, page) {
          if (MediaQuery.disableAnimationsOf(context)) return page;
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubicEmphasized,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(.08, 0),
                end: Offset.zero,
              ).animate(curved),
              child: page,
            ),
          );
        },
      );
}

class _FinnSettingsRoute<T> extends PageRouteBuilder<T> {
  _FinnSettingsRoute({required Widget child})
    : super(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (context, animation, _, page) {
          if (MediaQuery.disableAnimationsOf(context)) return page;
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
            child: page,
          );
        },
      );
}

class _ErrorReply extends StatelessWidget {
  const _ErrorReply({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => _Bubble(text: text);
}

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.blocked,
    required this.onSend,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool blocked;
  final VoidCallback onSend;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late bool _hasText;
  late bool _focused;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    _focused = widget.focusNode.hasFocus;
    widget.controller.addListener(_changed);
    widget.focusNode.addListener(_changed);
  }

  void _changed() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final focused = widget.focusNode.hasFocus;
    if (_hasText == hasText && _focused == focused) return;
    setState(() {
      _hasText = hasText;
      _focused = focused;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.focusNode.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && !widget.blocked;
    return FluxGlass(
      radius: 999,
      color: FluxColors.surfaceOf(context),
      borderColor: FluxColors.inkOf(
        context,
      ).withValues(alpha: _focused ? .2 : .07),
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.only(left: 18, right: 7),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Message to Finn AI',
                  textField: true,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    inputFormatters: [LengthLimitingTextInputFormatter(4000)],
                    enabled: !widget.blocked,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => canSend ? widget.onSend() : null,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration.collapsed(
                      hintText: widget.blocked
                          ? 'Finn AI is responding…'
                          : 'Ask anything',
                      hintStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: FluxColors.mutedOf(context)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Semantics(
                button: true,
                enabled: canSend,
                label: 'Send message',
                child: SizedBox.square(
                  key: const ValueKey('send-button-surface'),
                  dimension: 40,
                  child: InkWell(
                    onTap: canSend ? widget.onSend : null,
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: FigmaSvg(
                        asset: canSend
                            ? FigmaAssets.activeSend
                            : FigmaAssets.send,
                        key: const ValueKey('send-button-icon'),
                        width: 34,
                        height: 34,
                        invertForDark: FluxColors.isDark(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.onClose,
    required this.onNewConversation,
    required this.onConversation,
    required this.conversations,
    required this.activeConversationId,
    required this.onCreations,
    required this.onYou,
    required this.onSkills,
    required this.onSettings,
    required this.showAd,
  });

  final VoidCallback onClose;
  final VoidCallback onNewConversation;
  final ValueChanged<String> onConversation;
  final List<FinnConversation> conversations;
  final String? activeConversationId;
  final VoidCallback onCreations;
  final VoidCallback onYou;
  final VoidCallback onSkills;
  final VoidCallback onSettings;
  final bool showAd;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  late final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _scrollOffset.value = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: FluxColors.canvasOf(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double sy = (constraints.maxHeight / 844).clamp(0.7, 1.3);
          final double headerTop = 71 * sy;
          final double headerHeight = 34;
          final double gap1 = 14 * sy;
          final double buttonsTop = headerTop + headerHeight + gap1;
          final double navSize = ((constraints.maxWidth - 80) / 3).clamp(
            52.0,
            62.0,
          );
          final double buttonsHeight = navSize + 20;
          final double buttonsBottom = buttonsTop + buttonsHeight;
          final double initialTitleTop = buttonsBottom + 14 * sy;
          final double pinnedTitleTop = headerTop;
          const double titleHeight = 24;
          final double historyTopAtRest = initialTitleTop + titleHeight + 12;
          final double titleTravelDistance = initialTitleTop - pinnedTitleTop;

          return Stack(
            children: [
              // 1. Scrolling Chat History List in Background
              Positioned.fill(
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: historyTopAtRest,
                        bottom: (widget.showAd ? 74 : 30) + safeBottom,
                      ),
                      sliver: widget.conversations.isEmpty
                          ? SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const FigmaSvg(
                                      asset: FigmaAssets.noHistory,
                                      width: 40,
                                      height: 40,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No history',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: FluxColors.mutedOf(context),
                                            fontSize: 10,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SliverList.builder(
                              itemCount: widget.conversations.length,
                              itemBuilder: (context, index) {
                                final conversation =
                                    widget.conversations[index];
                                return _SidebarConversationTile(
                                  key: ValueKey(conversation.id),
                                  conversation: conversation,
                                  selected:
                                      conversation.id ==
                                      widget.activeConversationId,
                                  onTap: () =>
                                      widget.onConversation(conversation.id),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              // 2. Lightweight pinned-header surface. A solid surface avoids
              // per-frame backdrop filtering while preserving legibility.
              ValueListenableBuilder<double>(
                valueListenable: _scrollOffset,
                builder: (context, offset, _) {
                  final double scrollUp = math.max(0.0, offset);
                  final double coverProgress = (scrollUp / 24.0).clamp(
                    0.0,
                    1.0,
                  );
                  final double coverHeight = coverProgress <= 0
                      ? 0.0
                      : (pinnedTitleTop + titleHeight + 14 * sy);

                  return Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: coverHeight,
                    child: IgnorePointer(
                      child: coverProgress <= 0
                          ? const SizedBox()
                          : ColoredBox(
                              color: FluxColors.canvasOf(
                                context,
                              ).withValues(alpha: .96),
                            ),
                    ),
                  );
                },
              ),

              // 3. Header (Finn AI title + actions) - fades out on scroll up as title replaces it, spring overscroll on pull down
              Positioned(
                left: 25,
                right: 20,
                top: headerTop,
                height: headerHeight,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, child) {
                    final double pullDown = offset < 0 ? -offset : 0.0;
                    final double shift = pullDown * 0.20;
                    final double scrollUp = math.max(0.0, offset);
                    final double opacity =
                        (1.0 - (scrollUp / (titleTravelDistance * 0.5))).clamp(
                          0.0,
                          1.0,
                        );

                    return IgnorePointer(
                      ignoring: opacity < 0.5,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, shift),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        height: 34,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Finn AI',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w400),
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 78,
                        height: 34,
                        child: Stack(
                          children: [
                            // Underlying SVG showing both icons
                            const FigmaSvg(
                              asset: FigmaAssets.sidebarActions,
                              width: 78,
                              height: 34,
                            ),
                            // Left half → Settings
                            Positioned(
                              left: 0,
                              top: 0,
                              width: 39,
                              bottom: 0,
                              child: Tooltip(
                                message: 'Settings',
                                child: InkWell(
                                  onTap: widget.onSettings,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(17),
                                  ),
                                ),
                              ),
                            ),
                            // Right half → New Conversation
                            Positioned(
                              left: 39,
                              top: 0,
                              right: 0,
                              bottom: 0,
                              child: Tooltip(
                                message: 'New chat',
                                child: InkWell(
                                  onTap: widget.onNewConversation,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(17),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Local feature destinations.
              Positioned(
                left: 25,
                right: 25,
                top: buttonsTop,
                height: buttonsHeight,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, child) {
                    final double pullDown = offset < 0 ? -offset : 0.0;
                    final double shift = pullDown * 0.45;
                    final double scrollUp = math.max(0.0, offset);
                    final double opacity =
                        (1.0 - (scrollUp / (titleTravelDistance * 0.7))).clamp(
                          0.0,
                          1.0,
                        );

                    return IgnorePointer(
                      ignoring: opacity < 0.5,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, shift),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavTile(
                        asset: FigmaAssets.sidebarCreations,
                        label: 'Creations',
                        onTap: widget.onCreations,
                        size: navSize,
                      ),
                      _NavTile(
                        asset: FigmaAssets.sidebarYou,
                        label: 'You',
                        onTap: widget.onYou,
                        size: navSize,
                      ),
                      _NavTile(
                        asset: FigmaAssets.sidebarSkills,
                        label: 'Skills',
                        onTap: widget.onSkills,
                        size: navSize,
                      ),
                    ],
                  ),
                ),
              ),
              // 5. Chat History Title - lifts up on scroll all the way to headerTop replacing content beneath, spring overscroll on pull down
              Positioned(
                left: 25,
                right: 25,
                top: initialTitleTop,
                height: titleHeight,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, child) {
                    double shift;
                    if (offset < 0) {
                      final double pullDown = -offset;
                      shift = pullDown * 0.70;
                    } else {
                      shift = -math.min(titleTravelDistance, offset);
                    }
                    return Transform.translate(
                      offset: Offset(0, shift),
                      child: child,
                    );
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chat History',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: safeBottom + 8,
                child: BannerAdWidget(
                  key: const Key('sidebar-ad'),
                  enabled: widget.showAd,
                  margin: EdgeInsets.zero,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.asset,
    required this.label,
    required this.onTap,
    this.size = 62,
  });
  final String asset;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: size,
        height: size + 20,
        color: Colors.transparent,
        child: Column(
          children: [
            FigmaSvg(asset: asset, width: size, height: size, isNavTile: true),
            const SizedBox(height: 5),
            SizedBox(
              width: size,
              height: 15,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: FluxColors.inkOf(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SidebarConversationTile extends StatelessWidget {
  const _SidebarConversationTile({
    super.key,
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final FinnConversation conversation;
  final bool selected;
  final VoidCallback onTap;

  void _showChatPopupMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final position = RelativeRect.fromRect(
      renderBox.localToGlobal(Offset.zero, ancestor: overlay) & renderBox.size,
      Offset.zero & overlay.size,
    );

    final isDark = FluxColors.isDark(context);
    showMenu<String>(
      context: context,
      position: position,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? const Color(0xFF27272A) : Colors.white,
      items: [
        PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: const [
              Icon(Icons.edit_outlined, size: 20),
              SizedBox(width: 12),
              Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: const [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'rename') {
        _showRenameDialog(context);
      } else if (value == 'delete') {
        _showDeleteConfirmDialog(context);
      }
    });
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: conversation.title);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter chat title'),
          onSubmitted: (text) {
            Navigator.of(dialogContext).pop();
            ConversationStore.instance.renameConversation(
              conversation.id,
              text,
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ConversationStore.instance.renameConversation(
                conversation.id,
                controller.text,
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    final generationActive = conversation.messages.any(
      (message) => message.status == ConversationMessageStatus.generating,
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          generationActive
              ? 'Stop the active generation before deleting this chat. Its '
                    'partial response will be preserved.'
              : 'Are you sure you want to delete this chat history? This '
                    'action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(generationActive ? 'Close' : 'Cancel'),
          ),
          if (!generationActive)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ConversationStore.instance.deleteConversation(conversation.id);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected ? FluxColors.surfaceOf(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _showChatPopupMenu(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Text(
              conversation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}
