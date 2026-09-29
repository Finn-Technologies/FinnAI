import 'dart:io';

import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_skills_test_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists built-in state and custom flows', () async {
    final store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();

    expect(store.activePromptContext, isEmpty);
    expect(await store.setEnabled('builtin-coding', true), isTrue);
    expect(
      await store.upsertCustom(
        name: 'Release reviewer',
        description: 'Review release readiness',
        instructions: 'Check risks, regressions, and rollback steps.',
      ),
      isTrue,
    );

    final restored = FlowsStore(directoryProvider: () async => directory);
    await restored.initialize();

    expect(restored.enabledSkills, hasLength(2));
    expect(restored.activePromptContext, contains('Coding partner'));
    expect(restored.activePromptContext, contains('Release reviewer'));
    expect(
      restored.activePromptContext,
      contains('Check risks, regressions, and rollback steps.'),
    );
  });

  test('built-ins cannot be removed', () async {
    final store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();

    expect(await store.removeCustom('builtin-writing'), isFalse);
    expect(store.flows.where((flow) => flow.builtIn), hasLength(4));
  });

  test('prompt context includes only flows relevant to the request', () async {
    final store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();
    await store.setEnabled('builtin-coding', true);
    await store.setEnabled('builtin-writing', true);

    final coding = store.promptContextFor('Debug this Flutter code');
    expect(coding, contains('Coding partner'));
    expect(coding, isNot(contains('Clear writing')));

    expect(store.promptContextFor('What time is sunset?'), isEmpty);
  });

  test('custom flows respect the four-active limit and prompt cap', () async {
    final store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();
    for (final flow in finnBuiltInFlows) {
      expect(await store.setEnabled(flow.id, true), isTrue);
    }

    expect(
      await store.upsertCustom(
        name: 'Fifth',
        description: '',
        instructions: 'Never silently activate past the limit.',
      ),
      isFalse,
    );
    expect(store.enabledSkills, hasLength(4));
    // The store reports a code, not a user-facing sentence, so the page can
    // localize it.
    expect(store.failure, FlowsFailure.limit);
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

    expect(await store.setEnabled('builtin-coding', true), isFalse);
    expect(store.failure, FlowsFailure.save);
  });

  test('deleteStorage resets flows and removes persisted state', () async {
    final store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();
    await store.setEnabled('builtin-learning', true);
    await store.upsertCustom(
      name: 'My workflow',
      description: '',
      instructions: 'Follow my workflow.',
    );

    expect(await store.deleteStorage(), isEmpty);
    expect(store.flows, hasLength(finnBuiltInFlows.length));
    expect(store.enabledSkills, isEmpty);
    expect(File('${directory.path}/flows.json').existsSync(), isFalse);

    final restored = FlowsStore(directoryProvider: () async => directory);
    await restored.initialize();
    expect(restored.flows, hasLength(finnBuiltInFlows.length));
    expect(restored.enabledSkills, isEmpty);
  });
}
