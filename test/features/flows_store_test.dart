import 'dart:convert';
import 'dart:io';

import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every stored flow is an automation: a flow with blocks. Guides (flows with
/// no blocks, including the built-ins that used to ship with the app) are
/// dropped on load and refused on save.
void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_flows_test_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<bool> saveAutomation(
    FlowsStore store,
    String name, {
    String? id,
    bool enabled = true,
  }) =>
      store.upsertCustom(
        id: id,
        name: name,
        description: 'description of $name',
        blocks: const [FlowBlock.notify('hi')],
        enabled: enabled,
      );

  test('starts empty and persists custom automations', () async {
    final store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();

    expect(store.flows, isEmpty);
    expect(await saveAutomation(store, 'Morning brief'), isTrue);
    await store.setEnabled(store.flows.single.id, true);

    final restored = FlowsStore(directoryProvider: () async => directory);
    await restored.initialize();

    expect(restored.flows, hasLength(1));
    expect(restored.flows.single.name, 'Morning brief');
    expect(restored.flows.single.isAutomation, isTrue);
    expect(restored.enabledAutomations, hasLength(1));
  });

  test('a flow with no blocks is refused', () async {
    final store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();

    expect(
      await store.upsertCustom(name: 'Guide', description: ''),
      isFalse,
    );
    expect(store.flows, isEmpty);
  });

  test('v1 guides and v3 block-less flows are dropped on load', () async {
    final file = File('${directory.path}/flows.json');
    await file.writeAsString(jsonEncode({
      'version': 3,
      'flows': [
        {
          'id': 'guide-1',
          'name': 'Old guide',
          'description': 'd',
          'instructions': 'Be brief.',
          'category': 'Custom',
          'enabled': true,
        },
        {
          'id': 'auto-1',
          'name': 'Kept',
          'description': '',
          'instructions': '',
          'category': 'Automation',
          'enabled': true,
          'blocks': [
            {'kind': 'notify', 'text': 'hi'}
          ],
        },
      ],
    }));

    final store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();

    expect(store.flows.map((flow) => flow.id), ['auto-1']);
  });

  test('a v1 document loads as no flows', () async {
    final file = File('${directory.path}/flows.json');
    await file.writeAsString(jsonEncode({
      'version': 1,
      'flows': [
        {
          'id': 'g',
          'name': 'Guide',
          'description': 'd',
          'instructions': 'Be brief.',
          'category': 'Custom',
          'enabled': true,
        },
      ],
    }));

    final store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();

    expect(store.flows, isEmpty);
  });

  test('a failed write is reported as a save failure', () async {
    // A file where the store expects its directory makes the write fail.
    final blocker = File('${directory.path}/blocker');
    await blocker.writeAsString('not a directory');
    final store = FlowsStore(
      directoryProvider: () async => Directory(blocker.path),
    );
    await store.initialize();
    expect(store.failure, isNull);

    expect(await saveAutomation(store, 'Morning brief'), isFalse);
    expect(store.failure, FlowsFailure.save);
  });

  test('deleteStorage resets flows and removes persisted state', () async {
    final store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();
    await saveAutomation(store, 'My workflow');

    expect(await store.deleteStorage(), isEmpty);
    expect(store.flows, isEmpty);
    expect(File('${directory.path}/flows.json').existsSync(), isFalse);

    final restored = FlowsStore(directoryProvider: () async => directory);
    await restored.initialize();
    expect(restored.flows, isEmpty);
  });
}
