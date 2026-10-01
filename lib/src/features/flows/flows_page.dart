import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_detail_page.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flow_new.dart';
import 'package:finn_ai/src/features/flows/flow_runner.dart';
import 'package:finn_ai/src/features/flows/flow_scheduler.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

part 'parts/skill_editor.dart';

enum _Filter { all, active, paused }

/// Flows: the things FinnAI does for the user on a schedule or on request.
class FlowsPage extends StatefulWidget {
  const FlowsPage({
    super.key,
    required this.onBack,
    this.store,
    this.runner,
    this.scheduler,
    this.onOpenResult,
    this.startNew = false,
  });

  final VoidCallback onBack;
  final FlowsStore? store;

  /// Opens the new-flow sheet as soon as the page is up.
  final bool startNew;

  /// Runs a flow on the spot. Injected so the page can be driven in a widget
  /// test without the engine.
  final FlowRunner? runner;

  /// Arms scheduled flows and asks for notification permission. Null in tests
  /// and on platforms with no scheduler.
  final FlowScheduler? scheduler;

  /// Opens the conversation a finished run just wrote.
  final VoidCallback? onOpenResult;

  @override
  State<FlowsPage> createState() => _FlowsPageState();
}

class _FlowsPageState extends State<FlowsPage> {
  late final FlowsStore _store = widget.store ?? FlowsStore.instance;
  late final FlowsActions _actions = FlowsActions(
    store: _store,
    runner: widget.runner,
    scheduler: widget.scheduler,
    onOpenResult: widget.onOpenResult,
  );
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    unawaited(_store.initialize());
    unawaited(_actions.refreshNotifications());
    if (widget.startNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_newFlow());
      });
    }
  }

  @override
  void dispose() {
    _actions.dispose();
    super.dispose();
  }

  Future<void> _newFlow() => showNewFlow(context, _actions);

  void _open(FinnFlow flow) => Navigator.of(context).push(
        FinnPageRoute<void>(
          child: FlowDetailPage(flowId: flow.id, actions: _actions),
        ),
      );

  Future<void> _editGuide([FinnFlow? flow]) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            switch (_store.failure ?? FlowsFailure.save) {
              FlowsFailure.limit => L10n.of(context).flowsLimitReached,
              _ => L10n.of(context).flowsSaveFailed,
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_store, _actions]),
      builder: (context, _) {
        if (!_store.initialized) {
          return FinnPage(
            title: l10n.flowsTitle,
            onBack: widget.onBack,
            children: const [
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ),
              ),
            ],
          );
        }
        final automations = _store.flows
            .where((flow) => !flow.builtIn && flow.steps.isNotEmpty)
            .toList();
        final shown = automations
            .where(
              (flow) => switch (_filter) {
                _Filter.all => true,
                _Filter.active => flow.enabled,
                _Filter.paused => !flow.enabled,
              },
            )
            .toList();
        final builtIns = _store.flows.where((flow) => flow.builtIn).toList();
        final custom = _store.flows
            .where((flow) => !flow.builtIn && flow.steps.isEmpty)
            .toList();
        final plus = FinnCircleButton.icon(
          key: const Key('add-flow-button'),
          icon: FluxIcons.add,
          label: l10n.flowsNewTitle,
          onTap: () => unawaited(_newFlow()),
        );
        return FinnPage(
          title: l10n.flowsTitle,
          onBack: widget.onBack,
          actions: [plus],
          children: [
            if (automations.isEmpty)
              FinnReveal(child: _Empty(onCreate: _newFlow))
            else ...[
              Row(
                children: [
                  for (final filter in _Filter.values) ...[
                    FluxChip(
                      label: switch (filter) {
                        _Filter.all => l10n.flowsFilterAll,
                        _Filter.active => l10n.flowsFilterActive,
                        _Filter.paused => l10n.flowsFilterPaused,
                      },
                      selected: _filter == filter,
                      onTap: () => setState(() => _filter = filter),
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
              for (var i = 0; i < shown.length; i++)
                FinnReveal(
                  index: i,
                  child: _FlowRow(
                    flow: shown[i],
                    actions: _actions,
                    onTap: () => _open(shown[i]),
                  ),
                ),
              FinnCaption(l10n.flowsPhoneOn),
            ],
            const SizedBox(height: 10),
            Text(
              l10n.flowsGuidesTitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            FinnCaption(l10n.flowsBuiltForFinnSubtitle),
            for (final flow in [...builtIns, ...custom])
              FinnTile(
                icon: FluxIcons.note,
                title: flow.name,
                subtitle: flow.description,
                onTap: flow.builtIn ? null : () => unawaited(_editGuide(flow)),
                chevron: false,
                trailing: FinnSwitch(
                  key: Key('flow-toggle-${flow.id}'),
                  value: flow.enabled,
                  label: l10n.flowsNameSemantic(flow.name),
                  onChanged: (v) => unawaited(_store.setEnabled(flow.id, v)),
                ),
              ),
            FinnButton(
              key: const Key('new-skill-button'),
              label: l10n.flowsNewGuide,
              icon: FluxIcons.add,
              secondary: true,
              onTap: () => unawaited(_editGuide()),
            ),
            if (_store.failure != null)
              FinnCaption(
                switch (_store.failure!) {
                  FlowsFailure.limit => l10n.flowsLimitReached,
                  _ => l10n.flowsSaveFailed,
                },
              ),
          ],
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});

  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      children: [
        const SizedBox(height: 30),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: FluxColors.controlOf(context),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: FluxIcon(
              icon: FluxIcons.flows,
              size: 44,
              strokeWidth: 1.4,
              color: FluxColors.actionOf(context),
            ),
          ),
        ),
        const SizedBox(height: 25),
        Text(l10n.flowsEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Text(
          l10n.flowsEmptyBody,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: FluxColors.actionOf(context),
              ),
        ),
        const SizedBox(height: 25),
        FinnButton(
          label: l10n.flowsEmptyCreate,
          icon: FluxIcons.add,
          onTap: () => unawaited(onCreate()),
        ),
      ],
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.flow,
    required this.actions,
    required this.onTap,
  });

  final FinnFlow flow;
  final FlowsActions actions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final runs = actions.store.runsOf(flow.id);
    final last = runs.isEmpty ? null : runs.first;
    final lastLine = !flow.enabled
        ? l10n.flowsPausedLine
        : last == null
            ? l10n.flowsNeverRun
            : l10n.flowsLastRunLine(
                flowWhen(context, last.startedAt),
                switch (last.outcome) {
                  FlowRunOutcome.completed => l10n.flowsResultDone,
                  FlowRunOutcome.interrupted => l10n.flowsResultStopped,
                  _ => l10n.flowsResultFailed,
                },
              );
    return FinnTile(
      icon: switch (flow.steps.first.kind) {
        FlowStepKind.browse => FluxIcons.internet,
        FlowStepKind.deviceAction => FluxIcons.alarm,
        _ => FluxIcons.magic,
      },
      title: flow.name,
      subtitle: '${flowScheduleLabel(context, flow.trigger)}\n$lastLine',
      onTap: onTap,
      chevron: false,
      trailing: FinnSwitch(
        key: Key('flow-toggle-${flow.id}'),
        value: flow.enabled,
        label: l10n.flowsNameSemantic(flow.name),
        onChanged: (v) => unawaited(actions.setEnabled(context, flow, v)),
      ),
    );
  }
}
