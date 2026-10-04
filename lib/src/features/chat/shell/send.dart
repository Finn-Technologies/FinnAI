// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

extension _HomeShellSend on _HomeShellState {
  Future<void> _send() async {
    final value = _composer.text.trim();
    final attached = _attachedImagePath;
    if ((value.isEmpty && attached == null) || _busy) return;
    if (_inference.isGeneratingReply) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(L10n.of(context).chatFinishingTask),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    // The turn is committed at this point, so the tick belongs here rather
    // than on the tap: a blocked or refused send stays silent.
    HapticFeedback.lightImpact();
    final timing = _generation.createTtftTrace(
      _conversations.active?.id ?? 'new-conversation',
    );
    _prewarmTimer?.cancel();

    setState(() {
      _preparing = true;
    });
    debugPrint('FINN_SEND preparing started');
    try {
      if (!_storesReady) {
        final initialization = Future.wait([
          _conversations.initialize(),
          YouProfileStore.instance.initialize(),
          YouMemoryStore.instance.initialize(),
          FlowsStore.instance.initialize(),
        ]).timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            debugPrint(
              'FINN_SEND store init timeout — proceeding with available stores',
            );
            return <void>[];
          },
        );
        await initialization;
        if (!mounted) return;
        _storesReady = true;
      }
      final systemContext = [
        YouProfileStore.instance.promptContext,
        YouMemoryStore.instance.promptContextFor(
          value,
          chatId: _conversations.active?.id,
        ),
      ].where((item) => item.trim().isNotEmpty).join('\n\n');

      // "Make me an app" and "when I plug in my charger…" build the thing and
      // show it as a card, instead of becoming a chat answer about it.
      if (attached == null && await _handleMakeRequest(value)) return;

      // A device command is answered from the catalog, not the model: it is
      // instant, it works before the model is installed, and it cannot be
      // talked into a different action.
      if (attached == null) {
        final deviceAction = await _deviceActions.resolve(value);
        if (deviceAction != null) {
          if (!mounted) return;
          await _handleDeviceAction(deviceAction, value);
          return;
        }
      }

