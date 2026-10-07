import 'package:flutter/widgets.dart';
import 'package:hugeicons_pro/hugeicons.dart';

import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The icon for each thing a flow can start from, check or do. Hugeicons
/// Solid, matching [FluxIcons].
abstract final class FlowIcons {
  static const plug = HugeIconsSolid.plug02;
  static const charger = HugeIconsSolid.plug01;
  static const batteryLow = HugeIconsSolid.batteryLow;
  static const batteryCharging = HugeIconsSolid.batteryCharging01;
  static const headphones = HugeIconsSolid.headphones;
  static const wifi = HugeIconsSolid.wifi01;
  static const wifiOff = HugeIconsSolid.wifiOff01;
  static const airplane = HugeIconsSolid.airplane01;
  static const power = HugeIconsSolid.powerSocket01;
  static const unlock = HugeIconsSolid.squareUnlock01;
  static const repeat = HugeIconsSolid.repeat;
  static const clock = HugeIconsSolid.clock01;
  static const bell = HugeIconsSolid.notification01;
  static const hourglass = HugeIconsSolid.hourglass;
  static const branch = HugeIconsSolid.gitBranch;
  static const stop = HugeIconsSolid.stopCircle;
  static const chat = HugeIconsSolid.message01;
  static const phone = HugeIconsSolid.smartPhone01;
  static const bolt = HugeIconsSolid.zap;
  static const arrowDown = HugeIconsSolid.arrowDown01;
  static const arrowUp = HugeIconsSolid.arrowUp01;
  static const trash = HugeIconsSolid.delete01;
  static const play = HugeIconsSolid.playCircle;
  static const flowchart = HugeIconsSolid.flowchart01;
  static const hand = HugeIconsSolid.cursorPointer01;

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
