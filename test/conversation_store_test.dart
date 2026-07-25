import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:finn_ai/src/conversations/conversation_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeKeyStorage implements SecureKeyStorage {
  FakeKeyStorage({
    this.failWrite = false,
    this.failReadBack = false,
    Map<String, Uint8List>? initialData,
  }) : _data = initialData ?? {};

  final Map<String, Uint8List> _data;
  final bool failWrite;
  final bool failReadBack;

  @override
  Future<Uint8List?> readKey(String alias) async {
    if (failReadBack) return null;
    return _data[alias];
  }

  @override
  Future<void> writeKey(String alias, Uint8List key) async {
    if (failWrite) throw StateError('Simulated secure storage write failure');
    _data[alias] = key;
  }

  @override
  Future<void> deleteKey(String alias) async {
    _data.remove(alias);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finn_ai_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('1. Cryptography AES-256-GCM Direct Unit Tests', () {
    test('AES-GCM roundtrip encrypts and decrypts correctly', () async {
      final key = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        key[i] = i * 7;
      }

      const plaintext = 'Hello FinnAI! Privacy-first on-device AI.';
      final envelope = await ConversationCipher.encrypt(key, plaintext);

      expect(envelope['version'], '2');
      expect(envelope['algorithm'], 'AES-256-GCM');
      expect(envelope['nonce'], isNotEmpty);
      expect(envelope['ciphertext'], isNotEmpty);
      expect(envelope['mac'], isNotEmpty);

      final decrypted = await ConversationCipher.decrypt(key, envelope);
      expect(decrypted, plaintext);
    });

    test('Unicode text roundtrip with emoji and multibyte characters', () async {
      final key = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        key[i] = i + 10;
      }

      const unicodeText = 'FinnAI 🤖 · 智能助手 · Bonjour le monde! 🔐🔥';
      final envelope = await ConversationCipher.encrypt(key, unicodeText);
      final decrypted = await ConversationCipher.decrypt(key, envelope);

      expect(decrypted, unicodeText);
    });

    test('Empty payload roundtrip', () async {
      final key = Uint8List(32);
      final envelope = await ConversationCipher.encrypt(key, '');
      final decrypted = await ConversationCipher.decrypt(key, envelope);

      expect(decrypted, '');
    });

    test('Large payload roundtrip (1 MB text)', () async {
      final key = Uint8List(32);
      final largeText = 'A' * (1024 * 1024);
      final envelope = await ConversationCipher.encrypt(key, largeText);
      final decrypted = await ConversationCipher.decrypt(key, envelope);

      expect(decrypted.length, 1024 * 1024);
      expect(decrypted, largeText);
    });

    test('Random nonce produces different ciphertext for identical plaintext', () async {
      final key = Uint8List(32);
      const text = 'Identical message';

      final env1 = await ConversationCipher.encrypt(key, text);
      final env2 = await ConversationCipher.encrypt(key, text);

      expect(env1['nonce'], isNot(equals(env2['nonce'])));
      expect(env1['ciphertext'], isNot(equals(env2['ciphertext'])));
    });

    test('Modified ciphertext fails decryption (integrity verification)', () async {
      final key = Uint8List(32);
      final envelope = await ConversationCipher.encrypt(key, 'Secret content');

      final corruptedBytes = base64Decode(envelope['ciphertext']!);
      corruptedBytes[0] ^= 0xFF;
      final tampered = Map<String, String>.from(envelope);
      tampered['ciphertext'] = base64Encode(corruptedBytes);

      expect(
        () async => ConversationCipher.decrypt(key, tampered),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Modified nonce fails decryption', () async {
      final key = Uint8List(32);
      final envelope = await ConversationCipher.encrypt(key, 'Secret content');

      final nonceBytes = base64Decode(envelope['nonce']!);
      nonceBytes[0] ^= 0xFF;
      final tampered = Map<String, String>.from(envelope);
      tampered['nonce'] = base64Encode(nonceBytes);

      expect(
        () async => ConversationCipher.decrypt(key, tampered),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Modified authentication tag (mac) fails decryption', () async {
      final key = Uint8List(32);
      final envelope = await ConversationCipher.encrypt(key, 'Secret content');

      final macBytes = base64Decode(envelope['mac']!);
      macBytes[0] ^= 0xFF;
      final tampered = Map<String, String>.from(envelope);
      tampered['mac'] = base64Encode(macBytes);

      expect(
        () async => ConversationCipher.decrypt(key, tampered),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Wrong decryption key fails decryption', () async {
      final key1 = Uint8List(32);
      final key2 = Uint8List(32)..fillRange(0, 32, 99);

      final envelope = await ConversationCipher.encrypt(key1, 'Secret content');

      expect(
        () async => ConversationCipher.decrypt(key2, envelope),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  group('2. ConversationStore Migration & Safety Tests', () {
    test('Legacy plaintext migration succeeds and deletes plaintext file', () async {
      final legacyFile = File('${tempDir.path}${Platform.pathSeparator}conversations.json');
      const legacyData = '{"activeId":"100","conversations":[{"id":"100","title":"Legacy Chat","createdAt":"2026-07-25T10:00:00.000Z","updatedAt":"2026-07-25T10:00:00.000Z","messages":[]}]}';
      await legacyFile.writeAsString(legacyData);

      final keyStore = FakeKeyStorage();
      final store = ConversationStore(
        keyStorage: keyStore,
        directoryProvider: () async => tempDir,
      );

      await store.initialize();

      final encFile = File('${tempDir.path}${Platform.pathSeparator}conversations.v2.enc');
      expect(await encFile.exists(), isTrue);
      expect(await legacyFile.exists(), isFalse);
      expect(store.conversations.length, 1);
      expect(store.conversations.first.title, 'Legacy Chat');
      expect(store.storageError, isFalse);
    });

    test('Secure-key write failure preserves plaintext file and sets storage error', () async {
      final legacyFile = File('${tempDir.path}${Platform.pathSeparator}conversations.json');
      const legacyData = '{"activeId":"100","conversations":[{"id":"100","title":"Important Notes","createdAt":"2026-07-25T10:00:00.000Z","updatedAt":"2026-07-25T10:00:00.000Z","messages":[]}]}';
      await legacyFile.writeAsString(legacyData);

      final keyStore = FakeKeyStorage(failWrite: true);
      final store = ConversationStore(
        keyStorage: keyStore,
        directoryProvider: () async => tempDir,
      );

      await store.initialize();

      expect(await legacyFile.exists(), isTrue);
      expect(store.storageError, isTrue);
    });

    test('Secure-key read-back failure preserves plaintext file', () async {
      final legacyFile = File('${tempDir.path}${Platform.pathSeparator}conversations.json');
      await legacyFile.writeAsString('{"activeId":null,"conversations":[]}');

      final keyStore = FakeKeyStorage(failReadBack: true);
      final store = ConversationStore(
        keyStorage: keyStore,
        directoryProvider: () async => tempDir,
      );

      await store.initialize();

      expect(await legacyFile.exists(), isTrue);
      expect(store.storageError, isTrue);
    });

    test('App restart using persisted key loads encrypted history correctly', () async {
      final keyStore = FakeKeyStorage();

      final store1 = ConversationStore(
        keyStorage: keyStore,
        directoryProvider: () async => tempDir,
      );
      await store1.initialize();
      store1.add(ConversationRole.user, 'Persistent message');
      await store1.flush();

      // Simulate app restart
      final store2 = ConversationStore(
        keyStorage: keyStore,
        directoryProvider: () async => tempDir,
      );
      await store2.initialize();

      expect(store2.conversations.length, 1);
      expect(store2.conversations.first.messages.first.text, 'Persistent message');
    });

    test('No plaintext chat content appears in the encrypted file', () async {
      final keyStore = FakeKeyStorage();
      final store = ConversationStore(
        keyStorage: keyStore,
        directoryProvider: () async => tempDir,
      );
      await store.initialize();

      const sensitiveText = 'SENSITIVE_CONFIDENTIAL_USER_PROMPT_98765';
      store.add(ConversationRole.user, sensitiveText);
      await store.flush();

      final encFile = File('${tempDir.path}${Platform.pathSeparator}conversations.v2.enc');
      final encContent = await encFile.readAsString();

      expect(encContent.contains(sensitiveText), isFalse);
    });

    test('deleteStorageFiles removes encrypted files and keys from secure storage', () async {
      final keyStore = FakeKeyStorage();
      final store = ConversationStore(
        keyStorage: keyStore,
        directoryProvider: () async => tempDir,
      );
      await store.initialize();
      store.add(ConversationRole.user, 'To be deleted');
      await store.flush();

      await store.deleteStorageFiles();

      final encFile = File('${tempDir.path}${Platform.pathSeparator}conversations.v2.enc');
      expect(await encFile.exists(), isFalse);
      expect(await keyStore.readKey('finn_ai_conversation_master_key_v2'), isNull);
      expect(store.conversations.isEmpty, isTrue);
    });
  });
}
