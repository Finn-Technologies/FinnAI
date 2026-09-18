import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_executor.dart';
import 'package:finn_ai/src/features/actions/device_action_resolver.dart';

enum DeviceActionFlow { idle, resolving, confirming, running, done }

/// Drives one action at a time: resolve, confirm, run.
///
/// Nothing reaches the device without [confirm]. Every action in the catalog
/// leaves the app — even opening a settings screen hands the user to another
/// process — so the confirmation step is unconditional rather than reserved for
/// "state-changing" tiers.
class DeviceActionsController extends ChangeNotifier {
  DeviceActionsController({
    DeviceActionResolver? resolver,
    DeviceActionExecutor? executor,
  })  : resolver = resolver ?? const DeviceActionResolver(),
        executor = executor ?? const PlatformDeviceActionExecutor();

  final DeviceActionResolver resolver;
  final DeviceActionExecutor executor;

  DeviceActionFlow _flow = DeviceActionFlow.idle;
  DeviceActionFlow get flow => _flow;

  String _request = '';
  String get request => _request;

  DeviceActionInvocation? _invocation;
  DeviceActionInvocation? get invocation => _invocation;

  DeviceActionResult? _result;
  DeviceActionResult? get result => _result;

  String _error = '';
  String get error => _error;

  bool _disposed = false;

  bool get isBusy =>
      _flow == DeviceActionFlow.resolving || _flow == DeviceActionFlow.running;

  /// Resolution and execution are awaited, and the page that owns this
  /// controller is usually gone by the time they land. Notifying a disposed
  /// [ChangeNotifier] throws, so every notify goes through here.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> submit(String request) async {
    final trimmed = request.trim();
    if (trimmed.isEmpty || isBusy) return;
    // A second request would overwrite the invocation the user is being asked
    // to approve, silently dropping the confirmation they were about to give.
    if (_flow == DeviceActionFlow.confirming) return;

    _request = trimmed;
    _invocation = null;
    _result = null;
    _error = '';
    _flow = DeviceActionFlow.resolving;
    _notify();

    try {
      final invocation = await resolver.resolve(trimmed);
      if (_disposed) return;
      if (invocation == null) {
        _flow = DeviceActionFlow.idle;
        _error = 'unresolved';
        _notify();
        return;
      }
      _invocation = invocation;
      _flow = DeviceActionFlow.confirming;
    } catch (error) {
      _flow = DeviceActionFlow.idle;
      _error = error.toString();
    }
    _notify();
  }

  Future<void> confirm() async {
    final invocation = _invocation;
    if (invocation == null) return;
    if (_flow != DeviceActionFlow.confirming) return;

    _flow = DeviceActionFlow.running;
    _notify();

    DeviceActionResult result;
    try {
      result = await executor.execute(invocation);
    } catch (error) {
      result = DeviceActionResult.failed(error: error.toString());
    }
    if (_disposed) return;
    _result = result;
    _flow = DeviceActionFlow.done;
    _notify();
  }

  void cancel() {
    if (isBusy) return;
    _flow = DeviceActionFlow.idle;
    _invocation = null;
    _result = null;
    _error = '';
    _notify();
  }

  void reset() {
    _flow = DeviceActionFlow.idle;
    _request = '';
    _invocation = null;
    _result = null;
    _error = '';
    _notify();
  }
}
