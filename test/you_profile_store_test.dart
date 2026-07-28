import 'dart:io';

import 'package:finn_ai/src/you/you_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_you_test_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists personalization and exposes compact prompt context', () async {
    final store = YouProfileStore(directoryProvider: () async => directory);
    await store.initialize();

    expect(store.promptContext, isEmpty);
    expect(
      await store.save(
        const FinnUserProfile(
          preferredName: 'Ari',
          about: 'Android developer',
          customInstructions: 'Use metric units.',
          responseStyle: FinnResponseStyle.concise,
        ),
      ),
      isTrue,
    );

    final restored = YouProfileStore(directoryProvider: () async => directory);
    await restored.initialize();

    expect(restored.profile.preferredName, 'Ari');
    expect(restored.profile.responseStyle, FinnResponseStyle.concise);
    expect(restored.promptContext, contains('Address the user as Ari'));
    expect(restored.promptContext, contains('Use metric units.'));
  });

  test('deleteStorage removes persisted personalization and memory', () async {
    final store = YouProfileStore(directoryProvider: () async => directory);
    await store.initialize();
    await store.save(const FinnUserProfile(preferredName: 'Local user'));

    expect(await store.deleteStorage(), isEmpty);
    expect(store.profile.hasPersonalization, isFalse);
    expect(
      File('${directory.path}/user_personalization.json').existsSync(),
      isFalse,
    );

    final restored = YouProfileStore(directoryProvider: () async => directory);
    await restored.initialize();
    expect(restored.profile.hasPersonalization, isFalse);
  });
}
