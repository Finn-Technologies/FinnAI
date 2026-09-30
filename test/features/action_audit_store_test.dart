import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/actions/action_audit_store.dart';
import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';

void main() {
  late Directory dir;
  late ActionAuditStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('audit_test');
    store = ActionAuditStore(directoryProvider: () async => dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  const dial = DeviceActionInvocation(
    action: DeviceActionCatalog.dial,
    arguments: {'number': '+1 555 0100'},
  );

  test('stores the action name and outcome but never its arguments', () async {
    await store.recordRan(
      dial,
      const DeviceActionResult.performed(detail: 'Contacts'),
      source: 'chat',
    );
    final raw = await (await store.fileForTest()).readAsString();
    expect(raw, isNot(contains('555')));
    expect(raw, isNot(contains('Contacts')));
    final entry = (jsonDecode(raw) as List).single as Map;
    expect(entry['action'], DeviceActionCatalog.dial.name);
    expect(entry['outcome'], 'performed');
    expect(entry['source'], 'chat');
  });

  test('records a refusal and survives a reload', () async {
    await store.recordRefused(dial, source: 'chat');
    final reloaded = ActionAuditStore(directoryProvider: () async => dir);
    await reloaded.initialize();
    expect(reloaded.entries.single.outcome, 'refused');
  });

  test('is bounded to maxEntries, newest first', () async {
    for (var i = 0; i < ActionAuditStore.maxEntries + 5; i++) {
      await store.recordRefused(dial, source: 'chat');
    }
    expect(store.entries.length, ActionAuditStore.maxEntries);
  });

  test('a corrupt file is ignored, not fatal', () async {
    await File('${dir.path}/action_audit.json').writeAsString('{not json');
    await store.initialize();
    expect(store.initialized, isTrue);
    expect(store.entries, isEmpty);
  });

  test('deleteAll removes the file', () async {
    await store.recordRefused(dial, source: 'chat');
    await store.deleteAll();
    expect(await (await store.fileForTest()).exists(), isFalse);
    expect(store.entries, isEmpty);
  });
}
