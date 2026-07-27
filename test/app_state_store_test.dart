import 'dart:io';
import 'dart:typed_data';

import 'package:finn_ai/src/app_state_store.dart';
import 'package:finn_ai/src/conversations/conversation_store.dart';
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
