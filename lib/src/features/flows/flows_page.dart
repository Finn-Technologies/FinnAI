import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/features/flows/flow_runner.dart';
import 'package:finn_ai/src/features/flows/flow_scheduler.dart';
import 'package:finn_ai/src/features/flows/flow_templates.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';

part 'parts/cards.dart';

part 'parts/summary.dart';

part 'parts/skill_editor.dart';
part 'parts/history.dart';
part 'parts/automations.dart';

class FlowsPage extends StatefulWidget {
  const FlowsPage({
    super.key,
    required this.onBack,
    this.store,
    this.runner,
    this.scheduler,
    this.onOpenResult,
  });

  final VoidCallback onBack;
  final FlowsStore? store;

  /// Runs a flow on the spot. Injected so the page can be driven in a widget
  /// test without the engine, and so the page has no opinion about how a flow
  /// is executed.
  final FlowRunner? runner;

  /// Arms scheduled flows and asks for notification permission. Null in tests
  /// and on platforms with no scheduler; scheduling controls then still save
  /// the choice, which simply never fires.
  final FlowScheduler? scheduler;

  /// Opens the conversation a finished run just wrote. Null where there is
  /// nowhere to open it.
  final VoidCallback? onOpenResult;

  @override
  State<FlowsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<FlowsPage> {
  late final FlowsStore _store = widget.store ?? FlowsStore.instance;
  late final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);

  /// Which flow is running right now, if any. One at a time: two concurrent
  /// runs would attribute their device actions to each other.
  String? _runningId;

  /// Whether the OS will show this app's notifications. Null until known.
  bool? _notificationsOn;

