// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

extension _HomeShellFlows on _HomeShellState {
  /// Keeps the platform alarms in step with the flows, and picks up a tap on a
  /// "your flow is due" notification.
  void _startFlowScheduling() {
    FlowsStore.instance.addListener(_flowsChanged);
    MethodChannelFlowScheduleBackend.channel.setMethodCallHandler((call) async {
      final args = call.arguments as Map?;
      final id = args?['flowId'] as String?;
      if (id == null) return null;
      switch (call.method) {
        // A tap on a notification: the user is here.
        case 'onFlowDue':
          unawaited(_runDueFlow(id));
        // An alarm or a device event: nobody is asking.
        case 'onFlowTrigger':
          unawaited(
            _runTriggeredFlow(id, args?['source'] as String? ?? 'schedule'),
          );
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
    await _flows.scheduler.sync(FlowsStore.instance.flows);
    final pending = await _flows.scheduler.backend.takePendingFlow();
    if (pending != null && mounted) unawaited(_runDueFlow(pending));
  }

  /// Any change to the flows re-arms the alarms, debounced so a burst of edits
  /// is one sync.
  void _flowsChanged() {
    _flowSyncTimer?.cancel();
    _flowSyncTimer = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_flows.scheduler.sync(FlowsStore.instance.flows)),
    );
  }

  /// Runs the flow a notification pointed at, then opens what it wrote.
  ///
  /// A tap is the user being present, so the run happens now, in the
  /// foreground. The user starts it, so a flow that changes the phone asks
  /// first unless it already has a standing grant.
  Future<void> _runDueFlow(String id) async {
    final store = FlowsStore.instance;
    await store.initialize();
    final flow = store.flows.where((f) => f.id == id).firstOrNull;
    if (flow == null || !mounted || _flowRunInProgress) return;
    _flowRunInProgress = true;
    final l10n = L10n.of(context);
    try {
      var granted = flow.granted;
      if (flow.hasDeviceAction && !granted) {
        granted = await showFinnConfirm(
              context,
              title: l10n.flowsAllowTitle(flow.name),
              body: l10n.flowsGrantExplain,
              confirmLabel: l10n.flowsRunAction,
            ) ??
            false;
        if (!granted || !mounted) return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.flowsRunning(flow.name)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 30),
          ),
        );
      final run = await _flows.runner.run(flow, granted: granted);
      if (!mounted) return;
      _afterFlowRun(flow, run);
    } finally {
      _flowRunInProgress = false;
    }
  }

  /// Runs a flow something else started (an alarm, a charger, the phone
  /// booting) while the app is open. There is no one to ask, so the flow's
  /// standing grant decides, exactly as it would with the app closed.
  Future<void> _runTriggeredFlow(String id, String source) {
    // One event can start several flows at once (every flow that listens for
    // "charger connected"), and the runner does one at a time, so they wait in
    // line rather than the later ones being dropped.
    final next = _flowQueue.then((_) => _runQueuedFlow(id, source));
    _flowQueue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _runQueuedFlow(String id, String source) async {
    final store = FlowsStore.instance;
    await store.initialize();
    final flow = store.flows.where((f) => f.id == id).firstOrNull;
    if (flow == null || !flow.enabled || !mounted) return;
    final foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final run = await _flows.runner.run(
      flow,
      triggeredBy: source,
      background: !foreground,
    );
    if (!mounted) return;
    await tellAboutFlowRun(_flows.scheduler, flow, run, L10n.of(context));
  }

  /// What the user sees after a run they started: the chat it wrote, or a
  /// note that it could not finish.
  void _afterFlowRun(FinnFlow flow, FlowRun run) {
    final l10n = L10n.of(context);
    final wrote = run.outcome == FlowRunOutcome.completed &&
        run.steps.any(
          (s) => s.kind == FlowBlockKind.saveToChat && s.detail == 'saved',
        );
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
  }

  /// Opens the conversation the last flow run wrote, if there is one.
  void _openFlowResult() {
    final id = _flows.sink.lastConversationId;
    if (id == null) return;
    _conversations.activate(id);
    // Close the Flows page (or any other pushed page) to reveal the chat.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
