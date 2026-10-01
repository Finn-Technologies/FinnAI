import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_intent.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flow_new.dart';
import 'package:finn_ai/src/features/flows/flow_templates.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// "Describe it": write a sentence, get the flow it means, then turn it on.
class FlowBuilderPage extends StatefulWidget {
  const FlowBuilderPage({super.key, required this.actions});

  final FlowsActions actions;

  @override
  State<FlowBuilderPage> createState() => _FlowBuilderPageState();
}

class _FlowBuilderPageState extends State<FlowBuilderPage> {
  final TextEditingController _input = TextEditingController();
  String? _said;
  FlowIntent? _intent;
  bool _noMatch = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _said = text;
      _intent = FlowIntent.parse(text);
      _noMatch = _intent == null;
      _input.clear();
    });
  }

  FinnFlow? _preview() {
    final intent = _intent;
    if (intent == null) return null;
    return intent.template.build(
      'preview',
      SlotSanitizer.sanitize(intent.template.slots, intent.slots),
      trigger: intent.trigger,
    );
  }

  Future<void> _turnOn() async {
    final flow = _preview();
    final intent = _intent;
    if (flow == null || intent == null) return;
    final saved = await widget.actions.add(context, flow);
    if (saved == null || !mounted) return;
    if (saved.hasDeviceAction) {
      await widget.actions.setGranted(context, saved, true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final flow = _preview();
    final actions = widget.actions;
    final bubble = BoxDecoration(
      color: FluxColors.controlOf(context),
      borderRadius: BorderRadius.circular(100),
    );
    return FinnPage(
      title: l10n.flowsNewTitle,
      spacing: 20,
      footer: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('flow-builder-input'),
              controller: _input,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: l10n.flowsBuilderHint,
                filled: true,
                fillColor: FluxColors.controlOf(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FinnCircleButton.icon(
            icon: FluxIcons.arrowUp01,
            label: l10n.chatSend,
            dark: true,
            onTap: _send,
          ),
        ],
      ),
      children: [
        if (_said != null)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: bubble,
              child: Text(
                _said!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        if (_noMatch) ...[
          Text(
            l10n.flowsBuilderNoMatch,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          for (final template in FlowTemplates.all)
            FinnTile(
              title: flowTemplateName(context, template.id),
              subtitle: flowTemplateBody(context, template.id),
              onTap: () async {
                final navigator = Navigator.of(context);
                final saved =
                    await editTemplateFlow(context, actions, template);
                if (saved != null) navigator.pop();
              },
            ),
        ],
        if (flow != null) ...[
          FinnReveal(
            child: Text(
              l10n.flowsBuilderHere,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          FinnReveal(
            index: 1,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: FluxColors.controlOf(context),
                borderRadius: BorderRadius.circular(FluxRadius.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(flow.name,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  _label(context, l10n.flowsWhen),
                  Text(flowScheduleLabel(context, flow.trigger)),
                  const SizedBox(height: 12),
                  _label(context, l10n.flowsThen),
                  for (var i = 0; i < flow.steps.length; i++)
                    Text('${i + 1}. ${flowStepLabel(l10n, flow.steps[i])}'),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: FinnButton(
                  key: const Key('flow-builder-turn-on'),
                  label: l10n.flowsBuilderTurnOn,
                  onTap: () => unawaited(_turnOn()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FinnButton(
                  label: l10n.flowsMenuEdit,
                  secondary: true,
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    final intent = _intent!;
                    final saved = await editTemplateFlow(
                      context,
                      actions,
                      intent.template,
                      trigger: intent.trigger,
                      initial: intent.slots,
                    );
                    if (saved != null) navigator.pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: FluxColors.actionOf(context),
            ),
      );
}
