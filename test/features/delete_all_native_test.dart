import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/app/app_state_store.dart';
import 'package:finn_ai/src/features/creations/home_screen_service.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/features/flows/flow_scheduler.dart';

class _Backend implements FlowScheduleBackend {
  List<FlowTriggerSpec> alarms = const [];
  List<FlowTriggerSpec> events = const [];

  @override
  Future<bool> notificationsAllowed() async => true;

  @override
  Future<bool> requestNotifications() async => true;

  @override
  Future<void> sync({
    required List<FlowTriggerSpec> alarms,
    required List<FlowTriggerSpec> events,
  }) async {
    this.alarms = alarms;
    this.events = events;
  }

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> notify({
    required String flowId,
    required String title,
    required String body,
  }) async {}

  @override
  Future<String?> takePendingFlow() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('delete all data forgets widget taps and disarms every trigger',
      () async {
    final dir = await Directory.systemTemp.createTemp('finn_delete_native_');
    addTearDown(() => dir.delete(recursive: true));

    final calls = <String>[];
    const channel = MethodChannel('finn_ai/test_home_screen');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final backend = _Backend();
    final scheduler = FlowScheduler(backend: backend);
    await scheduler.sync([
      FinnFlow(
        id: 'charging',
        name: 'Charging',
        description: '',
        instructions: '',
        category: 'Automation',
        enabled: true,
        triggers: const [FlowTrigger.event(FlowTriggerKind.chargerConnected)],
        blocks: const [FlowBlock.notify('Hi', title: 'Hi')],
      ),
    ]);
    expect(backend.events, isNotEmpty, reason: 'the trigger starts armed');

    await AppStateStore(directoryProvider: () async => dir).deleteAllData(
      homeScreen: HomeScreenService(channel: channel),
      flowScheduler: scheduler,
    );

    expect(calls, contains('clearWidgetState'));
    expect(backend.alarms, isEmpty);
    expect(backend.events, isEmpty);
  });
}
