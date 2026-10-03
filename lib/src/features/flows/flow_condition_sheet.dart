import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

/// The user's choice in the condition sheet.
class FlowConditionPick {
  const FlowConditionPick(this.condition);

  /// The condition, or null to remove the one being edited.
  final FlowCondition? condition;
}

/// Edits one condition. Null when dismissed; a pick with no condition means
/// "remove this one" (offered only when [removable]).
///
/// [allowAnswer] adds "the answer mentions …", which only means something
/// inside a branch (a flow's own "only if" is checked before any answer
/// exists).
Future<FlowConditionPick?> pickFlowCondition(
  BuildContext context, {
  FlowCondition? initial,
  bool allowAnswer = false,
  bool removable = false,
}) {
  final l10n = L10n.of(context);
  return showFinnSheet<FlowConditionPick>(
    context,
    title: l10n.flowsEdChooseCondition,
    subtitle: allowAnswer ? null : l10n.flowsEdConditionNote,
    children: (_) => [
      _ConditionBody(
        initial: initial,
        allowAnswer: allowAnswer,
        removable: removable,
      ),
    ],
  );
}

/// [pickFlowCondition] for callers that only want the condition.
Future<FlowCondition?> editFlowCondition(
  BuildContext context, {
  FlowCondition? initial,
  bool allowAnswer = false,
}) async =>
    (await pickFlowCondition(
      context,
      initial: initial,
      allowAnswer: allowAnswer,
    ))
        ?.condition;

class _ConditionBody extends StatefulWidget {
  const _ConditionBody({
    required this.initial,
    required this.allowAnswer,
    required this.removable,
  });

  final FlowCondition? initial;
  final bool allowAnswer;
  final bool removable;

  @override
  State<_ConditionBody> createState() => _ConditionBodyState();
}

class _ConditionBodyState extends State<_ConditionBody> {
  late FlowConditionKind _kind =
      widget.initial?.kind ?? FlowConditionKind.batteryBelow;
  late int _level = switch (widget.initial?.kind) {
    FlowConditionKind.batteryBelow ||
    FlowConditionKind.batteryAbove =>
      widget.initial!.value,
    _ => 30,
  };
  late int _from = widget.initial?.kind == FlowConditionKind.timeBetween
      ? widget.initial!.value
      : 22 * 60;
  late int _to = widget.initial?.kind == FlowConditionKind.timeBetween
      ? widget.initial!.endValue
      : 7 * 60;
  late final Set<int> _days = widget.initial?.kind == FlowConditionKind.weekdays
      ? {...widget.initial!.days}
      : {1, 2, 3, 4, 5};
  late final TextEditingController _text =
      TextEditingController(text: widget.initial?.text ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<FlowConditionKind> get _kinds => [
        for (final kind in FlowConditionKind.values)
          if (kind != FlowConditionKind.answerContains || widget.allowAnswer)
            kind,
      ];

  FlowCondition get _result => switch (_kind) {
        FlowConditionKind.batteryBelow => FlowCondition.batteryBelow(_level),
        FlowConditionKind.batteryAbove => FlowCondition.batteryAbove(_level),
        FlowConditionKind.timeBetween => FlowCondition.timeBetween(_from, _to),
        FlowConditionKind.weekdays => FlowCondition.weekdays({..._days}),
        FlowConditionKind.answerContains =>
          FlowCondition.answerContains(_text.text.trim()),
        _ => FlowCondition(_kind),
      };

  Future<void> _pickTime({required bool start}) async {
    final minutes = start ? _from : _to;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    setState(() {
      final value = picked.hour * 60 + picked.minute;
      if (start) {
        _from = value;
      } else {
        _to = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final canSave = _result.isValid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in _kinds)
              FluxChip(
                key: Key('condition-kind-${kind.name}'),
                label: flowConditionLabel(
                  l10n,
                  switch (kind) {
                    FlowConditionKind.batteryBelow ||
                    FlowConditionKind.batteryAbove =>
                      FlowCondition(kind, value: _level),
                    FlowConditionKind.timeBetween =>
                      FlowCondition.timeBetween(_from, _to),
                    FlowConditionKind.weekdays => FlowCondition.weekdays(_days),
                    FlowConditionKind.answerContains =>
                      FlowCondition.answerContains(
                        _text.text.isEmpty ? '…' : _text.text,
                      ),
                    _ => FlowCondition(kind),
                  },
                ),
                selected: _kind == kind,
                onTap: () => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ..._params(context),
        const SizedBox(height: 18),
        FinnButton(
          key: const Key('condition-save'),
          label: l10n.flowsEdDone,
          onTap: canSave
              ? () => Navigator.of(context).pop(FlowConditionPick(_result))
              : null,
        ),
        if (widget.removable) ...[
          const SizedBox(height: 10),
          FinnButton(
            key: const Key('condition-remove'),
            label: l10n.flowsEdRemove,
            secondary: true,
            onTap: () =>
                Navigator.of(context).pop(const FlowConditionPick(null)),
          ),
        ],
      ],
    );
  }

  List<Widget> _params(BuildContext context) {
    final l10n = L10n.of(context);
    switch (_kind) {
      case FlowConditionKind.batteryBelow:
      case FlowConditionKind.batteryAbove:
        return [
          Center(
            child: Text('$_level%',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
          Slider(
            key: const Key('condition-level'),
            value: _level.toDouble(),
            min: 5,
            max: 95,
            divisions: 18,
            label: '$_level%',
            onChanged: (v) => setState(() => _level = v.round()),
          ),
        ];
      case FlowConditionKind.timeBetween:
        return [
          Row(
            children: [
              Expanded(
                child: _TimeBox(
                  label: l10n.flowsFieldFrom,
                  value: flowMinutesLabel(_from),
                  onTap: () => _pickTime(start: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeBox(
                  label: l10n.flowsFieldTo,
                  value: flowMinutesLabel(_to),
                  onTap: () => _pickTime(start: false),
                ),
              ),
            ],
          ),
        ];
      case FlowConditionKind.weekdays:
        final initials = flowDayInitials(l10n);
        final names = flowDayNames(l10n);
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var day = 1; day <= 7; day++)
                Semantics(
                  button: true,
                  selected: _days.contains(day),
                  label: names[day - 1],
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: Key('condition-day-$day'),
                    onTap: () => setState(
                      () => _days.contains(day)
                          ? _days.remove(day)
                          : _days.add(day),
                    ),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _days.contains(day)
                            ? FluxColors.actionOf(context)
                            : FluxColors.controlOf(context),
                      ),
                      child: Text(
                        initials[day - 1],
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _days.contains(day)
                                  ? FluxColors.actionInkOf(context)
                                  : FluxColors.inkOf(context),
                            ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ];
      case FlowConditionKind.answerContains:
        return [
          TextField(
            key: const Key('condition-text'),
            controller: _text,
            maxLength: FlowCondition.maxTextLength,
            decoration: InputDecoration(labelText: l10n.flowsFieldContains),
            onChanged: (_) => setState(() {}),
          ),
        ];
      default:
        return const [];
    }
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label $value',
        excludeSemantics: true,
        child: Material(
          color: FluxColors.controlOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(FluxRadius.md),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ),
        ),
      );
}
