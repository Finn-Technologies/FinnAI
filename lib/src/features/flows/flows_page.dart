import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/features/flows/flow_runner.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';

class FlowsPage extends StatefulWidget {
  const FlowsPage({super.key, required this.onBack, this.store, this.runner});

  final VoidCallback onBack;
  final FlowsStore? store;

  /// Runs a flow on the spot. Injected so the page can be driven in a widget
  /// test without the engine, and so the page has no opinion about how a flow
  /// is executed.
  final FlowRunner? runner;

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

  FlowRunner get _runner => widget.runner ?? FlowRunner(store: _store);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _store.initialize();
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
      await _runner.run(flow, granted: permitted);
    } finally {
      if (mounted) setState(() => _runningId = null);
    }
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
                onPressed: _editSkill,
                backgroundColor: FluxColors.inkOf(context),
                foregroundColor: FluxColors.canvasOf(context),
                elevation: 0,
                shape: const StadiumBorder(),
                icon: FluxIcon(
                  icon: FluxIcons.add,
                  size: 20,
                  color: FluxColors.canvasOf(context),
                ),
                label: Text(L10n.of(context).flowsNewSkill),
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
                      final custom =
                          _store.flows.where((flow) => !flow.builtIn).toList();
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

class _SkillsSummary extends StatelessWidget {
  const _SkillsSummary({required this.active, required this.total});

