import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_descriptions.dart';
import 'package:finn_ai/src/features/flows/flow_condition_sheet.dart';
import 'package:finn_ai/src/features/flows/flow_icons.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

/// What the user did in the block sheet.
enum FlowBlockOp { save, remove, moveUp, moveDown }

class FlowBlockEdit {
  const FlowBlockEdit(this.op, [this.block]);

  final FlowBlockOp op;
  final FlowBlock? block;
}

/// A fresh block of [kind] with sensible starting values.
FlowBlock newFlowBlock(FlowBlockKind kind) => switch (kind) {
      FlowBlockKind.ask => const FlowBlock.ask(''),
      FlowBlockKind.web => const FlowBlock.web(''),
      FlowBlockKind.notify => const FlowBlock.notify(''),
      FlowBlockKind.speak => const FlowBlock.speak(''),
      FlowBlockKind.action => const FlowBlock.action('torch', {'on': 'true'}),
      FlowBlockKind.wait => const FlowBlock.wait(5),
      FlowBlockKind.branch =>
        const FlowBlock.branch(FlowCondition.batteryBelow(20)),
      FlowBlockKind.saveToChat => const FlowBlock.saveToChat(),
      FlowBlockKind.stop => const FlowBlock.stop(),
    };

/// Edits one block. Null when dismissed.
Future<FlowBlockEdit?> editFlowBlock(
  BuildContext context,
  FlowBlock block, {
  required bool isNew,
  bool canMoveUp = false,
  bool canMoveDown = false,
}) {
  final l10n = L10n.of(context);
  return showFinnSheet<FlowBlockEdit>(
    context,
    title: flowBlockTitle(l10n, block.kind),
    children: (_) => [
      _BlockForm(
        block: block,
        isNew: isNew,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
      ),
    ],
  );
}

class _BlockForm extends StatefulWidget {
  const _BlockForm({
    required this.block,
    required this.isNew,
    required this.canMoveUp,
    required this.canMoveDown,
  });

  final FlowBlock block;
  final bool isNew;
  final bool canMoveUp;
  final bool canMoveDown;

  @override
  State<_BlockForm> createState() => _BlockFormState();
}

class _BlockFormState extends State<_BlockForm> {
  late FlowBlock _block = widget.block;
  late final TextEditingController _text = TextEditingController(
    text: widget.block.kind == FlowBlockKind.web
        ? widget.block.text.replaceFirst(RegExp(r'^(?:news|weather):\s*'), '')
        : widget.block.text,
  );
  late final TextEditingController _title =
      TextEditingController(text: widget.block.title);
  final Map<String, TextEditingController> _params = {};

  /// `news`, `weather` or empty (the general web) for a look-up block.
  late String _source = RegExp(r'^(news|weather):', caseSensitive: false)
          .firstMatch(widget.block.text)
          ?.group(1)
          ?.toLowerCase() ??
      '';

  @override
  void dispose() {
    _text.dispose();
    _title.dispose();
    for (final c in _params.values) {
      c.dispose();
    }
    super.dispose();
  }

  FlowBlockKind get _kind => _block.kind;

  FlowBlock get _result {
    switch (_kind) {
      case FlowBlockKind.web:
        final query = _text.text.trim();
        return _block.copyWith(
          text: _source.isEmpty ? query : '$_source: $query',
        );
      case FlowBlockKind.ask:
      case FlowBlockKind.speak:
        return _block.copyWith(text: _text.text.trim());
      case FlowBlockKind.notify:
        return _block.copyWith(
          text: _text.text.trim(),
          title: _title.text.trim(),
        );
      case FlowBlockKind.action:
        return _block.copyWith(arguments: _arguments());
      default:
        return _block;
    }
  }

  Map<String, String> _arguments() {
    final action = DeviceActionCatalog.byName(_block.actionName ?? '');
    final out = <String, String>{..._block.arguments};
    if (action == null) return out;
    for (final param in action.params) {
      final controller = _params[param.name];
      if (controller != null) out[param.name] = controller.text.trim();
    }
    out.removeWhere((_, v) => v.isEmpty);
    return out;
  }

