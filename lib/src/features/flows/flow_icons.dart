import 'package:hugeicons/hugeicons.dart';

import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The icon for each thing a flow can start from, check or do.
abstract final class FlowIcons {
  static const plug = HugeIcons.strokeRoundedPlugSocket;
  static const charger = HugeIcons.strokeRoundedPlug01;
  static const batteryLow = HugeIcons.strokeRoundedBatteryLow;
  static const batteryCharging = HugeIcons.strokeRoundedBatteryCharging01;
  static const headphones = HugeIcons.strokeRoundedHeadphones;
  static const wifi = HugeIcons.strokeRoundedWifi01;
  static const wifiOff = HugeIcons.strokeRoundedWifiOff01;
  static const airplane = HugeIcons.strokeRoundedAirplane01;
  static const power = HugeIcons.strokeRoundedPowerSocket01;
  static const unlock = HugeIcons.strokeRoundedSquareUnlock01;
  static const repeat = HugeIcons.strokeRoundedRepeat;
  static const clock = HugeIcons.strokeRoundedClock01;
  static const bell = HugeIcons.strokeRoundedNotification01;
  static const hourglass = HugeIcons.strokeRoundedHourglass;
  static const branch = HugeIcons.strokeRoundedGitBranch;
  static const stop = HugeIcons.strokeRoundedStopCircle;
  static const chat = HugeIcons.strokeRoundedBubbleChat;
  static const phone = HugeIcons.strokeRoundedSmartPhone01;
  static const bolt = HugeIcons.strokeRoundedFlash;
  static const arrowDown = HugeIcons.strokeRoundedArrowDown01;
  static const arrowUp = HugeIcons.strokeRoundedArrowUp01;
  static const trash = HugeIcons.strokeRoundedDelete02;
  static const play = HugeIcons.strokeRoundedPlayCircle;
  static const flowchart = HugeIcons.strokeRoundedFlowchart01;
  static const hand = HugeIcons.strokeRoundedTouch01;

  static List<List<dynamic>> forTrigger(FlowTriggerKind kind) => switch (kind) {
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

  static List<List<dynamic>> forCondition(FlowConditionKind kind) =>
      switch (kind) {
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

  static List<List<dynamic>> forBlock(FlowBlockKind kind) => switch (kind) {
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
