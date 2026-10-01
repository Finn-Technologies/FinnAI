import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_builder_page.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flow_schedule_sheet.dart';
import 'package:finn_ai/src/features/flows/flow_templates.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

String flowTemplateName(BuildContext context, String id) {
  final l10n = L10n.of(context);
  return switch (id) {
    'morning_brief' => l10n.flowsTemplateMorningBrief,
    'web_check' => l10n.flowsTemplateWebCheck,
    'reminder' => l10n.flowsTemplateReminder,
    _ => id,
  };
}

String flowTemplateBody(BuildContext context, String id) {
  final l10n = L10n.of(context);
  return switch (id) {
    'morning_brief' => l10n.flowsTemplateMorningBriefBody,
    'web_check' => l10n.flowsTemplateWebCheckBody,
    'reminder' => l10n.flowsTemplateReminderBody,
    _ => '',
  };
}

String flowSlotName(BuildContext context, String key) {
  final l10n = L10n.of(context);
  return switch (key) {
    'topics' => l10n.flowsSlotTopics,
    'city' => l10n.flowsSlotCity,
    'topic' => l10n.flowsSlotTopic,
    'message' => l10n.flowsSlotMessage,
    _ => key,
  };
}

/// The "New flow" sheet: describe it, pick a time, or pick an event.
Future<void> showNewFlow(BuildContext context, FlowsActions actions) {
  final l10n = L10n.of(context);
  return showFinnSheet<void>(
    context,
    title: l10n.flowsNewTitle,
    subtitle: l10n.flowsNewSub,
    children: (sheet) => [
      FinnTile(
        key: const Key('flow-new-describe'),
        icon: FluxIcons.edit,
        title: l10n.flowsNewDescribe,
        subtitle: l10n.flowsNewDescribeSub,
        onTap: () {
          Navigator.pop(sheet);
          Navigator.of(context).push(
            FinnPageRoute<void>(child: FlowBuilderPage(actions: actions)),
          );
        },
      ),
      const SizedBox(height: 10),
      FinnTile(
        key: const Key('flow-new-time'),
        icon: FluxIcons.alarm,
        title: l10n.flowsNewTime,
        subtitle: l10n.flowsNewTimeSub,
        onTap: () {
          Navigator.pop(sheet);
          unawaited(pickTemplateFlow(context, actions));
        },
      ),
      const SizedBox(height: 10),
      FinnTile(
        key: const Key('flow-new-event'),
        icon: FluxIcons.flows,
        title: l10n.flowsNewEvent,
        subtitle: l10n.flowsNewEventSub,
        onTap: () {
          Navigator.pop(sheet);
          Navigator.of(context).push(
            FinnPageRoute<void>(child: FlowTriggersPage(actions: actions)),
          );
        },
      ),
    ],
  );
}