  final int active;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: FluxColors.cardOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.sheet),
          border: Border.all(color: FluxColors.lineOf(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FluxColors.surfaceOf(context),
              ),
              child: Center(child: FluxIcon(icon: FluxIcons.flows, size: 23)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active == 0
                        ? L10n.of(context).flowsNoneActive
                        : L10n.of(context).flowsActiveCount(active),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    L10n.of(context).flowsSubtitle(total),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: FluxColors.mutedOf(context),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FluxColors.mutedOf(context),
                  height: 1.35,
                ),
          ),
        ],
      );
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.flow,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onRun,
    this.onGrantChanged,
    this.runs = const [],
    this.isRunning = false,
  });

  final FinnFlow flow;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Runs the flow once, on the spot. Always asks before any device action.
  final VoidCallback? onRun;

  final ValueChanged<bool>? onGrantChanged;
  final List<FlowRun> runs;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: FluxColors.cardOf(context),
        borderRadius: BorderRadius.circular(FluxRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(FluxRadius.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FluxColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(FluxRadius.sm),
                ),
                child: Center(
                  child: FluxIcon(
                    icon: _iconFor(flow.category),
                    size: 20,
                    color: FluxColors.inkOf(context),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            flow.name,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                        if (!flow.builtIn)
                          PopupMenuButton<String>(
                            tooltip: L10n.of(context).flowsActionsTooltip,
                            padding: EdgeInsets.zero,
                            icon: const FluxIcon(
                              icon: FluxIcons.moreHorizontal,
                              size: 21,
                            ),
                            onSelected: (value) {
                              if (value == 'edit') onEdit?.call();
                              if (value == 'delete') onDelete?.call();
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                  value: 'edit',
                                  child: Text(L10n.of(context).commonEdit)),
                              PopupMenuItem(
                                  value: 'delete',
                                  child: Text(L10n.of(context).commonDelete)),
                            ],
                          ),
                      ],
                    ),
                    if (flow.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        flow.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: FluxColors.mutedOf(context),
                              height: 1.35,
                            ),
                      ),
                    ],
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: FluxColors.surfaceOf(context),
                            borderRadius:
                                BorderRadius.circular(FluxRadius.pill),
                          ),
                          child: Text(
                            _categoryLabel(context, flow.category),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  letterSpacing: -0.1,
                                ),
                          ),
                        ),
                        const Spacer(),
                        Semantics(
                          label: L10n.of(context).flowsNameSemantic(flow.name),
                          toggled: flow.enabled,
                          child: ExcludeSemantics(
                            child: Switch.adaptive(
                              key: Key('flow-toggle-${flow.id}'),
                              value: flow.enabled,
                              onChanged: onToggle,
                              activeTrackColor: FluxColors.inkOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (flow.steps.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _AutomationControls(
                        flow: flow,
                        isRunning: isRunning,
                        onRun: onRun,
                        onGrantChanged: onGrantChanged,
                      ),
                    ],
                    if (runs.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _RunHistory(runs: runs),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<List<dynamic>> _iconFor(String category) => switch (category) {
        'Writing' => FluxIcons.note,
        'Development' => FluxIcons.sourceCode,
        'Learning' => FluxIcons.education,
        'Planning' => FluxIcons.task,
        _ => FluxIcons.magic,
      };
}

/// The controls that make a flow an automation rather than a preference: when
/// it runs, whether it may run by itself, and a button to run it now.
class _AutomationControls extends StatelessWidget {
  const _AutomationControls({
    required this.flow,
    required this.isRunning,
    this.onRun,
    this.onGrantChanged,
  });

  final FinnFlow flow;
  final bool isRunning;
  final VoidCallback? onRun;
  final ValueChanged<bool>? onGrantChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final canAct = flow.hasDeviceAction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FluxPillButton(
              key: Key('flow-run-${flow.id}'),
              label: isRunning ? l10n.flowsRunRunning : l10n.flowsRunAction,
              onTap: isRunning ? null : onRun,
            ),
            FluxChip(
              key: Key('flow-steps-${flow.id}'),
              label: l10n.flowsStepCount(flow.steps.length),
              onTap: null,
            ),
            if (flow.trigger.isScheduled)
              FluxChip(
                key: Key('flow-schedule-${flow.id}'),
                label: _scheduleLabel(context, flow.trigger),
                onTap: null,
              ),
          ],
        ),
        if (canAct) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.flowsGrantLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FluxColors.inkOf(context),
                      ),
                ),
              ),
              Semantics(
                label: l10n.flowsGrantLabel,
                toggled: flow.granted,
                child: ExcludeSemantics(
                  child: Switch.adaptive(
                    key: Key('flow-grant-${flow.id}'),
                    value: flow.granted,
                    onChanged: onGrantChanged,
                    activeTrackColor: FluxColors.inkOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.flowsGrantExplain,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FluxColors.secondaryInkOf(context),
                  height: 1.35,
                ),
          ),
        ],
      ],
    );
  }

  String _scheduleLabel(BuildContext context, FlowTrigger trigger) {
    final l10n = L10n.of(context);
    final time = '${trigger.hour.toString().padLeft(2, '0')}:'
        '${trigger.minute.toString().padLeft(2, '0')}';
    if (trigger.daysOfWeek.isEmpty) {
      return l10n.flowsScheduleDaily(time);
    }
    return l10n.flowsScheduleWeekly(_weekdays(context, trigger), time);
  }

  String _weekdays(BuildContext context, FlowTrigger trigger) {
    // Uses intl's locale data rather than shipping weekday names in five ARB
    // files. A weekly trigger is the only place they are needed, and adding
    // seven strings per locale for one label is a bad trade.
    final names = DateFormat.EEEE(L10n.of(context).localeName);
    return [
      for (final day in trigger.daysOfWeek.toList()..sort())
        if (day >= 1 && day <= 7) names.format(DateTime(2026, 1, 5 + day - 1)),
    ].join(', ');
  }
}

/// What an automation did, and whether the user or the schedule did it.
///
/// A flow that runs by itself is something that happened *to* the user, so
/// being able to see that it did — and what it did — is the difference between
/// an automation and a surprise.
class _RunHistory extends StatelessWidget {
  const _RunHistory({required this.runs});

