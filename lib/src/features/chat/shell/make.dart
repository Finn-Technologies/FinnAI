// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

/// Making things from the chat: "make me a water counter app" and "when I plug
/// in my charger turn on the flashlight" are answered by building the thing and
/// showing it right under the reply, as a card you can open or switch on.
extension _HomeShellMake on _HomeShellState {
  /// True when [value] was a request to make something and has been handled.
  ///
  /// Only an explicit request counts (see [CreationRequest] and
  /// [FlowAuthor.isFlowRequest]); anything else goes on to the model.
  Future<bool> _handleMakeRequest(String value) async {
    final creation = CreationRequest.parse(value);
    if (creation != null) {
      await _makeCreation(value, creation);
      return true;
    }
    if (FlowAuthor.isFlowRequest(value)) {
      await _makeFlow(value);
      return true;
    }
    return false;
  }

  /// Starts the exchange in the conversation: the user's words, then a reply
  /// that [_makeReply] fills in as the work finishes.
  ConversationMessage _beginMakeExchange(String value, String progress) {
    final conversation = _conversations.active ?? _conversations.startNew();
    _composer.clear();
    _focusNode.unfocus();
    final reply = _conversations.beginExchangeInConversation(
      conversation.id,
      value,
    );
    _conversations.updateMessageInConversation(
      conversation.id,
      reply.id,
      progress,
      status: ConversationMessageStatus.complete,
    );
    return reply;
  }

  void _makeReply(
    ConversationMessage reply,
    String text, {
    MessageCard? card,
  }) {
    final conversation = _conversations.active;
    if (conversation == null) return;
    _conversations.updateMessageInConversation(
      conversation.id,
      reply.id,
      text,
      card: card,
      status: ConversationMessageStatus.complete,
      persistSoon: true,
    );
  }

  Future<void> _makeCreation(String value, CreationRequest request) async {
    final l10n = L10n.of(context);
    final reply = _beginMakeExchange(value, l10n.chatCreationBuilding);
    final controller = CreationsController(
      CreationStore.instance,
      FinnCreationGenerator(),
    );
    void progress() {
      if (!mounted) return;
      final stage = switch (controller.stage) {
        CreationStage.designing => l10n.creationsStageDesigning,
        CreationStage.writing => l10n.creationsStageWriting,
        CreationStage.validating => l10n.creationsStageValidating,
        CreationStage.repairing => l10n.creationsStageRepairing,
        null => null,
      };
      if (stage != null) _makeReply(reply, stage);
    }

    try {
      await controller.load();
      controller.addListener(progress);
      final result = await controller.create(request.brief, request.kind);
      if (!mounted) return;
      if (result == null) {
        _makeReply(reply, l10n.creationsFailed);
        return;
      }
      _makeReply(
        reply,
        result.usedFallback
            ? '${l10n.creationsFallbackNote}\n\n${l10n.chatCreationReady}'
            : l10n.chatCreationReady,
        card: MessageCard.creation(result.creation.id),
      );
    } on Object catch (error) {
      debugPrint('FINN_MAKE creation failed: ${error.runtimeType}');
      if (mounted) _makeReply(reply, l10n.creationsFailed);
    } finally {
      controller.removeListener(progress);
      controller.dispose();
    }
  }

  Future<void> _makeFlow(String value) async {
    final l10n = L10n.of(context);
    final reply = _beginMakeExchange(value, l10n.flowsDescribeThinking);
    final id = 'custom-${DateTime.now().microsecondsSinceEpoch}';
    try {
      var draft = FlowAuthor.fromSentence(value, id: id);
      final model = _flows.runner.model;
      if (draft == null && model != null && !_inference.isGeneratingReply) {
        draft = FlowAuthor.fromScript(
          await model.answer(FlowAuthor.modelPrompt(value), maxTokens: 200),
          id: id,
        );
      }
      if (!mounted) return;
      final flow = draft?.flow;
      final store = FlowsStore.instance;
      await store.initialize();
      final saved = flow != null &&
          await store.upsertCustom(
            name: flow.name,
            description: flow.description,
            instructions: '',
            category: flow.category,
            enabled: false,
            blocks: flow.blocks,
            triggers: flow.triggers,
            conditions: flow.conditions,
          );
      if (!mounted) return;
      if (!saved) {
        _makeReply(reply, l10n.flowsDescribeFailed);
        return;
      }
      final missed = draft!.notUnderstood;
      _makeReply(
        reply,
        [
          l10n.flowsChatCreated(flow.name),
          if (missed.isNotEmpty) l10n.flowsDescribeMissed(missed.join(', ')),
        ].join('\n\n'),
        card: MessageCard.flow(store.flows.last.id),
      );
    } on Object catch (error) {
      debugPrint('FINN_MAKE flow failed: ${error.runtimeType}');
      if (mounted) _makeReply(reply, l10n.flowsDescribeFailed);
    }
  }
}
