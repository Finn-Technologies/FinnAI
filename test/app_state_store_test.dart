import 'dart:io';
import 'dart:typed_data';

import 'package:finn_ai/src/app_state_store.dart';
import 'package:finn_ai/src/conversations/conversation_store.dart';
import 'package:finn_ai/src/creations/creation_model.dart';
import 'package:finn_ai/src/creations/creation_store.dart';
import 'package:finn_ai/src/skills/skills_store.dart';
import 'package:finn_ai/src/you/you_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingKeyStorage implements SecureKeyStorage {
  @override
  Future<Uint8List?> readKey(String alias) async => null;

  @override
  Future<void> writeKey(String alias, Uint8List key) async {}

  @override
  Future<void> deleteKey(String alias) async {
    throw StateError('Simulated key deletion error');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ConversationStore testConvStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finn_ai_app_state_test_');
    testConvStore = ConversationStore(
      keyStorage: FakeKeyStorage(),
      directoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AppStateStore Data Purge & Failure Tests', () {
    test('completeOnboarding creates onboarding marker', () async {
      final store = AppStateStore(directoryProvider: () async => tempDir);
      await store.completeOnboarding();

      final marker = File(
        '${tempDir.path}${Platform.pathSeparator}onboarding_complete',
      );
      expect(await marker.exists(), isTrue);
      expect(store.onboardingComplete, isTrue);
    });

    test(
      'deleteAllData removes onboarding marker and returns success result',
      () async {
        final store = AppStateStore(directoryProvider: () async => tempDir);
        await store.completeOnboarding();

        final result = await store.deleteAllData(
          conversationStore: testConvStore,
        );

        final marker = File(
          '${tempDir.path}${Platform.pathSeparator}onboarding_complete',
        );
        expect(await marker.exists(), isFalse);
        expect(store.onboardingComplete, isFalse);
        expect(result.isSuccess, isTrue);
      },
    );

    test(
      'deleteAllData handles missing onboarding marker gracefully',
      () async {
        final store = AppStateStore(directoryProvider: () async => tempDir);
        final result = await store.deleteAllData(
          conversationStore: testConvStore,
        );

        expect(result.isSuccess, isTrue);
        expect(result.nonExistentItems, contains('Onboarding state'));
      },
    );

    test(
      'Injected key deletion failure is accurately reported in DeletionResult',
      () async {
        final failingConvStore = ConversationStore(
          keyStorage: FailingKeyStorage(),
          directoryProvider: () async => tempDir,
        );

        final store = AppStateStore(directoryProvider: () async => tempDir);
        final result = await store.deleteAllData(
          conversationStore: failingConvStore,
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.failedItems,
          contains('encryption key (Bad state: Simulated key deletion error)'),
        );
      },
    );

    test(
      'deleteAllData purges injected creations, personalization, and skills',
      () async {
        final creationStore = CreationStore(
          directoryProvider: () async => tempDir,
        );
        final profileStore = YouProfileStore(
          directoryProvider: () async => tempDir,
        );
        final skillsStore = SkillsStore(directoryProvider: () async => tempDir);

        await creationStore.save([
          FinnCreation(
            id: 'private-creation',
            kind: CreationKind.app,
            prompt: 'Build my private app',
            title: 'Private app',
            summary: 'Local-only data',
            sections: const [],
            createdAt: DateTime(2026, 7, 27),
          ),
        ]);
        await profileStore.initialize();
        await profileStore.save(
          const FinnUserProfile(
            preferredName: 'Ari',
            customInstructions: 'Remember this locally.',
          ),
        );
        await skillsStore.initialize();
        await skillsStore.setEnabled('builtin-coding', true);
        await skillsStore.upsertCustom(
          name: 'Private workflow',
          description: 'Local workflow',
          instructions: 'Use the private workflow.',
        );

        final result = await AppStateStore(
          directoryProvider: () async => tempDir,
        ).deleteAllData(
          conversationStore: testConvStore,
          creationStore: creationStore,
          youProfileStore: profileStore,
          skillsStore: skillsStore,
        );

        expect(result.failedItems, isEmpty);
        expect(result.deletedItems, contains('Local creations'));
        expect(result.deletedItems, contains('Personalization'));
        expect(result.deletedItems, contains('Skills'));
        expect(Directory('${tempDir.path}/creations').existsSync(), isFalse);
        expect(
          File('${tempDir.path}/user_personalization.json').existsSync(),
          isFalse,
        );
        expect(File('${tempDir.path}/skills.json').existsSync(), isFalse);
        expect(profileStore.profile.hasPersonalization, isFalse);
        expect(skillsStore.enabledSkills, isEmpty);
        expect(skillsStore.skills, hasLength(finnBuiltInSkills.length));

        final restoredProfile = YouProfileStore(
          directoryProvider: () async => tempDir,
        );
        final restoredSkills = SkillsStore(
          directoryProvider: () async => tempDir,
        );
        await restoredProfile.initialize();
        await restoredSkills.initialize();
        expect(restoredProfile.promptContext, isEmpty);
        expect(restoredSkills.activePromptContext, isEmpty);
      },
    );
  });
}

class FakeKeyStorage implements SecureKeyStorage {
  @override
  Future<Uint8List?> readKey(String alias) async => null;

  @override
  Future<void> writeKey(String alias, Uint8List key) async {}

  @override
  Future<void> deleteKey(String alias) async {}
}