      final missing = <FinnModelSpec>[];
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
              borderRadius: BorderRadius.circular(FluxRadius.sheet),
            ),
            title: Text(
              L10n.of(context).chatDownloadModelTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w400),
            ),
            content: Text(L10n.of(context).chatDownloadModelBody(size)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(L10n.of(context).commonNotNow),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(L10n.of(context).commonDownload),
              ),
            ],
          ),
        );
        if (accepted != true) {
          return;
        }
      }
      if (!mounted) return;

      final effectivePrompt = value.isNotEmpty
          ? value
          : attached != null && _isImageAttachmentPath(attached)
              ? L10n.of(context).chatImagePromptDefault
              : L10n.of(context).chatFilePromptDefault;
      final conversation = _conversations.active ?? _conversations.startNew();
      final attachedBytes = _attachedImageBytes;
      final history = [
        for (final message in conversation.messages)
          if (message.text.trim().isNotEmpty)
            LocalChatTurn(
              role: message.role.name,
              content: message.text,
              imagePath: message.imagePath,
            ),
      ];
      // Append image bytes to the new turn when available (picker bytes skip temp file)
      final sendHistory =
          attachedBytes != null && _isImageAttachmentPath(attached ?? '')
              ? [
                  ...history,
                  LocalChatTurn(
                    role: 'user',
                    content: effectivePrompt,
                    imagePath: attached,
                    imageBytes: attachedBytes,
                  ),
                ]
              : history;

      _focusNode.unfocus();
      _composer.clear();
      if (mounted) {
        setState(() {
          _attachedImagePath = null;
          _attachedImageBytes = null;
          _dismissedSearchNotice = false;
          _upfrontSearchFailed = false;
        });
      }
      final used = YouMemoryStore.instance.lastUsed;
      if (used.isNotEmpty) {
        _generation.noteToolActivity(
          ToolActivity(
            kind: ToolActivityKind.you,
            label: '${used.length}',
            detail: used.map((item) => item.text).join('\n'),
          ),
        );
      }
      unawaited(
        YouMemoryStore.instance.observe(effectivePrompt, conversation.title),
      );
      final grounding = await _groundTurn(
        effectivePrompt,
        hasAttachment: attached != null,
      );

      // Pass imagePath for persistence (store), but also ensure the history
      // carries bytes when present so the engine can use imageBytes without file I/O.
      await _generation.start(
        conversationId: conversation.id,
        prompt: effectivePrompt,
        imagePath: attached,
        history: attachedBytes != null ? sendHistory : history,
        systemContext: systemContext,
        groundedContext: grounding.groundedContext,
        sources: grounding.sources,
        trace: timing,
        spoken: _spokenTurn,
      );
    } catch (e) {
      debugPrint('FINN_SEND error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(L10n.of(context).chatCouldNotPrepare),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
      _focusComposerOnDesktop();
      debugPrint('FINN_SEND preparing cleared');
    }
  }

  Future<SearchTurnResult> _groundTurn(
    String prompt, {
    bool hasAttachment = false,
  }) async {
    final plan = _searchPlanner.plan(prompt, hasAttachment: hasAttachment);
    if (!plan.search || !ContextConsentStore.instance.webLookups) {
      return SearchTurnResult.none;
    }
    // A search costs several seconds before the first word. In a spoken turn
    // that is paid only when the user asked for it or the question is about
    // now; the speculative fact-check is not worth the wait.
    if (_spokenTurn && plan.reason == SearchPlanReason.factCheck) {
      return SearchTurnResult.none;
    }
    _generation.noteToolActivity(
      ToolActivity(kind: ToolActivityKind.search, label: plan.query),
    );
    final result = await _searchTurn.run(plan);
    if (result.failed && mounted) {
      setState(() => _upfrontSearchFailed = true);
    }
    return result;
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
      YouMemoryStore.instance.promptContextFor(latestUser.text),
    ].where((item) => item.trim().isNotEmpty).join('\n\n');
    // A continuation reuses the sources the reply was written from, so it
    // stays grounded offline. A fresh lookup happens only when the original
    // turn searched and the prompt still calls for one.
    var continuationSources = assistant.sources;
    var groundedContext =
        SearchAgent.groundedContextForSources(continuationSources);
    if (assistant.sources.isNotEmpty) {
      final refreshed = await _groundTurn(latestUser.text);
      if (refreshed.sources.isNotEmpty) {
        continuationSources = refreshed.sources;
        groundedContext = refreshed.groundedContext;
      }
    }
    await _generation.continueResponse(
      conversationId: conversation.id,
      assistantMessageId: assistant.id,
      originalPrompt: latestUser.text,
      history: history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      sources: continuationSources,
    );
  }

  Future<void> _regenerateReply(ConversationMessage assistant) async {
    if (_busy || _inference.isGeneratingReply) return;
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
      for (final message in conversation.messages.take(assistantIndex))
        if (message.text.trim().isNotEmpty)
          LocalChatTurn(role: message.role.name, content: message.text),
    ];
    final systemContext = [
      YouProfileStore.instance.promptContext,
      YouMemoryStore.instance.promptContextFor(latestUser.text),
    ].where((item) => item.trim().isNotEmpty).join('\n\n');
    if (mounted) setState(() => _dismissedSearchNotice = false);
    final grounding = await _groundTurn(latestUser.text);
    await _generation.regenerate(
      conversationId: conversation.id,
      assistantMessageId: assistant.id,
      originalPrompt: latestUser.text,
      history: history,
      systemContext: systemContext,
      groundedContext: grounding.groundedContext,
      sources: grounding.sources,
    );
  }

  Future<void> _editUserMessage(ConversationMessage message) async {
    if (_busy || _inference.isGeneratingReply) return;
    final conversation = _conversations.active;
    if (conversation == null) return;
    final edited = await showDialog<String>(
      context: context,
      builder: (_) => _EditMessageDialog(initialText: message.text),
    );
    if (edited == null) return;
    final trimmed = edited.trim();
    if (trimmed.isEmpty || trimmed == message.text) return;
    final ok = _conversations.editUserMessage(
      conversationId: conversation.id,
      messageId: message.id,
      newText: trimmed,
    );
    if (!ok || !mounted) return;
    final updated = _conversations.conversationById(conversation.id);
    if (updated == null) return;
    final history = [
      for (final message in updated.messages)
        if (message.text.trim().isNotEmpty)
          LocalChatTurn(role: message.role.name, content: message.text),
    ];
    final systemContext = [
      YouProfileStore.instance.promptContext,
      YouMemoryStore.instance.promptContextFor(trimmed),
    ].where((item) => item.trim().isNotEmpty).join('\n\n');
    if (mounted) setState(() => _dismissedSearchNotice = false);
    final grounding = await _groundTurn(trimmed);
    await _generation.replyToExisting(
      conversationId: conversation.id,
      prompt: trimmed,
      history: history,
      systemContext: systemContext,
      groundedContext: grounding.groundedContext,
      sources: grounding.sources,
    );
  }
}
