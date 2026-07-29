import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/banner_ad_widget.dart';
import '../conversations/conversation_store.dart';
import '../creations/creations_page.dart';
import '../inference/bonsai_inference.dart';
import '../inference/prompt_intent.dart';
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

enum _ReplyState { idle, loading, thinking, complete, error }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _focusNode = FocusNode();
  final _inference = BonsaiInference.instance;
  final _conversations = ConversationStore.instance;
  StreamSubscription<String>? _replySubscription;
  Timer? _tokenPaintTimer;
  Timer? _memoryReleaseTimer;
  Timer? _prewarmTimer;
  final _pendingTokens = StringBuffer();
  final _streamingAnswer = ValueNotifier<String>('');
  String? _assistantMessageId;
  _ReplyState _replyState = _ReplyState.idle;
  bool _sidebar = false;
  bool _sidebarEverOpened = false;
  bool _sidebarAdVisible = false;
  bool _preparing = false;
  bool _storesReady = false;
  String _answer = '';
  String _error = '';
  bool _canContinue = false;
  bool _continuationUsed = false;
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

  bool get _busy =>
      _preparing ||
      _replySubscription != null ||
      _replyState == _ReplyState.loading ||
      _replyState == _ReplyState.thinking;

  @override
  void initState() {
    super.initState();
    _inference.addListener(_inferenceChanged);
    _conversations.addListener(_conversationChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeStores());
      _schedulePrewarm();
      unawaited(AdConsentService.instance.initializeConsentAndAds());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _memoryReleaseTimer?.cancel();
      _prewarmTimer?.cancel();
      unawaited(_conversations.flush());
      unawaited(_inference.releaseMemory());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _prewarmTimer?.cancel();
      unawaited(_conversations.flush());
      if (state != AppLifecycleState.paused) return;
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
    if (_replySubscription == null) {
      unawaited(_inference.releaseMemory());
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
    _inference.removeListener(_inferenceChanged);
    _conversations.removeListener(_conversationChanged);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_replySubscription?.cancel());
    _tokenPaintTimer?.cancel();
    _memoryReleaseTimer?.cancel();
    _prewarmTimer?.cancel();
    _sidebarController.dispose();
    unawaited(_conversations.flush());
    _composer.dispose();
    _focusNode.dispose();
    _streamingAnswer.dispose();
    super.dispose();
  }

  void _schedulePrewarm() {
    _prewarmTimer?.cancel();
    _prewarmTimer = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_inference.prewarm()),
    );
  }

  void _inferenceChanged() {
    if (!mounted ||
        (_replySubscription == null && !_preparing) ||
        _inference.phase == InferencePhase.idle) {
      return;
    }
    setState(() {
      switch (_inference.phase) {
        case InferencePhase.downloading:
        case InferencePhase.loading:
          _replyState = _ReplyState.loading;
        case InferencePhase.generating:
          if (_answer.isEmpty) _replyState = _ReplyState.thinking;
        case InferencePhase.error:
          _error = _inference.status;
          _replyState = _ReplyState.error;
        case InferencePhase.idle:
          break;
      }
    });
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
      SkillsStore.instance.activePromptContext,
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
          backgroundColor: const Color(0xFFF7F8F4),
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

    final conversation = _conversations.active ?? _conversations.startNew();
    final history = [
      for (final message in conversation.messages)
        LocalChatTurn(role: message.role.name, content: message.text),
    ];

    final assistant = _conversations.beginExchange(value);
    _assistantMessageId = assistant.id;
    _focusNode.unfocus();
    setState(() {
      _answer = '';
      _streamingAnswer.value = '';
      _error = '';
      _canContinue = false;
      _continuationUsed = false;
      _composer.clear();
      _replyState = _ReplyState.loading;
    });

    _replySubscription = _inference
        .generateReply(
          value,
          conversationId: conversation.id,
          history: history,
          systemContext: systemContext,
        )
        .listen(
          (token) {
            if (!mounted) return;
            _pendingTokens.write(token);
            _tokenPaintTimer ??= Timer(
              Duration(
                milliseconds: _inference.plan?.tokenPaintIntervalMs ?? 50,
              ),
              () {
                _tokenPaintTimer = null;
                _flushTokenPaint();
              },
            );
          },
          onError: (Object _) {
            if (!mounted) return;
            _tokenPaintTimer?.cancel();
            _tokenPaintTimer = null;
            _flushTokenPaint(persist: true);
            _replySubscription = null;
            setState(() {
              _error = _inference.status;
              _replyState = _ReplyState.error;
            });
          },
          onDone: () {
            _flushTokenPaint(persist: true);
            _tokenPaintTimer?.cancel();
            _tokenPaintTimer = null;
            _replySubscription = null;
            if (mounted) {
              if (_answer.isEmpty && _replyState != _ReplyState.error) {
                setState(() {
                  _error = 'The model finished without producing a response.';
                  _replyState = _ReplyState.error;
                });
              } else {
                // Settle onto the stored message so the lightweight streaming
                // text is replaced by selectable text and actions only once.
                _streamingAnswer.value = '';
                _assistantMessageId = null;
                setState(() {
                  _replyState = _ReplyState.complete;
                  _canContinue =
                      !_continuationUsed &&
                      _inference.lastGenerationReport?.finishReason ==
                          GenerationFinishReason.tokenLimit;
                });
              }
            }
          },
          cancelOnError: true,
        );
  }

  Future<void> _continueReply() async {
    if (_busy || !_canContinue) return;
    final conversation = _conversations.active;
    if (conversation == null || conversation.messages.isEmpty) return;
    final assistant = conversation.messages.last;
    if (assistant.role != ConversationRole.assistant) return;
    final latestUser = conversation.messages.reversed
        .where((message) => message.role == ConversationRole.user)
        .firstOrNull;
    final history = [
      for (final message in conversation.messages)
        LocalChatTurn(role: message.role.name, content: message.text),
    ];
    final systemContext = [
      YouProfileStore.instance.promptContext,
      SkillsStore.instance.activePromptContext,
    ].where((item) => item.trim().isNotEmpty).join('\n\n');
    _continuationUsed = true;
    _canContinue = false;
    _assistantMessageId = assistant.id;
    _answer = assistant.text;
    _streamingAnswer.value = _answer;
    setState(() => _replyState = _ReplyState.thinking);
    _replySubscription = _inference
        .generateReply(
          BonsaiInference.continuationPrompt,
          conversationId: conversation.id,
          history: history,
          systemContext: systemContext,
          promptAnalysis: latestUser == null
              ? null
              : const PromptIntentClassifier().classify(latestUser.text),
        )
        .listen(
          (token) {
            _pendingTokens.write(token);
            _tokenPaintTimer ??= Timer(
              Duration(
                milliseconds: _inference.plan?.tokenPaintIntervalMs ?? 50,
              ),
              () {
                _tokenPaintTimer = null;
                _flushTokenPaint();
              },
            );
          },
          onError: (Object _) {
            _flushTokenPaint(persist: true);
            _replySubscription = null;
            if (mounted) {
              setState(() {
                _error = _inference.status;
                _replyState = _ReplyState.error;
              });
            }
          },
          onDone: () {
            _flushTokenPaint(persist: true);
            _tokenPaintTimer?.cancel();
            _tokenPaintTimer = null;
            _replySubscription = null;
            _streamingAnswer.value = '';
            _assistantMessageId = null;
            if (mounted) setState(() => _replyState = _ReplyState.complete);
          },
          cancelOnError: true,
        );
  }

  void _flushTokenPaint({bool persist = false}) {
    final generatingTier = _inference.lastGeneratingModel.name;
    if (_pendingTokens.isEmpty) {
      if (persist) {
        final id = _assistantMessageId;
        if (id != null) {
          _conversations.updateMessage(
            id,
            _answer,
            modelTier: generatingTier,
            persistSoon: true,
            notify: false,
          );
        } else {
          unawaited(_conversations.flush());
        }
      }
      return;
    }
    final next = _pendingTokens.toString();
    _pendingTokens.clear();
    final wasEmpty = _answer.isEmpty;
    _answer += next;
    _streamingAnswer.value = _answer;
    final id = _assistantMessageId;
    if (persist && id != null) {
      _conversations.updateMessage(
        id,
        _answer,
        modelTier: generatingTier,
        persistSoon: true,
        notify: false,
      );
    }
    if (wasEmpty && mounted) {
      setState(() => _replyState = _ReplyState.complete);
    }
  }

  Future<void> _stopReply() async {
    final subscription = _replySubscription;
    if (subscription == null) return;
    _replySubscription = null;
    _tokenPaintTimer?.cancel();
    _tokenPaintTimer = null;
    await subscription.cancel();
    await _inference.stopGeneration();
    _flushTokenPaint(persist: true);
    final messageId = _assistantMessageId;
    if (_answer.trim().isEmpty && messageId != null) {
      _conversations.removeMessage(messageId);
    }
    _streamingAnswer.value = '';
    _assistantMessageId = null;
    if (mounted) setState(() => _replyState = _ReplyState.complete);
    await _conversations.flush();
  }

  void _activateConversation(String id) {
    _conversations.activate(id);
    _setSidebar(false);
    setState(() {
      _assistantMessageId = null;
      _replyState = _ReplyState.complete;
      _answer = '';
      _streamingAnswer.value = '';
      _error = '';
      _canContinue = false;
      _continuationUsed = false;
    });
  }

  void _newConversation() {
    _conversations.startNew();
    _setSidebar(false);
    setState(() {
      _assistantMessageId = null;
      _replyState = _ReplyState.idle;
      _answer = '';
      _streamingAnswer.value = '';
      _error = '';
      _canContinue = false;
      _continuationUsed = false;
    });
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
                        state: _replyState,
                        streamingAnswer: _streamingAnswer,
                        streamingMessageId: _assistantMessageId,
                        error: _error,
                        onStop: _stopReply,
                        continuationMessageId: _canContinue
                            ? _conversations.active?.messages.lastOrNull?.id
                            : null,
                        onContinue: _continueReply,
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom:
                          safeBottom + (constraints.maxHeight < 650 ? 20 : 30),
                      child: _Composer(
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
                      showAd:
                          _sidebarAdVisible && !_inference.isGeneratingReply,
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
    required this.state,
    required this.streamingAnswer,
    required this.streamingMessageId,
    required this.error,
    required this.onStop,
    required this.continuationMessageId,
    required this.onContinue,
  });
  final List<ConversationMessage> messages;
  final _ReplyState state;
  final ValueNotifier<String> streamingAnswer;
  final String? streamingMessageId;
  final String error;
  final VoidCallback onStop;
  final String? continuationMessageId;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (state == _ReplyState.idle && messages.isEmpty) return const SizedBox();
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
              ValueListenableBuilder<String>(
                valueListenable: streamingAnswer,
                builder: (context, answer, _) => answer.isEmpty
                    ? const SizedBox()
                    : _CompleteReply(
                        text: answer,
                        showActions: false,
                        selectable: false,
                      ),
              ),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 360),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .025),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: switch (state) {
                  _ReplyState.loading => _ModelResponseLoader(
                    key: ValueKey('loading'),
                    onStop: onStop,
                  ),
                  _ReplyState.thinking => _ModelResponseLoader(
                    key: ValueKey('thinking'),
                    onStop: onStop,
                  ),
                  _ReplyState.complete => const SizedBox(
                    key: ValueKey('complete'),
                  ),
                  _ReplyState.error => _ErrorReply(
                    key: const ValueKey('error'),
                    text: error,
                  ),
                  _ => const SizedBox(),
                },
              ),
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
                  child: _Bubble(text: message.text, user: true),
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
                  showActions: true,
                  selectable: true,
                  onContinue: message.id == continuationMessageId
                      ? onContinue
                      : null,
                ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, this.user = false});
  final String text;
  final bool user;

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final bgColor = user
        ? FluxColors.surfaceOf(context)
        : (isDark
              ? const Color(0xCC222226)
              : Colors.white.withValues(alpha: .66));
    final borderColor = isDark
        ? const Color(0x28FFFFFF)
        : Colors.white.withValues(alpha: .42);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(6),
        ),
        border: Border.all(color: borderColor),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _ModelResponseLoader extends StatefulWidget {
  const _ModelResponseLoader({super.key, required this.onStop});

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
    label: 'Finn AI is preparing a response',
    hint: 'Tap to stop generation',
    button: true,
    liveRegion: true,
    child: Align(
      alignment: Alignment.centerLeft,
      child: RepaintBoundary(
        child: Material(
          color: FluxColors.cardOf(context).withValues(alpha: .7),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: widget.onStop,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 94,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: FluxColors.lineOf(context)),
              ),
              child: Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 7),
                  FluxIcon(
                    icon: FluxIcons.close,
                    size: 15,
                    color: FluxColors.mutedOf(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CompleteReply extends StatelessWidget {
  const _CompleteReply({
    required this.text,
    this.userPrompt,
    this.modelTier = 'Finn AI',
    this.showActions = true,
    this.selectable = true,
    this.onContinue,
  });

  final String text;
  final String? userPrompt;
  final String modelTier;
  final bool showActions;
  final bool selectable;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (selectable)
        SelectionArea(child: _ReplyText(text: text))
      else
        _ReplyText(text: text),
      if (showActions) ...[
        const SizedBox(height: 7),
        Row(
          children: [
            FluxIconButton(
              icon: FluxIcons.copy,
              size: 32,
              tooltip: 'Copy response',
              onTap: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Copied'),
                      duration: Duration(milliseconds: 900),
                    ),
                  );
              },
            ),
            if (onContinue != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: const Text('Continue'),
              ),
            ],
            const SizedBox(width: 8),
            FluxIconButton(
              icon: FluxIcons.flag,
              size: 32,
              tooltip: 'Report response',
              onTap: () {
                ReportDialog.show(
                  context,
                  assistantResponse: text,
                  userPrompt: userPrompt,
                  modelTier: modelTier,
                );
              },
            ),
          ],
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

class _Composer extends StatefulWidget {
  const _Composer({
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
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
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
      radius: 15,
      color: FluxColors.isDark(context)
          ? const Color(0xCC18181B)
          : Colors.white.withValues(alpha: .82),
      borderColor: FluxColors.inkOf(
        context,
      ).withValues(alpha: _focused ? .18 : .045),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.only(left: 14, right: 4),
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
              const SizedBox(width: 8),
              Semantics(
                button: true,
                enabled: canSend,
                label: 'Send message',
                child: AnimatedScale(
                  scale: canSend ? 1 : .94,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: InkWell(
                    onTap: canSend ? widget.onSend : null,
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: FigmaSvg(
                          asset: canSend
                              ? FigmaAssets.activeSend
                              : FigmaAssets.send,
                          width: 34,
                          height: 34,
                        ),
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text(
          'Are you sure you want to delete this chat history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
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
