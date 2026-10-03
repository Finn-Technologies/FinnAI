import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_runner.dart';
import 'package:finn_ai/src/features/flows/flow_scheduler.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';

/// What the Flows screens do to a flow, in one place.
///
/// The list, the detail page and the builder all turn flows on, run them and
/// delete them. Giving each its own copy meant the notification prompt and the
/// "ask before acting" rule could drift between screens.
class FlowsActions extends ChangeNotifier {
  FlowsActions({
    required this.store,
    this.runner,
    this.scheduler,
    this.onOpenResult,
  });

  final FlowsStore store;
  final FlowRunner? runner;
  final FlowScheduler? scheduler;
  final VoidCallback? onOpenResult;

  /// The flow running right now, if any. One at a time: two concurrent runs
  /// would attribute their device actions to each other.
  String? runningId;

  /// Whether the OS will show notifications. Null until known.
  bool? notificationsOn;

  FlowRunner get _runner => runner ?? FlowRunner(store: store);

  Future<void> refreshNotifications() async {
    final allowed = await scheduler?.backend.notificationsAllowed();
    notificationsOn = allowed ?? true;
    notifyListeners();
  }

  /// Runs a flow once, on the spot. A manual run asks before any device
  /// action: the grant lets a flow act when the user is not looking, and here
  /// the user is looking, so one tap stands in for it.
  Future<FlowRun?> run(BuildContext context, FinnFlow flow) async {
    if (runningId != null) return null;
    runningId = flow.id;
    notifyListeners();
    try {
      var permitted = true;
      if (flow.hasDeviceAction) {
        permitted = await showFinnConfirm(
              context,
              title: L10n.of(context).flowsAllowTitle(flow.name),
              body: L10n.of(context).flowsGrantExplain,
              confirmLabel: L10n.of(context).flowsRunAction,
            ) ??
            false;
      }
      return await _runner.run(flow, granted: permitted);
    } finally {
      runningId = null;
      notifyListeners();
    }
  }

  /// Whether the flow needs the platform to wake it (an alarm or an event
  /// listener), which is when notification permission matters.
  static bool _needsPlatform(FinnFlow flow) =>
      flow.triggers.any((t) => t.isScheduled || t.isEvent);

  /// Turning a triggered flow on is the moment to ask for notifications;
  /// turning it off just disarms it.
  Future<void> setEnabled(BuildContext context, FinnFlow flow, bool on) async {
    await store.setEnabled(flow.id, on);
    if (on && _needsPlatform(flow) && context.mounted) {
      await ensureNotifications(context);
    }
    await scheduler?.sync(store.flows);
    await refreshNotifications();
  }

  /// Tell the user why, then ask. Asking at first use, never at install, is the
  /// point.
  Future<bool> ensureNotifications(BuildContext context) async {
    final s = scheduler;
    if (s == null) return false;
    if (await s.backend.notificationsAllowed()) return true;
    if (!context.mounted) return false;
    final l10n = L10n.of(context);
    final agreed = await showFinnConfirm(
      context,
      title: l10n.flowsNotifyWhyTitle,
      body: l10n.flowsNotifyWhyBody,
      confirmLabel: l10n.flowsNotifyAllow,
      cancelLabel: l10n.commonNotNow,
    );
    if (agreed != true) return false;
    final granted = await s.ensurePermission();
    await refreshNotifications();
    return granted;
  }

  /// Saves changes to a flow (its name, blocks, triggers or conditions) and
  /// keeps the platform's alarms and listeners in step.
  ///
  /// Every edit saves at once: there is no draft to lose. Returns false when
  /// the store refused the write.
  Future<bool> update(
    BuildContext context,
    FinnFlow flow, {
    String? name,
    List<FlowBlock>? blocks,
    List<FlowTrigger>? triggers,
    List<FlowCondition>? conditions,
  }) async {
    final saved = await store.upsertCustom(
      id: flow.id,
      name: name ?? flow.name,
      description: flow.description,
      instructions: flow.instructions,
      category: flow.category,
      enabled: flow.enabled,
      blocks: blocks ?? flow.blocks,
      triggers: triggers ?? flow.triggers,
      conditions: conditions ?? flow.conditions,
    );
    if (!saved) return false;
    final after = store.flows.where((f) => f.id == flow.id).firstOrNull;
    if (after != null &&
        after.enabled &&
        _needsPlatform(after) &&
        context.mounted) {
      await ensureNotifications(context);
    }
    await scheduler?.sync(store.flows);
    await refreshNotifications();
    return true;
  }

  /// Saves a new flow (from a template, a sentence or a blank page). It starts
  /// turned off: the user checks it, then turns it on.
  Future<FinnFlow?> add(
    BuildContext context,
    FinnFlow flow, {
    bool enabled = false,
  }) async {
    final saved = await store.upsertCustom(
      name: flow.name,
      description: flow.description,
      instructions: '',
      category: flow.category,
      enabled: enabled,
      blocks: flow.blocks,
      triggers: flow.triggers,
      conditions: flow.conditions,
    );
    if (!saved) return null;
    final added = store.flows.last;
    if (enabled && _needsPlatform(added) && context.mounted) {
      await ensureNotifications(context);
    }
    await scheduler?.sync(store.flows);
    await refreshNotifications();
    return added;
  }

  /// Grants or revokes the standing permission to act on the phone, asking
  /// first when granting.
  Future<void> setGranted(BuildContext context, FinnFlow flow, bool on) async {
    if (on) {
      final l10n = L10n.of(context);
      final ok = await showFinnConfirm(
        context,
        title: l10n.flowsAllowTitle(flow.name),
        body: l10n.flowsGrantExplain,
        confirmLabel: l10n.flowsAllowConfirm,
        cancelLabel: l10n.commonNotNow,
      );
      if (ok != true) return;
    }
    await store.setGranted(flow.id, on);
  }

  /// Turns a flow on from somewhere other than its own page (a card in a chat),
  /// asking for what it needs first: a flow that changes the phone and starts
  /// by itself must be allowed to, in so many words, before it is switched on.
  /// False when the user said no.
  Future<bool> turnOn(BuildContext context, FinnFlow flow) async {
    final auto = flow.triggers.any((t) => t.isScheduled || t.isEvent);
    if (flow.hasDeviceAction && auto && !flow.granted) {
      await setGranted(context, flow, true);
      final now = store.flows.where((f) => f.id == flow.id).firstOrNull;
      if (now == null || !now.granted) return false;
    }
    if (!context.mounted) return false;
    final current = store.flows.where((f) => f.id == flow.id).firstOrNull;
    if (current == null) return false;
    await setEnabled(context, current, true);
    return true;
  }

  Future<bool> delete(BuildContext context, FinnFlow flow) async {
    final l10n = L10n.of(context);
    final ok = await showFinnConfirm(
      context,
      title: l10n.flowsDeleteNamed(flow.name),
      body: l10n.flowsDeleteNamedBody,
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (ok != true) return false;
    await store.removeCustom(flow.id);
    await scheduler?.sync(store.flows);
    return true;
  }

  Future<void> duplicate(FinnFlow flow) async {
    await store.upsertCustom(
      name: '${flow.name} 2',
      description: flow.description,
      instructions: flow.instructions,
      category: flow.category,
      enabled: false,
      blocks: flow.blocks,
      triggers: flow.triggers,
      conditions: flow.conditions,
    );
  }
}
