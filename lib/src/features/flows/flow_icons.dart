import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The icon for each thing a flow can start from, check or do.
abstract final class FlowIcons {
  static const plug = PhosphorIconsFill.plugs;
  static const charger = PhosphorIconsFill.plug;
  static const batteryLow = PhosphorIconsFill.batteryLow;
  static const batteryCharging = PhosphorIconsFill.batteryCharging;
  static const headphones = PhosphorIconsFill.headphones;
  static const wifi = PhosphorIconsFill.wifiHigh;
  static const wifiOff = PhosphorIconsFill.wifiSlash;
  static const airplane = PhosphorIconsFill.airplane;
  static const power = PhosphorIconsFill.plug;
  static const unlock = PhosphorIconsFill.lockOpen;
  static const repeat = PhosphorIconsFill.repeat;
  static const clock = PhosphorIconsFill.clock;
  static const bell = PhosphorIconsFill.bell;
  static const hourglass = PhosphorIconsFill.hourglass;
  static const branch = PhosphorIconsFill.gitBranch;
  static const stop = PhosphorIconsFill.stopCircle;
  static const chat = PhosphorIconsFill.chatCircle;
  static const phone = PhosphorIconsFill.deviceMobile;
  static const bolt = PhosphorIconsFill.lightning;
  static const arrowDown = PhosphorIconsBold.caretDown;
  static const arrowUp = PhosphorIconsBold.caretUp;
  static const trash = PhosphorIconsFill.trash;
  static const play = PhosphorIconsFill.playCircle;
  static const flowchart = PhosphorIconsFill.flowArrow;
  static const hand = PhosphorIconsFill.handTap;

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