  bool get _valid {
    switch (_kind) {
      case FlowBlockKind.ask:
      case FlowBlockKind.web:
        return _text.text.trim().isNotEmpty;
      case FlowBlockKind.action:
        final action = DeviceActionCatalog.byName(_block.actionName ?? '');
        if (action == null) return false;
        final args = _arguments();
        return action.params
            .every((p) => !p.required || args.containsKey(p.name));
      case FlowBlockKind.wait:
        return _block.seconds > 0;
      case FlowBlockKind.branch:
        return _block.condition?.isValid ?? false;
      default:
        return true;
    }
  }

  void _setArg(String name, String value) =>
      setState(() => _block = _block.copyWith(
            arguments: {..._block.arguments, name: value},
          ));

  Future<void> _chooseAction() async {
    final l10n = L10n.of(context);
    final picked = await showFinnSheet<DeviceAction>(
      context,
      title: l10n.flowsPickAction,
      children: (sheet) => [
        for (final action in DeviceActionCatalog.all)
          FinnTile(
            key: Key('action-${action.name}'),
            icon: FlowIcons.phone,
            title: flowActionName(l10n, action.name),
            subtitle: DeviceActionCatalog.runsInBackground(action.name)
                ? l10n.flowsBgWorks
                : l10n.flowsBgNeedsScreen,
            chevron: false,
            onTap: () => Navigator.of(sheet).pop(action),
          ),
      ],
    );
    if (picked == null) return;
    for (final c in _params.values) {
      c.dispose();
    }
    _params.clear();
    setState(() => _block = FlowBlock.action(
          picked.name,
          flowActionDefaults(picked.name),
        ));
  }

