import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_editor_page.dart';
import 'package:finn_ai/src/features/flows/flow_new.dart';
import 'package:finn_ai/src/features/flows/flow_run_page.dart';
import 'package:finn_ai/src/features/flows/flow_tile.dart';
import 'package:finn_ai/src/features/flows/flow_runner.dart';
import 'package:finn_ai/src/features/flows/flow_scheduler.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/widgets/finn_create_button.dart';
import 'package:finn_ai/src/shared/widgets/finn_skeleton.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

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
    _search.dispose();
    _actions.dispose();
    super.dispose();
  }

  final _search = TextEditingController();

  /// Two columns of tiles, with the app's 10dp gutter.
  Widget _grid(List<Widget> tiles) => Column(
        children: [
          for (var i = 0; i < tiles.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < tiles.length
                      ? tiles[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ],
      );

  Future<void> _run(FinnFlow flow) async {
    final run = await _actions.run(context, flow);
    if (run == null || !mounted) return;
    unawaited(
      Navigator.of(context).push(
        FinnPageRoute<void>(
          child: FlowRunPage(flow: flow, run: run, actions: _actions),
        ),
      ),
    );
  }

  Future<void> _newFlow([Rect? origin]) =>
      showNewFlow(context, _actions, origin: origin);

  void _open(FinnFlow flow) => Navigator.of(context).push(
        FinnPageRoute<void>(
          child: FlowEditorPage(flowId: flow.id, actions: _actions),
        ),
      );

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
            children: const [FinnSkeletonList()],
          );
        }
        final automations =
            _store.flows.where((flow) => flow.isAutomation).toList();
        final shown = automations
            .where(
              (flow) => switch (_filter) {
                _Filter.all => true,
                _Filter.active => flow.enabled,
                _Filter.paused => !flow.enabled,
              },
            )
            .toList();
        final query = _search.text.trim().toLowerCase();
        final searched = query.isEmpty
            ? shown
            : shown
                .where((flow) =>
                    flow.name.toLowerCase().contains(query) ||
                    flow.description.toLowerCase().contains(query))
                .toList();
        return FinnPage(
          title: l10n.flowsTitle,
          onBack: widget.onBack,
          footer: FinnCreateButton(
            key: const Key('add-flow-button'),
            label: l10n.flowsNewTitle,
            onTapFrom: (origin) => unawaited(_newFlow(origin)),
          ),
          children: [
            if (automations.isEmpty)
              FinnReveal(child: _Empty(onCreate: _newFlow))
            else ...[
              // Like the Shortcuts library: search first, then the tiles.
              FluxPillField(
                key: const Key('flows-search'),
                controller: _search,
                hint: l10n.searchHint,
                onChanged: (_) => setState(() {}),
                leading: FluxIcon(
                  icon: FluxIcons.search,
                  size: 20,
                  color: FluxColors.mutedOf(context),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
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
              ),
              _grid([
                for (var i = 0; i < searched.length; i++)
                  FinnReveal(
                    index: i,
                    child: FlowTile(
                      flow: searched[i],
                      actions: _actions,
                      onTap: () => _open(searched[i]),
                      onRun: () => unawaited(_run(searched[i])),
                    ),
                  ),
              ]),
              if (searched.isEmpty) FinnCaption(l10n.flowsSearchEmpty),
            ],
            if (_store.failure != null) FinnCaption(l10n.flowsSaveFailed),
          ],
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});

  final Future<void> Function([Rect? origin]) onCreate;

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
        // The sheet grows out of the button.
        Builder(
          builder: (button) => FinnButton(
            label: l10n.flowsEmptyCreate,
            icon: FluxIcons.add,
            onTap: () => unawaited(onCreate(globalRectOfContext(button))),
          ),
        ),
      ],
    );
  }
}
