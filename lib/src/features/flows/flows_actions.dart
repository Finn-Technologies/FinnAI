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

  /// Turning a scheduled flow on is the moment to ask for notifications;
  /// turning it off just disarms it.
  Future<void> setEnabled(BuildContext context, FinnFlow flow, bool on) async {
    await store.setEnabled(flow.id, on);
    if (on && flow.trigger.isScheduled && context.mounted) {
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

  Future<void> setTrigger(
    BuildContext context,
    FinnFlow flow,
    FlowTrigger trigger,
  ) async {
    await store.upsertCustom(
      id: flow.id,
      name: flow.name,
      description: flow.description,
      instructions: flow.instructions,
      category: flow.category,
      enabled: flow.enabled,
      steps: flow.steps,
      trigger: trigger,
    );
    if (trigger.isScheduled && context.mounted) {
      await ensureNotifications(context);
    }
    await scheduler?.sync(store.flows);
    await refreshNotifications();
  }

  /// Saves a flow built from a template and arms it.
  Future<FinnFlow?> add(BuildContext context, FinnFlow flow) async {
    final saved = await store.upsertCustom(
      name: flow.name,
      description: flow.description,
      instructions: '',
      category: flow.category,
      steps: flow.steps,
      trigger: flow.trigger,
    );
    if (!saved) return null;
    if (flow.trigger.isScheduled && context.mounted) {
      await ensureNotifications(context);
    }
    await scheduler?.sync(store.flows);
    await refreshNotifications();
    return store.flows.last;
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
      steps: flow.steps,
      trigger: flow.trigger,
    );
  }
}