  Future<void> _changeCondition() async {
    final condition = await editFlowCondition(
      context,
      initial: _block.condition,
      allowAnswer: true,
    );
    if (condition != null) {
      setState(() => _block = _block.copyWith(condition: condition));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._fields(context, l10n),
        const SizedBox(height: 18),
        FinnButton(
          key: const Key('block-save'),
          label: l10n.flowsEdDone,
          onTap: _valid
              ? () => Navigator.of(context)
                  .pop(FlowBlockEdit(FlowBlockOp.save, _result))
              : null,
        ),
        if (!widget.isNew) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (widget.canMoveUp)
                Expanded(
                  child: FinnButton(
                    key: const Key('block-up'),
                    label: l10n.flowsEdMoveUp,
                    icon: FlowIcons.arrowUp,
                    secondary: true,
                    onTap: () => Navigator.of(context)
                        .pop(const FlowBlockEdit(FlowBlockOp.moveUp)),
                  ),
                ),
              if (widget.canMoveUp && widget.canMoveDown)
                const SizedBox(width: 10),
              if (widget.canMoveDown)
                Expanded(
                  child: FinnButton(
                    key: const Key('block-down'),
                    label: l10n.flowsEdMoveDown,
                    icon: FlowIcons.arrowDown,
                    secondary: true,
                    onTap: () => Navigator.of(context)
                        .pop(const FlowBlockEdit(FlowBlockOp.moveDown)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FinnButton(
            key: const Key('block-remove'),
            label: l10n.flowsEdRemove,
            icon: FlowIcons.trash,
            secondary: true,
            onTap: () => Navigator.of(context)
                .pop(const FlowBlockEdit(FlowBlockOp.remove)),
          ),
        ],
      ],
    );
  }

  List<Widget> _fields(BuildContext context, AppLocalizations l10n) {
    switch (_kind) {
      case FlowBlockKind.ask:
        return [
          _field(
            key: 'block-text',
            controller: _text,
            label: l10n.flowsFieldPrompt,
            helper: l10n.flowsFieldPromptHint('{input}'),
            lines: 5,
          ),
        ];
      case FlowBlockKind.web:
        return [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in [
                ('', l10n.flowsSourceWeb),
                ('news', l10n.flowsSourceNews),
                ('weather', l10n.flowsSourceWeather),
              ])
                FluxChip(
                  key: Key('source-${value.isEmpty ? 'web' : value}'),
                  label: label,
                  selected: _source == value,
                  onTap: () => setState(() => _source = value),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _field(
            key: 'block-text',
            controller: _text,
            label: l10n.flowsFieldQuery,
          ),
        ];
      case FlowBlockKind.notify:
        return [
          _field(
              key: 'block-title',
              controller: _title,
              label: l10n.flowsFieldTitle),
          const SizedBox(height: 12),
          _field(
            key: 'block-text',
            controller: _text,
            label: l10n.flowsFieldMessage,
            helper: l10n.flowsFieldMessageHint,
            lines: 3,
          ),
        ];
      case FlowBlockKind.speak:
        return [
          _field(
            key: 'block-text',
            controller: _text,
            label: l10n.flowsFieldSay,
            helper: l10n.flowsFieldSayHint,
            lines: 3,
          ),
        ];
      case FlowBlockKind.wait:
        return [
          Center(
            child: Text(
              l10n.flowsSumWait(_block.seconds),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Slider(
            key: const Key('block-seconds'),
            value: _block.seconds.clamp(1, FlowBlock.maxWaitSeconds).toDouble(),
            min: 1,
            max: FlowBlock.maxWaitSeconds.toDouble(),
            divisions: FlowBlock.maxWaitSeconds - 1,
            label: '${_block.seconds}',
            onChanged: (v) => setState(
              () => _block = _block.copyWith(seconds: v.round()),
            ),
          ),
        ];
      case FlowBlockKind.branch:
        return [
          FinnTile(
            key: const Key('block-condition'),
            icon: FlowIcons.branch,
            title: l10n.flowsFieldCondition,
            subtitle: _block.condition == null
                ? ''
                : flowConditionLabel(l10n, _block.condition!),
            onTap: _changeCondition,
          ),
        ];
      case FlowBlockKind.action:
        return _actionFields(context, l10n);
      case FlowBlockKind.saveToChat:
      case FlowBlockKind.stop:
        return [
          Text(
            flowBlockHint(l10n, _kind),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ];
    }
  }

  List<Widget> _actionFields(BuildContext context, AppLocalizations l10n) {
    final action = DeviceActionCatalog.byName(_block.actionName ?? '');
    return [
      FinnTile(
        key: const Key('block-action'),
        icon: FlowIcons.phone,
        title: l10n.flowsFieldAction,
        subtitle: action == null ? '' : flowActionName(l10n, action.name),
        onTap: _chooseAction,
      ),
      if (action != null)
        for (final param in action.params)
          ..._paramField(context, l10n, action, param),
    ];
  }

  List<Widget> _paramField(
    BuildContext context,
    AppLocalizations l10n,
    DeviceAction action,
    DeviceActionParam param,
  ) {
    final value = _block.arguments[param.name] ?? '';
    Widget chips(List<(String, String)> options) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (id, label) in options)
                FluxChip(
                  key: Key('param-${param.name}-$id'),
                  label: label,
                  selected: value == id,
                  onTap: () => _setArg(param.name, id),
                ),
            ],
          ),
        );

    switch ('${action.name}.${param.name}') {
      case 'torch.on':
        return [
          chips([('true', l10n.flowsOn), ('false', l10n.flowsOff)]),
        ];
      case 'media.action':
        return [
          chips([
            ('play', l10n.deviceActionMediaPlay),
            ('pause', l10n.deviceActionMediaPause),
            ('next', l10n.deviceActionMediaNext),
            ('previous', l10n.deviceActionMediaPrevious),
          ]),
        ];
      case 'volume.direction':
        return [
          chips([
            ('up', l10n.deviceActionVolumeUp),
            ('down', l10n.deviceActionVolumeDown),
            ('mute', l10n.deviceActionVolumeMute),
          ]),
        ];
      case 'open_settings.screen':
        return [
          chips([
            for (final id in DeviceSettingsScreens.all)
              (id, DeviceActionDescriptions.screenLabel(context, id)),
          ]),
        ];
      case 'set_alarm.hour':
        final hour = int.tryParse(_block.arguments['hour'] ?? '') ?? 7;
        final minute = int.tryParse(_block.arguments['minute'] ?? '') ?? 0;
        return [
          const SizedBox(height: 14),
          FinnTile(
            key: const Key('param-time'),
            icon: FlowIcons.clock,
            title: l10n.flowsParamTime,
            subtitle: flowMinutesLabel(hour * 60 + minute),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: hour, minute: minute),
              );
              if (picked == null) return;
              setState(
                () => _block = _block.copyWith(
                  arguments: {
                    ..._block.arguments,
                    'hour': '${picked.hour}',
                    'minute': '${picked.minute}',
                  },
                ),
              );
            },
          ),
        ];
      case 'set_alarm.minute':
        return const [];
      default:
        final controller = _params.putIfAbsent(
          param.name,
          () => TextEditingController(text: value),
        );
        return [
          const SizedBox(height: 14),
          _field(
            key: 'param-${param.name}',
            controller: controller,
            label: flowParamLabel(l10n, param.name),
            number: param.type == DeviceActionParamType.integer,
            onChanged: () => setState(() {}),
          ),
        ];
    }
  }

  Widget _field({
    required String key,
    required TextEditingController controller,
    required String label,
    String? helper,
    int lines = 1,
    bool number = false,
    VoidCallback? onChanged,
  }) =>
      TextField(
        key: Key(key),
        controller: controller,
        minLines: lines,
        maxLines: lines,
        maxLength: FlowBlock.maxTextLength,
        keyboardType: number
            ? TextInputType.number
            : lines > 1
                ? TextInputType.multiline
                : TextInputType.text,
        onChanged: (_) => setState(() => onChanged?.call()),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          counterText: '',
        ),
      );
}