/// Picks a template, fills its slots and saves the flow with [trigger].
Future<void> pickTemplateFlow(
  BuildContext context,
  FlowsActions actions, {
  FlowTrigger? trigger,
}) async {
  final l10n = L10n.of(context);
  final template = await showFinnSheet<FlowTemplate>(
    context,
    title: l10n.flowsNewAutomation,
    children: (sheet) => [
      for (final template in FlowTemplates.all) ...[
        FinnTile(
          key: Key('flow-template-${template.id}'),
          title: flowTemplateName(sheet, template.id),
          subtitle: flowTemplateBody(sheet, template.id),
          onTap: () => Navigator.pop(sheet, template),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );
  if (template == null || !context.mounted) return;
  await editTemplateFlow(context, actions, template, trigger: trigger);
}

/// Slots and a schedule for one template, then save. Returns the new flow.
Future<FinnFlow?> editTemplateFlow(
  BuildContext context,
  FlowsActions actions,
  FlowTemplate template, {
  FlowTrigger? trigger,
  Map<String, String> initial = const {},
}) async {
  final draft = await showFinnSheet<({SlotValues values, FlowTrigger trigger})>(
    context,
    title: flowTemplateName(context, template.id),
    children: (_) => [
      _SlotsBody(template: template, trigger: trigger, initial: initial),
    ],
  );
  if (draft == null || !context.mounted) return null;
  final flow = template.build(
    'custom-${DateTime.now().microsecondsSinceEpoch}',
    draft.values,
    trigger: draft.trigger,
  );
  return actions.add(context, flow);
}

class _SlotsBody extends StatefulWidget {
  const _SlotsBody({
    required this.template,
    required this.trigger,
    required this.initial,
  });

  final FlowTemplate template;
  final FlowTrigger? trigger;
  final Map<String, String> initial;

  @override
  State<_SlotsBody> createState() => _SlotsBodyState();
}

class _SlotsBodyState extends State<_SlotsBody> {
  final Map<String, TextEditingController> _controllers = {};
  late FlowTrigger _trigger = widget.trigger ?? widget.template.defaultTrigger;

  @override
  void initState() {
    super.initState();
    for (final slot in widget.template.slots) {
      _controllers[slot.key] = TextEditingController(
        text: widget.initial[slot.key] ?? '${slot.fallback}',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slot in widget.template.slots) ...[
          TextField(
            key: Key('flow-slot-${slot.key}'),
            controller: _controllers[slot.key],
            maxLength: slot.maxChars,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              labelText: flowSlotName(context, slot.key),
              counterText: '',
              filled: true,
              fillColor: FluxColors.controlOf(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        FinnTile(
          key: const Key('flow-schedule-chip'),
          icon: FluxIcons.alarm,
          title: flowScheduleLabel(context, _trigger),
          onTap: () async {
            final picked = await showFlowSchedule(context, _trigger);
            if (picked != null) setState(() => _trigger = picked);
          },
        ),
        const SizedBox(height: 12),
        FinnButton(
          key: const Key('flow-automation-save'),
          label: l10n.commonSave,
          onTap: () => Navigator.pop(context, (
            values: SlotSanitizer.sanitize(widget.template.slots, {
              for (final e in _controllers.entries) e.key: e.value.text,
            }),
            trigger: _trigger,
          )),
        ),
      ],
    );
  }
}

/// "Start when": the ways a flow can begin.
class FlowTriggersPage extends StatelessWidget {
  const FlowTriggersPage({super.key, required this.actions});

  final FlowsActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    Widget soon(List<List<dynamic>> icon, String title, String sub) => Opacity(
          opacity: .55,
          child: FinnTile(
            icon: icon,
            title: title,
            subtitle: '$sub\n${l10n.flowsTriggerSoon}',
          ),
        );
    return FinnPage(
      title: l10n.flowsStartWhen,
      children: [
        FinnTile(
          icon: FluxIcons.alarm,
          title: l10n.flowsTriggerTime,
          subtitle: l10n.flowsTriggerTimeSub,
          onTap: () {
            final host = Navigator.of(context);
            host.pop();
            unawaited(pickTemplateFlow(host.context, actions));
          },
        ),
        soon(FluxIcons.flag, l10n.flowsTriggerPlace, l10n.flowsTriggerPlaceSub),
        soon(
          FluxIcons.bluetooth,
          l10n.flowsTriggerCharging,
          l10n.flowsTriggerChargingSub,
        ),
        soon(
          FluxIcons.cpu,
          l10n.flowsTriggerBattery,
          l10n.flowsTriggerBatterySub,
        ),
        soon(
          FluxIcons.alarm,
          l10n.flowsTriggerNotification,
          l10n.flowsTriggerNotificationSub,
        ),
        FinnTile(
          icon: FluxIcons.arrowRight02,
          title: l10n.flowsTriggerManual,
          subtitle: l10n.flowsTriggerManualSub,
          onTap: () {
            final host = Navigator.of(context);
            host.pop();
            unawaited(
              pickTemplateFlow(
                host.context,
                actions,
                trigger: const FlowTrigger.manual(),
              ),
            );
          },
        ),
      ],
    );
  }
}
