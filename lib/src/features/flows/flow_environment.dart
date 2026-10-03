import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/features/flows/flow_conditions.dart';
import 'package:finn_ai/src/features/flows/flow_ports.dart';

/// Reads the phone's state (battery, charger, Wi-Fi, headset, airplane mode)
/// from the Android side. Where there is no such side, a quiet default, so a
/// condition is simply untestable rather than the flow crashing.
class PlatformFlowEnvironment implements FlowEnvironment {
  const PlatformFlowEnvironment({this.clock = DateTime.now});

  static const MethodChannel channel = MethodChannel('finn_ai/flow_env');

  final DateTime Function() clock;

  @override
  Future<FlowEnvironmentSnapshot> snapshot() async {
    try {
      final raw = await channel.invokeMethod<Map<Object?, Object?>>('snapshot');
      if (raw != null) {
        return FlowEnvironmentSnapshot.fromMap(raw, now: clock());
      }
    } on MissingPluginException {
      // Not Android, or a test.
    } on PlatformException catch (error) {
      debugPrint('FINN_FLOW_ENV snapshot failed: ${error.code}');
    }
    return FlowEnvironmentSnapshot(now: clock());
  }
}
