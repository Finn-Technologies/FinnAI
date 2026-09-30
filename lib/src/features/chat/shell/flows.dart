// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

extension _HomeShellFlows on _HomeShellState {
  /// Keeps the platform alarms in step with the flows, and picks up a tap on a
  /// "your flow is due" notification.
  void _startFlowScheduling() {
    FlowsStore.instance.addListener(_flowsChanged);
    MethodChannelFlowScheduleBackend.channel.setMethodCallHandler((call) async {
      if (call.method == 'onFlowDue') {
        final id = (call.arguments as Map?)?['flowId'] as String?;
        if (id != null) unawaited(_runDueFlow(id));
      }
      return null;
    });
  }

  void _stopFlowScheduling() {
    _flowSyncTimer?.cancel();
    FlowsStore.instance.removeListener(_flowsChanged);
    MethodChannelFlowScheduleBackend.channel.setMethodCallHandler(null);
  }

  /// Called once the stores are ready: arms the alarms and handles a cold
  /// start that came from a notification tap.
  Future<void> _flowsReady() async {
    await _flowScheduler.sync(FlowsStore.instance.flows);
    final pending = await _flowScheduler.backend.takePendingFlow();
    if (pending != null && mounted) unawaited(_runDueFlow(pending));
  }

  /// Any change to the flows re-arms the alarms, debounced so a burst of edits
  /// is one sync.
  void _flowsChanged() {
    _flowSyncTimer?.cancel();
    _flowSyncTimer = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_flowScheduler.sync(FlowsStore.instance.flows)),
    );
  }

  /// Runs the flow a notification pointed at, then opens what it wrote.
  ///
  /// A tap is the user being present, so the run happens now, in the
  /// foreground. The flow's own grant still decides whether it may act on the
  /// device; a flow with no grant stops there and says so.
  Future<void> _runDueFlow(String id) async {
    final store = FlowsStore.instance;
    await store.initialize();
    final flow = store.flows.where((f) => f.id == id).firstOrNull;
    if (flow == null || !mounted || _flowRunInProgress) return;
    _flowRunInProgress = true;
    final l10n = L10n.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.flowsRunning(flow.name)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 30),
        ),
      );
    try {
      final run = await _flowRunner.run(flow, triggeredBy: 'schedule');
      if (!mounted) return;
      final wrote = run.outcome == FlowRunOutcome.completed &&
          flow.steps.any((step) => step.kind == FlowStepKind.prompt);
      ScaffoldMessenger.of(context).clearSnackBars();
      if (wrote) {
        _openFlowResult();
      } else if (run.outcome == FlowRunOutcome.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.flowsRunCouldNotFinish(flow.name)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _flowRunInProgress = false;
    }
  }

  /// Opens the conversation the last flow run wrote, if there is one.
  void _openFlowResult() {
    final id = _flowSink.lastConversationId;
    if (id == null) return;
    _conversations.activate(id);
    // Close the Flows page (or any other pushed page) to reveal the chat.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
