import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_executor.dart';
import 'package:finn_ai/src/features/actions/device_action_resolver.dart';

/// Device actions as they behave inside a conversation.
///
/// The matcher is the only resolver wired here. Inside chat a device command has
/// to be recognised instantly or not at all: a model pass would delay every
/// turn, and the phrasings this feature exists for are exactly the ones the
/// matcher already settles.
class ChatDeviceActions {
  const ChatDeviceActions({
    this.resolver = const DeviceActionResolver(),
    this.executor = const PlatformDeviceActionExecutor(),
  });

  final DeviceActionResolver resolver;
  final DeviceActionExecutor executor;

  /// The action a message asks for, or null when it is an ordinary turn.
  Future<DeviceActionInvocation?> resolve(String prompt) =>
      resolver.resolve(prompt);

  /// Nothing runs without the user tapping through.
  ///
  /// Even the "open" tier leaves the app: raising a settings screen changes what
  /// is on screen and puts a toggle one tap away, and opening the clock app is
  /// still handing control to another process. A confirmation costs one tap and
  /// is the only thing that makes a mis-resolution harmless.
  static bool runsWithoutAsking(DeviceActionInvocation invocation) => false;

  Future<DeviceActionResult> run(DeviceActionInvocation invocation) =>
      executor.execute(invocation);
}
