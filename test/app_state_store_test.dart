import 'dart:io';

import 'package:finn_ai/src/app_state_store.dart';
import 'package:finn_ai/src/conversations/conversation_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'conversation_store_test.dart';

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

  group('AppStateStore Data Purge Tests', () {
    test('completeOnboarding creates onboarding marker', () async {
      final store = AppStateStore(directoryProvider: () async => tempDir);
      await store.completeOnboarding();

      final marker = File('${tempDir.path}${Platform.pathSeparator}onboarding_complete');
      expect(await marker.exists(), isTrue);
      expect(store.onboardingComplete, isTrue);
    });

    test('deleteAllData removes onboarding marker and returns success result', () async {
      final store = AppStateStore(directoryProvider: () async => tempDir);
      await store.completeOnboarding();

      final result = await store.deleteAllData(conversationStore: testConvStore);

      final marker = File('${tempDir.path}${Platform.pathSeparator}onboarding_complete');
      expect(await marker.exists(), isFalse);
      expect(store.onboardingComplete, isFalse);
      expect(result.isSuccess, isTrue);
    });

    test('deleteAllData handles missing onboarding marker gracefully', () async {
      final store = AppStateStore(directoryProvider: () async => tempDir);
      final result = await store.deleteAllData(conversationStore: testConvStore);

      expect(result.isSuccess, isTrue);
      expect(result.nonExistentItems, contains('Onboarding state'));
    });
  });
}