  final List<FlowRun> runs;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.flowsHistoryTitle,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: FluxColors.mutedOf(context),
              ),
        ),
        const SizedBox(height: 6),
        for (final run in runs.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                FluxIcon(
                  icon: run.outcome == FlowRunOutcome.completed
                      ? FluxIcons.check
                      : FluxIcons.error,
                  size: 14,
                  color: run.outcome == FlowRunOutcome.completed
                      ? FluxColors.successOf(context)
                      : FluxColors.warningOf(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_outcomeLabel(context, run.outcome)} · '
                    '${run.triggeredBy == 'schedule' ? l10n.flowsRunBySchedule : l10n.flowsRunByYou}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FluxColors.secondaryInkOf(context),
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _outcomeLabel(BuildContext context, FlowRunOutcome outcome) {
    final l10n = L10n.of(context);
    return switch (outcome) {
      FlowRunOutcome.completed => l10n.flowsRunCompleted,
      FlowRunOutcome.declined => l10n.flowsRunDeclined,
      FlowRunOutcome.failed => l10n.flowsRunFailed,
      FlowRunOutcome.interrupted => l10n.flowsRunInterrupted,
      // The one a user can act on: the flow wanted to run by itself and was
      // not allowed to.
      FlowRunOutcome.needsGrant => l10n.flowsNeedsGrant,
    };
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

class _EmptyCustomSkills extends StatelessWidget {
  const _EmptyCustomSkills();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: BoxDecoration(
          color: FluxColors.surfaceOf(context).withValues(alpha: .65),
          borderRadius: BorderRadius.circular(FluxRadius.card),
          border: Border.all(color: FluxColors.lineOf(context)),
        ),
        child: Text(
          L10n.of(context).flowsNoSkills,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: FluxColors.mutedOf(context)),
        ),
      );
}

class _SkillDraft {
  const _SkillDraft({
    required this.name,
    required this.description,
    required this.instructions,
  });

  final String name;
  final String description;
  final String instructions;
}

class _SkillEditor extends StatefulWidget {
  const _SkillEditor({this.flow});
  final FinnFlow? flow;

  @override
  State<_SkillEditor> createState() => _SkillEditorState();
}

class _SkillEditorState extends State<_SkillEditor> {
  late final _name = TextEditingController(text: widget.flow?.name ?? '');
  late final _description = TextEditingController(
    text: widget.flow?.description ?? '',
  );
  late final _instructions = TextEditingController(
    text: widget.flow?.instructions ?? '',
  );

  bool get _valid =>
      _name.text.trim().isNotEmpty && _instructions.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _instructions.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: FluxColors.canvasOf(context),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(FluxRadius.sheet)),
        ),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: FluxColors.lineOf(context),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.flow == null
                        ? L10n.of(context).flowsNewSkill
                        : L10n.of(context).flowsEditTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    L10n.of(context).flowsInstructionHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: FluxColors.mutedOf(context),
                        ),
                  ),
                  const SizedBox(height: 18),
                  _EditorField(
                    key: const Key('flow-name-field'),
                    controller: _name,
                    label: L10n.of(context).flowsEditorName,
                    hint: L10n.of(context).flowsEditorNameHint,
                    maxLength: 60,
                  ),
                  const SizedBox(height: 10),
                  _EditorField(
                    controller: _description,
                    label: L10n.of(context).flowsEditorDescription,
                    hint: L10n.of(context).flowsEditorDescriptionHint,
                    maxLength: 140,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  _EditorField(
                    key: const Key('flow-instructions-field'),
                    controller: _instructions,
                    label: L10n.of(context).flowsEditorInstructions,
                    hint: L10n.of(context).flowsEditorInstructionsHint,
                    maxLength: 500,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const Key('save-flow-button'),
                      onPressed: _valid
                          ? () => Navigator.pop(
                                context,
                                _SkillDraft(
                                  name: _name.text,
                                  description: _description.text,
                                  instructions: _instructions.text,
                                ),
                              )
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: FluxColors.inkOf(context),
                        foregroundColor: FluxColors.canvasOf(context),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Text(L10n.of(context).commonSaveFlow),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.maxLength,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: FluxColors.mutedOf(context)),
          filled: true,
          fillColor: FluxColors.cardOf(context),
          contentPadding: const EdgeInsets.all(16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FluxRadius.md),
            borderSide: BorderSide(color: FluxColors.lineOf(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FluxRadius.md),
            borderSide: BorderSide(color: FluxColors.inkOf(context)),
          ),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FluxRadius.md)),
        ),
      );
}
