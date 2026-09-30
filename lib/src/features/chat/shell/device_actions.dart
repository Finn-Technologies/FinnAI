// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

extension _HomeShellDeviceActions on _HomeShellState {
  Future<void> _handleDeviceAction(
    DeviceActionInvocation invocation,
    String prompt,
  ) async {
    final conversation = _conversations.active ?? _conversations.startNew();
    final assistant = _conversations.beginExchangeInConversation(
      conversation.id,
      prompt,
    );
    final description = DeviceActionDescriptions.describe(context, invocation);

    if (!ChatDeviceActions.runsWithoutAsking(invocation)) {
      _composer.clear();
      _conversations.updateMessageInConversation(
        conversation.id,
        assistant.id,
        description,
        pendingAction: invocation,
        status: ConversationMessageStatus.complete,
        persistSoon: true,
      );
      return;
    }

    _composer.clear();
    _conversations.updateMessageInConversation(
      conversation.id,
      assistant.id,
      description,
      status: ConversationMessageStatus.complete,
    );
    final result = await _deviceActions.run(invocation);
    if (!mounted) return;
    _conversations.updateMessageInConversation(
      conversation.id,
      assistant.id,
      DeviceActionDescriptions.resultLine(context, result),
      clearPendingAction: true,
      status: ConversationMessageStatus.complete,
      persistSoon: true,
    );
  }

  Future<void> _runPendingAction(ConversationMessage message) async {
    final invocation = message.pendingAction;
    final conversation = _conversations.active;
    if (invocation == null || conversation == null) return;
    final result = await _deviceActions.run(invocation);
    // The audit entry is written whatever happened: an action that failed is
    // exactly as much a fact about the phone as one that worked, and the log
    // is the only place that fact outlives the message.
    unawaited(
      ActionAuditStore.instance.recordRan(invocation, result, source: 'chat'),
    );
    if (!mounted) return;
    _conversations.updateMessageInConversation(
      conversation.id,
      message.id,
      DeviceActionDescriptions.resultLine(context, result),
      clearPendingAction: true,
      status: ConversationMessageStatus.complete,
      persistSoon: true,
    );
  }

  void _dismissPendingAction(ConversationMessage message) {
    final conversation = _conversations.active;
    if (conversation == null) return;
    // A refusal is recorded too, and it is the more important half of the
    // log: an action the user declined is exactly the one they would want to
    // know about later.
    final refused = message.pendingAction;
    if (refused != null) {
      unawaited(
        ActionAuditStore.instance.recordRefused(refused, source: 'chat'),
      );
    }
    _conversations.updateMessageInConversation(
      conversation.id,
      message.id,
      L10n.of(context).deviceActionsDismissed,
      clearPendingAction: true,
      status: ConversationMessageStatus.complete,
      persistSoon: true,
    );
  }
}
