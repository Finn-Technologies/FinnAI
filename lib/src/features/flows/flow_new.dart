import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_block_picker.dart';
import 'package:finn_ai/src/features/flows/flow_block_sheet.dart';
import 'package:finn_ai/src/features/flows/flow_describe_page.dart';
import 'package:finn_ai/src/features/flows/flow_editor_page.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flow_icons.dart';
import 'package:finn_ai/src/features/flows/flow_trigger_sheet.dart';
import 'package:finn_ai/src/features/flows/flow_templates.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

String flowTemplateName(BuildContext context, String id) {
  final l10n = L10n.of(context);
  return switch (id) {
    'morning_brief' => l10n.flowsTemplateMorningBrief,
    'web_check' => l10n.flowsTemplateWebCheck,
    'reminder' => l10n.flowsTemplateReminder,
    'low_battery' => l10n.flowsTemplateLowBattery,
    'headset_music' => l10n.flowsTemplateHeadset,
    _ => id,
  };
}

String flowTemplateBody(BuildContext context, String id) {
  final l10n = L10n.of(context);
  return switch (id) {
    'morning_brief' => l10n.flowsTemplateMorningBriefBody,
    'web_check' => l10n.flowsTemplateWebCheckBody,
    'reminder' => l10n.flowsTemplateReminderBody,
    'low_battery' => l10n.flowsTemplateLowBatteryBody,
    'headset_music' => l10n.flowsTemplateHeadsetBody,
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
    'level' => l10n.flowsSlotLevel,
    'what' => l10n.flowsSlotWhat,
    _ => key,
  };
}

/// The "New flow" sheet: describe it, start from a template, or build it
/// step by step.
Future<void> showNewFlow(
  BuildContext context,
  FlowsActions actions, {
  Rect? origin,
}) {
  final l10n = L10n.of(context);
  return showFinnSheet<void>(
    context,
    origin: origin,
    originColor: origin != null && origin.width > 120
        ? FluxColors.actionOf(context)
        : FluxColors.controlOf(context),
    originRadius: 25,
    title: l10n.flowsNewTitle,
    subtitle: l10n.flowsNewSub,
    children: (sheet) => [
      FinnTile(
        key: const Key('flow-new-describe'),
        icon: FluxIcons.magic,
        title: l10n.flowsNewDescribe,
        subtitle: l10n.flowsNewDescribeSub,
        onTap: () {
          Navigator.pop(sheet);
          Navigator.of(context).push(
            FinnPageRoute<void>(child: FlowDescribePage(actions: actions)),
          );
        },
      ),
      const SizedBox(height: 10),
      FinnTile(
        key: const Key('flow-new-template'),
        icon: FluxIcons.flows,
        title: l10n.flowsNewTemplates,
        subtitle: l10n.flowsNewTemplatesSub,
        onTap: () {
          Navigator.pop(sheet);
          unawaited(pickTemplateFlow(context, actions));
        },
      ),
      const SizedBox(height: 10),
      FinnTile(
        key: const Key('flow-new-blank'),
        icon: FluxIcons.edit,
        title: l10n.flowsNewBlank,
        subtitle: l10n.flowsNewBlankSub,
        onTap: () {
          Navigator.pop(sheet);
          unawaited(startBlankFlow(context, actions));
        },
      ),
    ],
  );
}

/// Opens a saved flow in the editor.
void openFlowEditor(BuildContext context, FlowsActions actions, String id) {
  Navigator.of(context).push(
    FinnPageRoute<void>(child: FlowEditorPage(flowId: id, actions: actions)),
  );
}

/// Names a flow, picks its first step, and opens the editor.
Future<void> startBlankFlow(BuildContext context, FlowsActions actions) async {
  final l10n = L10n.of(context);
  final name = await showFinnPrompt(
    context,
    title: l10n.flowsNewTitle,
    hint: l10n.flowsEditorNameHint,
    confirmLabel: l10n.commonSave,
  );
  if (name == null || name.trim().isEmpty || !context.mounted) return;
  final kind = await pickFlowBlockKind(context, canBranch: false);
  if (kind == null || !context.mounted) return;
  var block = newFlowBlock(kind);
  if (kind != FlowBlockKind.saveToChat && kind != FlowBlockKind.stop) {
    final edit = await editFlowBlock(context, block, isNew: true);
    if (edit?.op != FlowBlockOp.save ||
        edit?.block == null ||
        !context.mounted) {
      return;
    }
    block = edit!.block!;
  }
  final flow = await actions.add(
    context,
    FinnFlow(
      id: '',
      name: name.trim(),
      description: '',
      instructions: '',
      category: 'Automation',
      blocks: [block],
    ),
  );
  if (flow != null && context.mounted) {
    openFlowEditor(context, actions, flow.id);
  }
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
  // Made on purpose, with a time chosen in the form: it starts working.
  final added = await actions.add(context, flow, enabled: true);
  if (added != null && context.mounted) {
    openFlowEditor(context, actions, added.id);
  }
  return added;
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
          if (slot.kind == SlotKind.choice)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in slot.options)
                  FluxChip(
                    key: Key('flow-slot-${slot.key}-$option'),
                    label: switch (option) {
                      'play' => l10n.flowsSlotPlay,
                      'pause' => l10n.flowsSlotPause,
                      _ => option,
                    },
                    selected: _controllers[slot.key]!.text == option,
                    onTap: () => setState(
                      () => _controllers[slot.key]!.text = option,
                    ),
                  ),
              ],
            )
          else
            TextField(
              key: Key('flow-slot-${slot.key}'),
              controller: _controllers[slot.key],
              maxLength: slot.maxChars,
              keyboardType: slot.kind == SlotKind.integer
                  ? TextInputType.number
                  : TextInputType.text,
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
          icon: FlowIcons.forTrigger(_trigger.kind),
          title: flowTriggerLabel(l10n, _trigger),
          onTap: () async {
            final picked = await pickFlowTrigger(context, current: _trigger);
            if (picked?.trigger != null) {
              setState(() => _trigger = picked!.trigger!);
            }
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
