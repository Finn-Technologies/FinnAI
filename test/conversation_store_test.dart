import 'dart:typed_data';

import 'package:finn_ai/src/conversations/conversation_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationCipher Authenticated Encryption Tests', () {
    test('Encrypt and decrypt payload roundtrip', () {
      final key = Uint8List(64);
      for (var i = 0; i < 64; i++) {
        key[i] = i * 3;
      }

      const message = 'FinnAI private encrypted payload message 🚀';
      final envelope = ConversationCipher.encrypt(key, message);

      expect(envelope['version'], 1);
      expect(envelope['algorithm'], 'AES-256-CTR-HMAC-SHA256');
      expect(envelope['iv'], isA<String>());
      expect(envelope['ciphertext'], isA<String>());
      expect(envelope['mac'], isA<String>());

      final decrypted = ConversationCipher.decrypt(key, envelope);
      expect(decrypted, message);
    });

    test('Tampered ciphertext fails authentication tag verification', () {
      final key = Uint8List(64);
      for (var i = 0; i < 64; i++) {
        key[i] = i * 5;
      }

      final envelope = ConversationCipher.encrypt(key, 'Sensitive data');
      final tamperedEnv = Map<String, Object?>.from(envelope);
      tamperedEnv['ciphertext'] = 'AAAA${envelope['ciphertext']}';

      expect(
        () => ConversationCipher.decrypt(key, tamperedEnv),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ConversationStore Rename & Delete Tests', () {
    test('renameConversation updates title and notifies listeners', () {
      final store = ConversationStore.instance;
      final conv = store.startNew();
      final originalId = conv.id;

      bool notified = false;
      store.addListener(() => notified = true);

      store.renameConversation(originalId, 'Project Roadmap Notes');

      final updated = store.conversations.firstWhere((c) => c.id == originalId);
      expect(updated.title, 'Project Roadmap Notes');
      expect(notified, true);
    });

    test('deleteConversation removes item and switches active id if needed', () {
      final store = ConversationStore.instance;
      final conv1 = store.startNew();
      final conv2 = store.startNew();

      expect(store.active?.id, conv2.id);

      store.deleteConversation(conv2.id);

      expect(store.conversations.any((c) => c.id == conv2.id), false);
      expect(store.active?.id, conv1.id);
    });

    test('clearAll wipes in-memory conversations', () {
      final store = ConversationStore.instance;
      store.startNew();
      store.clearAll();
      expect(store.conversations.isEmpty, true);
      expect(store.active, null);
    });
  });
}
