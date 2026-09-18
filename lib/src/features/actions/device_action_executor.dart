import 'package:flutter/services.dart';

import 'package:finn_ai/src/features/actions/device_action.dart';

/// Runs a resolved action against the platform.
abstract class DeviceActionExecutor {
  Future<DeviceActionResult> execute(DeviceActionInvocation invocation);
}

/// Stand-in used off Android, in tests, and on the OpenHarmony build so the
/// feature never has to ask which platform it is on.
class NoopDeviceActionExecutor implements DeviceActionExecutor {
  const NoopDeviceActionExecutor();

  @override
  Future<DeviceActionResult> execute(DeviceActionInvocation invocation) async =>
      const DeviceActionResult.unavailable();
}

class PlatformDeviceActionExecutor implements DeviceActionExecutor {
  const PlatformDeviceActionExecutor();

  static const _channel = MethodChannel('finn_ai/device_actions');

  @override
  Future<DeviceActionResult> execute(DeviceActionInvocation invocation) async {
    final Object? raw;
    try {
      raw = await _channel.invokeMethod<Object?>('perform', {
        'name': invocation.action.name,
        'arguments': invocation.arguments,
      });
    } on PlatformException catch (error) {
      return DeviceActionResult.failed(error: error.message ?? error.code);
    } on MissingPluginException {
      return const DeviceActionResult.unavailable();
    } catch (error) {
      // A malformed reply or an unexpected platform-side throw must read as a
      // failed action, never as an unhandled exception in the controller.
      return DeviceActionResult.failed(error: error.toString());
    }

    if (raw is! Map) return const DeviceActionResult.unavailable();
    final payload = raw.map((key, value) => MapEntry(key.toString(), value));
    final outcome = switch (payload['outcome']?.toString()) {
      'performed' => DeviceActionOutcome.performed,
      'opened' => DeviceActionOutcome.opened,
      'unavailable' => DeviceActionOutcome.unavailable,
      _ => DeviceActionOutcome.failed,
    };

    return DeviceActionResult(
      outcome: outcome,
      detail: payload['detail']?.toString() ?? '',
      error: payload['error']?.toString() ?? '',
    );
  }
}
