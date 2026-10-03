import 'dart:io';
import 'dart:typed_data';

import 'package:finn_ai/src/app/app_state_store.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/providers/provider_store.dart';
import 'package:finn_ai/src/features/code/providers/secret_store.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/features/you/you_profile_store.dart';
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
        'deleteAllData removes FinnAI Code sessions, folders, keys and settings',
        () async {
      final secrets = MemoryCodeSecretStore();
      final sessions = CodeSessionStore(directoryProvider: () async => tempDir);
      final providers = CodeProviderStore(
        secrets: secrets,
        directoryProvider: () async => tempDir,
      );
      final settings =
          CodeSettingsStore(directoryProvider: () async => tempDir);
      final code = CodeServices(
        sessions: sessions,
        providers: providers,
        settings: settings,
      );

      final session = sessions.create(title: 'Private project');
      await (await sessions.workspaceOf(session.id))
          .writeFile('secret.txt', 'private source');
      await providers.saveKey(CodeProvider.openRouter, 'sk-private-0001');
      await settings.update(
        (s) => s.copyWith(permissionMode: CodePermissionMode.autoRun),
      );
      await sessions.flush();
      expect(Directory('${tempDir.path}/code').existsSync(), isTrue);
      expect(secrets.values, isNotEmpty);

      final result = await AppStateStore(
        directoryProvider: () async => tempDir,
      ).deleteAllData(
        conversationStore: testConvStore,
        codeServices: code,
      );

      expect(result.failedItems, isEmpty);
      expect(result.deletedItems, contains('FinnAI Code'));
      expect(Directory('${tempDir.path}/code').existsSync(), isFalse);
      expect(secrets.values, isEmpty);
      expect(sessions.sessions, isEmpty);
      expect(providers.hasKey(CodeProvider.openRouter), isFalse);
      expect(settings.settings.permissionMode, CodePermissionMode.acceptEdits);
    });

    test(
      'deleteAllData purges injected creations, personalization, and flows',
      () async {
        final creationStore = CreationStore(
          directoryProvider: () async => tempDir,
        );
        final profileStore = YouProfileStore(
          directoryProvider: () async => tempDir,
        );
        final flowsStore = FlowsStore(directoryProvider: () async => tempDir);

        await creationStore.save([
          FinnCreation(
            id: 'private-creation',
            prompt: 'Build my private app',
            title: 'Private app',
            summary: 'Local-only data',
            artifact: const LegacyDocumentArtifact(
              summary: 'Local-only data',
              sections: <CreationSection>[],
            ),
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
        await flowsStore.initialize();
        await flowsStore.upsertCustom(
          name: 'Private workflow',
          description: 'Local workflow',
          blocks: const [FlowBlock.notify('hi')],
        );

        final result = await AppStateStore(
          directoryProvider: () async => tempDir,
        ).deleteAllData(
          conversationStore: testConvStore,
          creationStore: creationStore,
          youProfileStore: profileStore,
          flowsStore: flowsStore,
        );

        expect(result.failedItems, isEmpty);
        expect(result.deletedItems, contains('Local creations'));
        expect(result.deletedItems, contains('Personalization'));
        expect(result.deletedItems, contains('Flows'));
        expect(Directory('${tempDir.path}/creations').existsSync(), isFalse);
        expect(
          File('${tempDir.path}/user_personalization.json').existsSync(),
          isFalse,
        );
        expect(File('${tempDir.path}/flows.json').existsSync(), isFalse);
        expect(profileStore.profile.hasPersonalization, isFalse);
        expect(flowsStore.flows, isEmpty);

        final restoredProfile = YouProfileStore(
          directoryProvider: () async => tempDir,
        );
        final restoredFlows = FlowsStore(
          directoryProvider: () async => tempDir,
        );
        await restoredProfile.initialize();
        await restoredFlows.initialize();
        expect(restoredProfile.promptContext, isEmpty);
        expect(restoredFlows.flows, isEmpty);
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
