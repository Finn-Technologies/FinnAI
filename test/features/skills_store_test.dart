import 'dart:io';

import 'package:finn_ai/src/features/skills/skills_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_skills_test_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists built-in state and custom skills', () async {
    final store = SkillsStore(directoryProvider: () async => directory);
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

    final restored = SkillsStore(directoryProvider: () async => directory);
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
    final store = SkillsStore(directoryProvider: () async => directory);
    await store.initialize();

    expect(await store.removeCustom('builtin-writing'), isFalse);
    expect(store.skills.where((skill) => skill.builtIn), hasLength(4));
  });

  test('prompt context includes only skills relevant to the request', () async {
    final store = SkillsStore(directoryProvider: () async => directory);
    await store.initialize();
    await store.setEnabled('builtin-coding', true);
    await store.setEnabled('builtin-writing', true);

    final coding = store.promptContextFor('Debug this Flutter code');
    expect(coding, contains('Coding partner'));
    expect(coding, isNot(contains('Clear writing')));

    expect(store.promptContextFor('What time is sunset?'), isEmpty);
  });

  test('custom skills respect the four-active limit and prompt cap', () async {
    final store = SkillsStore(directoryProvider: () async => directory);
    await store.initialize();
    for (final skill in finnBuiltInSkills) {
      expect(await store.setEnabled(skill.id, true), isTrue);
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
    expect(store.storageError, contains('four'));
  });

  test('deleteStorage resets skills and removes persisted state', () async {
    final store = SkillsStore(directoryProvider: () async => directory);
    await store.initialize();
    await store.setEnabled('builtin-learning', true);
    await store.upsertCustom(
      name: 'My workflow',
      description: '',
      instructions: 'Follow my workflow.',
    );

    expect(await store.deleteStorage(), isEmpty);
    expect(store.skills, hasLength(finnBuiltInSkills.length));
    expect(store.enabledSkills, isEmpty);
    expect(File('${directory.path}/skills.json').existsSync(), isFalse);

    final restored = SkillsStore(directoryProvider: () async => directory);
    await restored.initialize();
    expect(restored.skills, hasLength(finnBuiltInSkills.length));
    expect(restored.enabledSkills, isEmpty);
  });
}
