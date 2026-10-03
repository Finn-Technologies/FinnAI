import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_icons.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/features/flows/flow_schedule_sheet.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

/// The user's choice in the trigger sheet.
class FlowTriggerPick {
  const FlowTriggerPick(this.trigger);

  /// The new trigger, or null to remove the one being edited.
  final FlowTrigger? trigger;
}

/// Picks what starts a flow. Null when dismissed; a pick with no trigger means
/// "remove this one".
///
/// A trigger that has numbers to set (a time, an interval, a battery level)
/// goes on to a second sheet for them; the others are chosen with one tap.
Future<FlowTriggerPick?> pickFlowTrigger(
  BuildContext context, {
  FlowTrigger? current,
}) async {
  final l10n = L10n.of(context);
  final kind = await showFinnSheet<Object>(
    context,
    title: l10n.flowsEdChooseTrigger,
    children: (sheet) => [
      FinnCaption(l10n.flowsTrigGroupTime),
      for (final kind in const [
        FlowTriggerKind.timeOfDay,
        FlowTriggerKind.interval,
      ])
        _kindTile(sheet, kind, current),
      FinnCaption(l10n.flowsTrigGroupPhone),
      for (final kind in const [
        FlowTriggerKind.chargerConnected,
        FlowTriggerKind.chargerDisconnected,
        FlowTriggerKind.batteryLow,
        FlowTriggerKind.headsetConnected,
        FlowTriggerKind.headsetDisconnected,
        FlowTriggerKind.wifiConnected,
        FlowTriggerKind.wifiDisconnected,
        FlowTriggerKind.airplaneOn,
        FlowTriggerKind.airplaneOff,
        FlowTriggerKind.deviceBooted,
        FlowTriggerKind.screenUnlocked,
      ])
        _kindTile(sheet, kind, current),
      if (current != null) ...[
        const SizedBox(height: 10),
        FinnButton(
          key: const Key('trigger-remove'),
          label: l10n.flowsEdRemove,
          secondary: true,
          onTap: () => Navigator.of(sheet).pop('remove'),
        ),
      ],
    ],
  );
  if (kind == null || !context.mounted) return null;
  if (kind == 'remove') return const FlowTriggerPick(null);
  FlowTrigger? chosen;
  switch (kind as FlowTriggerKind) {
    case FlowTriggerKind.timeOfDay:
      chosen = await showFlowSchedule(
        context,
        current?.kind == FlowTriggerKind.timeOfDay
            ? current!
            : const FlowTrigger.daily(7, 30),
      );
    case FlowTriggerKind.interval:
      chosen = await _pickInterval(context, current);
    case FlowTriggerKind.batteryLow:
      chosen = await _pickBatteryLevel(context, current);
    default:
      chosen = FlowTrigger.event(kind);
  }
  return chosen == null ? null : FlowTriggerPick(chosen);
}

Widget _kindTile(
  BuildContext sheet,
  FlowTriggerKind kind,
  FlowTrigger? current,
) {
  final l10n = L10n.of(sheet);
  final label = switch (kind) {
    FlowTriggerKind.timeOfDay => l10n.flowsTrigTimeOfDay,
    FlowTriggerKind.interval => l10n.flowsTrigInterval,
    FlowTriggerKind.batteryLow => flowTriggerLabel(
        l10n,
        FlowTrigger.batteryLow(current?.level ?? 20),
      ),
    _ => flowTriggerLabel(l10n, FlowTrigger.event(kind)),
  };
  return FinnTile(
    key: Key('trigger-kind-${kind.name}'),
    icon: FlowIcons.forTrigger(kind),
    title: label,
    onTap: () => Navigator.of(sheet).pop(kind),
    chevron: false,
    trailing: current?.kind == kind
        ? const FluxIcon(icon: FluxIcons.check, size: 20)
        : null,
  );
}

Future<FlowTrigger?> _pickInterval(
  BuildContext context,
  FlowTrigger? current,
) {
  final l10n = L10n.of(context);
  var minutes =
      current?.kind == FlowTriggerKind.interval ? current!.intervalMinutes : 60;
  return showFinnSheet<FlowTrigger>(
    context,
    title: l10n.flowsEveryHowLong,
    subtitle: l10n.flowsIntervalNote,
    children: (sheet) => [
      StatefulBuilder(
        builder: (context, setState) {
          final options = const [15, 30, 60, 120, 240, 480, 720, 1440];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in options)
                    FluxChip(
                      key: Key('interval-$option'),
                      label: flowTriggerLabel(l10n, FlowTrigger.every(option)),
                      selected: minutes == option,
                      onTap: () => setState(() => minutes = option),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FinnButton(
                key: const Key('interval-save'),
                label: l10n.flowsEdDone,
                onTap: () =>
                    Navigator.of(sheet).pop(FlowTrigger.every(minutes)),
              ),
            ],
          );
        },
      ),
    ],
  );
}

Future<FlowTrigger?> _pickBatteryLevel(
  BuildContext context,
  FlowTrigger? current,
) {
  final l10n = L10n.of(context);
  var level = current?.kind == FlowTriggerKind.batteryLow ? current!.level : 20;
  return showFinnSheet<FlowTrigger>(
    context,
    title: l10n.flowsFieldLevel,
    subtitle: l10n.flowsBatteryLevelNote,
    children: (sheet) => [
      StatefulBuilder(
        builder: (context, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                '$level%',
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            Slider(
              key: const Key('battery-level-slider'),
              value: level.toDouble(),
              min: 5,
              max: 90,
              divisions: 17,
              label: '$level%',
              onChanged: (v) => setState(() => level = v.round()),
            ),
            const SizedBox(height: 10),
            FinnButton(
              key: const Key('battery-save'),
              label: l10n.flowsEdDone,
              onTap: () =>
                  Navigator.of(sheet).pop(FlowTrigger.batteryLow(level)),
            ),
          ],
        ),
      ),
    ],
  );
}