/// The user-facing name of a device action.
String flowActionName(AppLocalizations l10n, String name) => switch (name) {
      'set_alarm' => l10n.flowsActSetAlarm,
      'set_timer' => l10n.flowsActSetTimer,
      'show_alarms' => l10n.flowsActShowAlarms,
      'torch' => l10n.flowsActTorch,
      'media' => l10n.flowsActMedia,
      'volume' => l10n.flowsActVolume,
      'vibrate' => l10n.flowsActVibrate,
      'open_settings' => l10n.flowsActOpenSettings,
      'open_app' => l10n.flowsActOpenApp,
      'dial' => l10n.flowsActDial,
      'compose_sms' => l10n.flowsActSms,
      'compose_email' => l10n.flowsActEmail,
      'take_photo' => l10n.flowsActPhoto,
      'open_url' => l10n.flowsActUrl,
      'navigate' => l10n.flowsActNavigate,
      'share' => l10n.flowsActShare,
      _ => name,
    };

String flowParamLabel(AppLocalizations l10n, String name) => switch (name) {
      'seconds' => l10n.flowsParamSeconds,
      'milliseconds' => l10n.flowsParamMilliseconds,
      'label' => l10n.flowsParamLabel,
      'name' => l10n.flowsParamName,
      'number' => l10n.flowsParamNumber,
      'to' => l10n.flowsParamTo,
      'body' => l10n.flowsParamBody,
      'subject' => l10n.flowsParamSubject,
      'url' => l10n.flowsParamUrl,
      'query' => l10n.flowsParamQuery,
      'text' => l10n.flowsParamText,
      _ => name,
    };

/// The arguments a newly chosen action starts with.
Map<String, String> flowActionDefaults(String name) => switch (name) {
      'torch' => {'on': 'true'},
      'media' => {'action': 'play'},
      'volume' => {'direction': 'up'},
      'open_settings' => {'screen': DeviceSettingsScreens.wifi},
      'set_alarm' => {'hour': '7', 'minute': '0'},
      'set_timer' => {'seconds': '600'},
      'vibrate' => {'milliseconds': '400'},
      _ => const {},
    };
