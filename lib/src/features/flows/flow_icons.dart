import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The icon for each thing a flow can start from, check or do.
abstract final class FlowIcons {
  static const plug = LucideIcons.unplug300;
  static const charger = LucideIcons.plug300;
  static const batteryLow = LucideIcons.batteryLow300;
  static const batteryCharging = LucideIcons.batteryCharging300;
  static const headphones = LucideIcons.headphones300;
  static const wifi = LucideIcons.wifi300;
  static const wifiOff = LucideIcons.wifiOff300;
  static const airplane = LucideIcons.plane300;
  static const power = LucideIcons.plug300;
  static const unlock = LucideIcons.lockOpen300;
  static const repeat = LucideIcons.repeat300;
  static const clock = LucideIcons.clock300;
  static const bell = LucideIcons.bell300;
  static const hourglass = LucideIcons.hourglass300;
  static const branch = LucideIcons.gitBranch300;
  static const stop = LucideIcons.circleStop300;
  static const chat = LucideIcons.messageCircle300;
  static const phone = LucideIcons.smartphone300;
  static const bolt = LucideIcons.zap300;
  static const arrowDown = LucideIcons.chevronDown300;
  static const arrowUp = LucideIcons.chevronUp300;
  static const trash = LucideIcons.trash2300;
  static const play = LucideIcons.circlePlay300;
  static const flowchart = LucideIcons.waypoints300;
  static const hand = LucideIcons.pointer300;

  static IconData forTrigger(FlowTriggerKind kind) => switch (kind) {
        FlowTriggerKind.manual => hand,
        FlowTriggerKind.timeOfDay => clock,
        FlowTriggerKind.interval => repeat,
        FlowTriggerKind.chargerConnected => charger,
        FlowTriggerKind.chargerDisconnected => plug,
        FlowTriggerKind.batteryLow => batteryLow,
        FlowTriggerKind.headsetConnected ||
        FlowTriggerKind.headsetDisconnected =>
          headphones,
        FlowTriggerKind.wifiConnected => wifi,
        FlowTriggerKind.wifiDisconnected => wifiOff,
        FlowTriggerKind.airplaneOn || FlowTriggerKind.airplaneOff => airplane,
        FlowTriggerKind.deviceBooted => power,
        FlowTriggerKind.screenUnlocked => unlock,
      };

  static IconData forCondition(FlowConditionKind kind) => switch (kind) {
        FlowConditionKind.batteryBelow => batteryLow,
        FlowConditionKind.batteryAbove ||
        FlowConditionKind.charging ||
        FlowConditionKind.notCharging =>
          batteryCharging,
        FlowConditionKind.timeBetween || FlowConditionKind.weekdays => clock,
        FlowConditionKind.wifiConnected => wifi,
        FlowConditionKind.wifiDisconnected => wifiOff,
        FlowConditionKind.headsetConnected ||
        FlowConditionKind.headsetDisconnected =>
          headphones,
        FlowConditionKind.airplaneOn ||
        FlowConditionKind.airplaneOff =>
          airplane,
        FlowConditionKind.answerContains => FluxIcons.magic,
      };

  static IconData forBlock(FlowBlockKind kind) => switch (kind) {
        FlowBlockKind.ask => FluxIcons.magic,
        FlowBlockKind.web => FluxIcons.internet,
        FlowBlockKind.notify => bell,
        FlowBlockKind.speak => FluxIcons.volume,
        FlowBlockKind.action => phone,
        FlowBlockKind.wait => hourglass,
        FlowBlockKind.branch => branch,
        FlowBlockKind.saveToChat => chat,
        FlowBlockKind.stop => stop,
      };
}
