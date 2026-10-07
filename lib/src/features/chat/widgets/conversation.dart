part of '../home_shell.dart';

class _Conversation extends StatefulWidget {
  const _Conversation({
    required this.messages,
    required this.activeConversationId,
    required this.generation,
    required this.conversations,
    required this.onStop,
    required this.onContinue,
    required this.onRegenerate,
    required this.onRunAction,
    required this.onDismissAction,
    required this.onActions,
    required this.onEdit,
    required this.onOpenConversation,
    required this.preparing,
    required this.topInset,
    required this.bottomInset,
    required this.scrollController,
    required this.greeting,
    required this.cards,
    this.receded = false,
    this.searchFailed = false,
    this.onDismissSearchNotice,
    this.historyUnavailable = false,
    this.onDismissHistoryNotice,
  });
  final List<ConversationMessage> messages;
  final String? activeConversationId;
  final ChatGenerationController generation;
  final ConversationStore conversations;
  final VoidCallback onStop;
  final ValueChanged<ConversationMessage> onContinue;
  final ValueChanged<ConversationMessage> onRegenerate;
  final ValueChanged<ConversationMessage> onRunAction;
  final ValueChanged<ConversationMessage> onDismissAction;
  final VoidCallback onActions;
  final ValueChanged<ConversationMessage> onEdit;
  final ValueChanged<String> onOpenConversation;
  final bool preparing;

  /// What the cards under replies (a creation, a flow) need to work.
  final MessageCardHost cards;

  /// Greeting shown on the empty slate; the design greets a listening session
  /// with a different line than a typed one.
  final String greeting;

  /// True during a live voice conversation: the transcript steps back, a
  /// little smaller and dimmer, so the screen's light has the foreground.
  final bool receded;

  /// True when the conversation store could not be opened, so the notice
  /// explaining that history is not being kept should be shown.
  final bool historyUnavailable;
  final VoidCallback? onDismissHistoryNotice;

  /// Vertical insets so the first message clears the header and the newest
  /// message clears the composer, while the list still bleeds beneath both
  /// for the soft edge fade.
  final double topInset;
  final double bottomInset;

  /// Scroll controller owned by the shell so it can observe the scroll
  /// position (to collapse the composer) and jump back to the latest message.
  final ScrollController scrollController;

  /// True when the last turn wanted the web and could not reach it. Rendered
  /// with the reply that failed rather than as a banner over the app.
  final bool searchFailed;

  /// Dismisses [searchFailed] for the rest of this turn.
  final VoidCallback? onDismissSearchNotice;

  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  Timer? _scrollSettleTimer;

  /// (conversationId, messageCount, jobId, responseLength, state, preparing)
  /// — the layout-relevant generation inputs. A change that only moves the
  /// response length is a token event: the streaming bubble repaints itself
  /// and the list only re-anchors the scroll, without a full rebuild.
  late (String, int, String?, int, String?, bool) _contentSignature;

  @override
  void initState() {
    super.initState();
    _contentSignature = _signature();
    widget.generation.addListener(_generationChanged);
  }

  @override
  void didUpdateWidget(covariant _Conversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSignature(rebuild: false);
  }

  (String, int, String?, int, String?, bool) _signature() {
    final active = widget.generation.activeJob;
    return (
      widget.activeConversationId ?? '',
      widget.messages.length,
      active?.conversationId,
      active?.responseText.length ?? 0,
      active?.state.name,
      widget.preparing,
    );
  }

  void _generationChanged() {
    if (!mounted) return;
    _syncSignature(rebuild: true);
  }

  void _syncSignature({required bool rebuild}) {
    final nextSignature = _signature();
    if (nextSignature == _contentSignature) return;
    final previous = _contentSignature;
    _contentSignature = nextSignature;
    final textOnlyGrew = previous.$1 == nextSignature.$1 &&
        previous.$2 == nextSignature.$2 &&
        previous.$3 == nextSignature.$3 &&
        previous.$5 == nextSignature.$5 &&
        previous.$6 == nextSignature.$6;
    if (rebuild && !textOnlyGrew) {
      setState(() {});
    }
    _queueLatestAlignment();
  }