  FlowRunner get _runner => widget.runner ?? FlowRunner(store: _store);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _store.initialize();
    unawaited(_refreshNotificationState());
  }

  /// Runs a flow once, on the spot.
  ///
  /// A manual run asks before any device action, exactly as a chat turn does:
  /// the grant is what lets a flow act when the user is not looking, and here
  /// the user *is* looking, so one tap stands in for it. The run is recorded
  /// either way, including a refusal.
  Future<void> _run(FinnFlow flow) async {
    if (_runningId != null) return;
    setState(() => _runningId = flow.id);
    try {
      var permitted = true;
      if (flow.hasDeviceAction) {
        // A one-tap confirmation, not a stored grant. The alternative — a
        // dialog naming every action the flow can take — is more honest but
        // is a different screen, and this is the same shape the chat shell
        // already uses for a pending action.
        permitted = await _confirmRun(context, flow) ?? false;
      }
      final run = await _runner.run(flow, granted: permitted);
      if (mounted) _announce(flow, run);
    } finally {
      if (mounted) setState(() => _runningId = null);
    }
  }

  /// Says how a run ended. A run that wrote something offers to open it.
  void _announce(FinnFlow flow, FlowRun run) {
    final l10n = L10n.of(context);
    final wrote = flow.steps.any((step) => step.kind == FlowStepKind.prompt);
    final (message, canOpen) = switch (run.outcome) {
      FlowRunOutcome.completed => (l10n.flowsRunReady(flow.name), wrote),
      FlowRunOutcome.failed => (l10n.flowsRunCouldNotFinish(flow.name), false),
      _ => (null, false),
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: canOpen && widget.onOpenResult != null
              ? SnackBarAction(
                  label: l10n.flowsOpenResult,
                  onPressed: widget.onOpenResult!,
                )
              : null,
        ),
      );
  }

  /// Turning a scheduled automation on is the moment to ask for notifications;
  /// turning it off just disarms it.
  Future<void> _toggleAutomation(FinnFlow flow, bool value) async {
    await _store.setEnabled(flow.id, value);
    if (value && flow.trigger.isScheduled) await _ensureNotifications();
    await widget.scheduler?.sync(_store.flows);
    await _refreshNotificationState();
  }

  Future<bool?> _confirmRun(BuildContext context, FinnFlow flow) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(flow.name),
          content: Text(L10n.of(context).flowsGrantExplain),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(L10n.of(context).commonCancel),
            ),
            FilledButton(
              key: const Key('flow-confirm-run'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(L10n.of(context).flowsRunAction),
            ),
          ],
        ),
      );

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

  Future<void> _editSkill([FinnFlow? flow]) async {
    final result = await showModalBottomSheet<_SkillDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SkillEditor(flow: flow),
    );
    if (result == null) return;
    final saved = await _store.upsertCustom(
      id: flow?.id,
      name: result.name,
      description: result.description,
      instructions: result.instructions,
      enabled: flow?.enabled ?? true,
    );
    if (!saved && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _skillFailureMessage(
                context,
                _store.failure ?? FlowsFailure.save,
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _delete(FinnFlow flow) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluxRadius.card)),
        title: Text(L10n.of(context).flowsDeleteTitle),
        content: Text(L10n.of(context).flowsDeleteBody(flow.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L10n.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(L10n.of(context).commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) await _store.removeCustom(flow.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => _store.initialized
            ? FloatingActionButton.extended(
                key: const Key('add-flow-button'),
                onPressed: () => unawaited(_newAutomation()),
                backgroundColor: FluxColors.inkOf(context),
                foregroundColor: FluxColors.canvasOf(context),
                elevation: 0,
                shape: const StadiumBorder(),
                icon: FluxIcon(
                  icon: FluxIcons.add,
                  size: 20,
                  color: FluxColors.canvasOf(context),
                ),
                label: Text(L10n.of(context).flowsNewAutomation),
              )
            : const SizedBox.shrink(),
      ),
      body: AmbientBackground(
        intensity: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = FinnPageHeaderMetrics.forHeight(
              constraints.maxHeight,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: _store,
                    builder: (context, _) {
                      if (!_store.initialized) {
                        return const Center(
                          child: SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        );
                      }
                      final builtIns =
                          _store.flows.where((flow) => flow.builtIn).toList();
                      final custom = _store.flows
                          .where((flow) => !flow.builtIn && flow.steps.isEmpty)
                          .toList();
                      final automations = _store.flows
                          .where(
                              (flow) => !flow.builtIn && flow.steps.isNotEmpty)
                          .toList();
                      return ListView(
                        controller: _scrollController,
                        physics: const FluxBouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          20,
                          metrics.contentTop + 10,
                          20,
                          104,
                        ),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 680),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _SectionTitle(
                                    title:
                                        L10n.of(context).flowsAutomationsTitle,
                                    subtitle: L10n.of(
                                      context,
                                    ).flowsAutomationsSubtitle,
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FluxPillButton(
                                      key: const Key('new-automation-button'),
                                      label:
                                          L10n.of(context).flowsNewAutomation,
                                      icon: FluxIcons.add,
                                      onTap: () => unawaited(_newAutomation()),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (automations.isEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Text(
                                        L10n.of(context).flowsNoAutomations,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color:
                                                  FluxColors.mutedOf(context),
                                            ),
                                      ),
                                    )
                                  else
                                    ...automations.map(
                                      (flow) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _SkillCard(
                                          flow: flow,
                                          onToggle: (value) => unawaited(
                                            _toggleAutomation(flow, value),
                                          ),
                                          onDelete: () => _delete(flow),
                                          onRun: () => _run(flow),
                                          onEditSchedule: () =>
                                              unawaited(_editSchedule(flow)),
                                          onGrantChanged: (value) =>
                                              _store.setGranted(flow.id, value),
                                          runs: _store.runsOf(flow.id),
                                          isRunning: _runningId == flow.id,
                                          notificationsOff: flow.enabled &&
                                              flow.trigger.isScheduled &&
                                              _notificationsOn == false,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                  _SkillsSummary(
                                    active: _store.enabledSkills.length,
                                    total: _store.flows.length,
                                  ),
                                  const SizedBox(height: 24),
                                  _SectionTitle(
                                    title: L10n.of(context).flowsBuiltForFinn,
                                    subtitle: L10n.of(
                                      context,
                                    ).flowsBuiltForFinnSubtitle,
                                  ),
                                  const SizedBox(height: 10),
                                  ...builtIns.map(
                                    (flow) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _SkillCard(
                                        flow: flow,
                                        onToggle: (value) =>
                                            _store.setEnabled(flow.id, value),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _SectionTitle(
                                    title: L10n.of(context).flowsYourSkills,
                                    subtitle: L10n.of(
                                      context,
                                    ).flowsYourSkillsSubtitle,
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FluxPillButton(
                                      key: const Key('new-skill-button'),
                                      label: L10n.of(context).flowsNewSkill,
                                      icon: FluxIcons.add,
                                      onTap: _editSkill,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (custom.isEmpty)
                                    const _EmptyCustomSkills()
                                  else
                                    ...custom.map(
                                      (flow) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: _SkillCard(
                                          flow: flow,
                                          onToggle: (value) =>
                                              _store.setEnabled(flow.id, value),
                                          onEdit: () => _editSkill(flow),
                                          onDelete: () => _delete(flow),
                                          onRun: () => _run(flow),
                                          onGrantChanged: (value) =>
                                              _store.setGranted(flow.id, value),
                                          runs: _store.runsOf(flow.id),
                                          isRunning: _runningId == flow.id,
                                        ),
                                      ),
                                    ),
                                  if (_store.failure != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _skillFailureMessage(
                                        context,
                                        _store.failure!,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: FluxColors.destructiveOf(
                                              context,
                                            ),
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: FinnPageHeader(
                    title: L10n.of(context).flowsTitle,
                    onBack: widget.onBack,
                    metrics: metrics,
                    scrollOffset: _scrollOffset,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Resolves a store failure code to the sentence the user reads.
///
/// The store reports a code rather than a message so this lookup can pick the
/// active locale; reading and writing share the "could not be saved" sentence
/// because there is no separate localized key for a read failure.
String _skillFailureMessage(BuildContext context, FlowsFailure failure) {
  final l10n = L10n.of(context);
  return switch (failure) {
    FlowsFailure.limit => l10n.flowsLimitReached,
    FlowsFailure.load || FlowsFailure.save => l10n.flowsSaveFailed,
  };
}

/// Localized label for a flow category. Unknown categories (e.g. user-entered
/// ones persisted by older builds) fall back to the raw value.
String _categoryLabel(BuildContext context, String category) =>
    switch (category) {
      'Writing' => L10n.of(context).flowsCategoryWriting,
      'Development' => L10n.of(context).flowsCategoryDevelopment,
      'Learning' => L10n.of(context).flowsCategoryLearning,
      'Planning' => L10n.of(context).flowsCategoryPlanning,
      'Custom' => L10n.of(context).flowsCategoryCustom,
      _ => category,
    };
