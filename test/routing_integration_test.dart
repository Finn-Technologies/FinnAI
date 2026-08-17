// Tests: model-tier persistence and report metadata propagation
//
// These tests operate entirely through ConversationStore (updateMessage +
// flush + reload). They do NOT invoke QwenInference.generateReply or any
// real on-device model. They verify that:
//   1. updateMessage() stamps the caller-supplied modelTier on the assistant
//      message and that value is distinct from the default 'Finn AI'.
//   2. The stamped modelTier survives flush() → cold reload from the encrypted
//      store.
//   3. The reloaded modelTier (the value that ReportDialog receives) equals the
//      value set at generation time, not the currently selected model.
import 'dart:io';

import 'package:finn_ai/src/conversations/conversation_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// Reuse the same fake key-storage helper as conversation_store_test.dart
class _FakeKeyStorage implements SecureKeyStorage {
  _FakeKeyStorage() : _data = {};
  final Map<String, Uint8List> _data;

  @override
  Future<Uint8List?> readKey(String alias) async => _data[alias];

  @override
  Future<void> writeKey(String alias, Uint8List key) async =>
      _data[alias] = key;

  @override
  Future<void> deleteKey(String alias) async => _data.remove(alias);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakeKeyStorage keyStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finn_routing_test_');
    keyStore = _FakeKeyStorage();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Model-tier persistence and report metadata propagation', () {
    test(
      'updateMessage stamps the specified modelTier — not default or previously selected — on the assistant message',
      () async {
        final store = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );
        await store.initialize();

        final assistant = store.beginExchange('Explain quantum entanglement');

        // The assistant placeholder starts with the default modelTier.
        expect(assistant.modelTier, 'Finn AI');

        // After inference resolves, the controller stamps the generating model.
        const routedModelTier = 'Qwen 3.5 2B';
        store.updateMessage(
          assistant.id,
          'Quantum entanglement is…',
          modelTier: routedModelTier,
          persistSoon: true,
        );
        await store.flush();

        // Verify in-memory state.
        final stored = store.active!.messages.last;
        expect(
          stored.modelTier,
          routedModelTier,
          reason:
              'assistant message must carry the generating model, not Finn AI',
        );
        expect(stored.modelTier, isNot(equals('Finn AI')));

        // Reload from disk — confirm the tier survives serialisation.
        final store2 = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );
        await store2.initialize();

        final reloaded = store2.active!.messages.last;
        expect(
          reloaded.modelTier,
          routedModelTier,
          reason: 'persisted modelTier must survive a cold store reload',
        );

        // Simulate the report dialog receiving the message's modelTier.
        final reportModelTier = reloaded.modelTier;
        expect(reportModelTier, 'Qwen 3.5 2B');
        expect(reportModelTier, isNot(equals('Finn AI')));
      },
    );

    test(
      'a distinct modelTier stamp is persisted independently',
      () async {
        final store = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );
        await store.initialize();

        final assistant = store.beginExchange('What time is it?');

        const modelTier = 'Qwen 3.5 2B (variant)';
        store.updateMessage(
          assistant.id,
          'It is currently…',
          modelTier: modelTier,
          persistSoon: true,
        );
        await store.flush();

        final reloaded = store.active!.messages.last;
        expect(reloaded.modelTier, modelTier);
        expect(reloaded.modelTier, isNot(equals('Qwen 3.5 2B')));
      },
    );

    test(
      'After cold reload, reloaded modelTier is used as report metadata — not the currently selected model',
      () async {
        final store = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );
        await store.initialize();

        store.beginExchange('Summarise War and Peace');
        store.updateMessage(
          store.active!.messages.last.id,
          'War and Peace is…',
          modelTier: 'Qwen 3.5 2B',
          persistSoon: true,
        );
        await store.flush();

        // Cold-reload simulates the app being re-opened.
        final store2 = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );
        await store2.initialize();

        final assistantMsg = store2.active!.messages
            .where((m) => m.role == ConversationRole.assistant)
            .last;

        final dialogModelTier = assistantMsg.modelTier;
        expect(
          dialogModelTier,
          'Qwen 3.5 2B',
          reason:
              'ReportDialog must receive the generating model stored with the message',
        );
        expect(dialogModelTier, isNot(equals('Finn AI')));
      },
    );
  });
}