  void _queueLatestAlignment() {
    _scrollSettleTimer?.cancel();
    _scrollSettleTimer = Timer(const Duration(milliseconds: 70), () {
      if (!mounted || !widget.scrollController.hasClients) return;
      final position = widget.scrollController.position;
      // Reverse lists place the latest response at offset zero. Follow new
      // output only while the user is already near it; never pull someone
      // away from an older message they are reading.
      if (position.pixels > 140 || position.pixels <= .5) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        widget.scrollController.jumpTo(0);
      } else {
        unawaited(
          widget.scrollController.animateTo(
            0,
            duration: FluxMotion.pageDuration,
            curve: Curves.easeOutQuart,
          ),
        );
      }
    });
  }

  /// Counter-balances the reverse list's bottom anchor while a sources list
  /// grows: expanding the message pushes the content above it up by [delta],
  /// so the scroll position is nudged by the same amount to keep the answer
  /// anchored while the actions below the sources slide down.
  void _compensateSourcesGrowth(double delta) {
    if (!widget.scrollController.hasClients || delta == 0) return;
    final position = widget.scrollController.position;
    final target = (position.pixels + delta).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if (target != position.pixels) {
      widget.scrollController.jumpTo(target);
    }
  }

  @override
  void dispose() {
    widget.generation.removeListener(_generationChanged);
    _scrollSettleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeJob = widget.generation.activeJob;
    final ownsGeneration = activeJob != null &&
        activeJob.conversationId == widget.activeConversationId;
    final terminalJob = widget.generation.job;
    final visibleError =
        terminalJob?.conversationId == widget.activeConversationId &&
                terminalJob?.state == ChatGenerationState.error
            ? terminalJob?.errorMessage
            : null;
    // A turn that failed before emitting any token is persisted with empty
    // text, so it never reaches the message list and its Regenerate action is
    // unreachable. Surface a retry on the error bubble itself.
    final failedTurn = visibleError == null
        ? null
        : widget.messages
            .where((message) => message.id == terminalJob?.assistantMessageId)
            .firstOrNull;
    if (widget.messages.isEmpty &&
        activeJob == null &&
        visibleError == null &&
        !widget.preparing) {
      return _FadeRise(child: _ConversationEmpty(greeting: widget.greeting));
    }
    final streamingMessageId =
        ownsGeneration ? activeJob.assistantMessageId : null;
    final visibleMessages = widget.messages
        .where(
          (message) =>
              message.text.isNotEmpty && message.id != streamingMessageId,
        )
        .toList(growable: false);
    return _Recede(
      active: widget.receded,
      bottomFade: widget.bottomInset,
      child: _transcript(context, visibleMessages, failedTurn, visibleError,
          ownsGeneration, activeJob),
    );
  }

  Widget _transcript(
    BuildContext context,
    List<ConversationMessage> visibleMessages,
    ConversationMessage? failedTurn,
    String? visibleError,
    bool ownsGeneration,
    ChatGenerationJob? activeJob,
  ) {
    return Stack(
      key: const ValueKey('chat-edge-fade'),
      children: [
        ListView.builder(
          key: const ValueKey('chat-scroll-view'),
          controller: widget.scrollController,
          reverse: true,
          // Content bleeds into the soft edge fades so messages fade out as
          // they reach the top edge and fade into the bottom screen edge
          // beneath the composer. The top inset parks the oldest message below
          // the header instead of against the status bar; the bottom inset
          // keeps the newest message close above the composer.
          padding: EdgeInsets.fromLTRB(
            0,
            widget.topInset,
            0,
            widget.bottomInset + 20,
          ),
          // ignore: deprecated_member_use (OHOS fork 3.27 lacks scrollCacheExtent)
          cacheExtent: 700.0,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const FluxBouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: visibleMessages.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.searchFailed) ...[
                    _OfflineSearchNotice(
                      onDismiss: widget.onDismissSearchNotice,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.historyUnavailable) ...[
                    _HistoryUnavailableNotice(
                      onDismiss: widget.onDismissHistoryNotice,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (ownsGeneration)
                    _StreamingReply(
                      generation: widget.generation,
                      text: activeJob!.responseText,
                    )
                  else if (widget.preparing)
                    _StreamingReply(generation: widget.generation, text: '')
                  else if (activeJob != null)
                    OtherChatGenerationNotice(
                      title: widget.conversations
                              .conversationById(activeJob.conversationId)
                              ?.title ??
                          L10n.of(context).chatAnotherChatFallback,
                      onOpen: () =>
                          widget.onOpenConversation(activeJob.conversationId),
                      onStop: widget.onStop,
                    )
                  else if (visibleError != null)
                    _ErrorReply(
                      key: const ValueKey('error'),
                      text: visibleError ==
                              ChatGenerationController.emptyReplyError
                          ? L10n.of(context).chatEmptyReply
                          : visibleError,
                      onRetry: failedTurn == null
                          ? null
                          : () => widget.onRegenerate(failedTurn),
                    ),
                  if (visibleMessages.isNotEmpty) const SizedBox(height: 14),
                ],
              );
            }
            final message = visibleMessages[visibleMessages.length - index];
            return Padding(
              key: ValueKey('chat-message-${message.id}'),
              padding: const EdgeInsets.only(bottom: 14),
              child: FluxEntrance(
                // A message grows out of the side it belongs to.
                alignment: message.role == ConversationRole.user
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                child: message.role == ConversationRole.user
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: _Bubble(
                          text: message.text,
                          imagePath: message.imagePath,
                          user: true,
                          modelTier: 'User message',
                          onEdit: () => widget.onEdit(message),
                        ),
                      )
                    : _CompleteReply(
                        text: message.text,
                        userPrompt: (visibleMessages.length - index - 1 >= 0 &&
                                visibleMessages[
                                            visibleMessages.length - index - 1]
                                        .role ==
                                    ConversationRole.user)
                            ? visibleMessages[
                                    visibleMessages.length - index - 1]
                                .text
                            : null,
                        modelTier: message.modelTier,
                        status: message.status,
                        sources: message.sources,
                        toolActivities: message.toolActivities,
                        pendingAction: message.pendingAction,
                        card: message.card == null
                            ? null
                            : MessageCardView(
                                card: message.card!,
                                host: widget.cards,
                              ),
                        onRunAction: message.pendingAction == null
                            ? null
                            : () => widget.onRunAction(message),
                        onDismissAction: message.pendingAction == null
                            ? null
                            : () => widget.onDismissAction(message),
                        onSourcesHeightDelta: _compensateSourcesGrowth,
                        showActions: true,
                        onContinue: message.status ==
                                    ConversationMessageStatus.tokenLimited &&
                                message.continuationCount < 1
                            ? () => widget.onContinue(message)
                            : null,
                        onRegenerate:
                            message.id == widget.messages.lastOrNull?.id
                                ? () => widget.onRegenerate(message)
                                : null,
                      ),
              ),
            );
          },
        ),
        // Fixed overlay bands (Positioned, not Align) so they are anchored to
        // the real top and bottom edges of the viewport. The top band is tall
        // enough to hide the header completely and still ramp out below it; the
        // bottom band fades content into the very bottom edge of the screen and
        // completes exactly at the composer's top edge, so messages stay crisp
        // right up to the input.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: finnTopFadeHeight,
          child: IgnorePointer(
            child: _VoiceHidden(
              hidden: widget.receded,
              child: const FinnEdgeFade(
                key: ValueKey('chat-fade-top'),
                top: true,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: widget.bottomInset,
          child: IgnorePointer(
            child: _VoiceHidden(
              hidden: widget.receded,
              child: const FinnEdgeFade(
                key: ValueKey('chat-fade-bottom'),
                top: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hides [child] while voice mode is open. The edge fades are painted in the
/// solid canvas colour: over voice mode's glow they hid it at the top and
/// bottom, and once [_Recede] scaled them they showed as a hard-edged black
/// rectangle inset from the screen's edges.
class _VoiceHidden extends StatelessWidget {
  const _VoiceHidden({required this.hidden, required this.child});

  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        child: child,
      );
}

/// Steps [child] back while [active]: scaled toward its centre and dimmed.
/// Transform and opacity only, so it costs no more than the frame it is in.
class _Recede extends StatelessWidget {
  const _Recede({
    required this.active,
    required this.bottomFade,
    required this.child,
  });

  final bool active;

  /// Height of the band over the composer that messages fade out in.
  final double bottomFade;
  final Widget child;

  /// Fades the transcript's own pixels out under the header and over the
  /// composer, so voice mode's glow shows through where the canvas-coloured
  /// edge fades (hidden in voice mode, see [_VoiceHidden]) used to cover it.
  Widget _edgeMask(Widget child, double t) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          final h = bounds.height <= 0 ? 1.0 : bounds.height;
          final top = (finnTopFadeOpaqueDepth / h).clamp(0.0, .45);
          final topEnd = (finnTopFadeHeight / h).clamp(top, .5);
          final bottom = (1 - bottomFade / h).clamp(.5, 1.0);
          final hidden = Color.fromRGBO(255, 255, 255, 1 - t);
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [hidden, hidden, Colors.white, Colors.white, hidden],
            stops: [0, top, topEnd, bottom, 1],
          ).createShader(bounds);
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: active ? 1.0 : 0.0),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        child: child,
        builder: (context, t, child) => t == 0
            ? child!
            : _edgeMask(
                Opacity(
                  opacity: 1 - .55 * t,
                  child: Transform.scale(scale: 1 - .045 * t, child: child),
                ),
                t,
              ),
      );
}
