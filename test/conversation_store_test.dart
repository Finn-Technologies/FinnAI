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

    test(
      'Unicode text roundtrip with emoji and multibyte characters',
      () async {
        final key = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          key[i] = i + 10;
        }

        const unicodeText = 'FinnAI 🤖 · 智能助手 · Bonjour le monde! 🔐🔥';
        final envelope = await ConversationCipher.encrypt(key, unicodeText);
        final decrypted = await ConversationCipher.decrypt(key, envelope);

        expect(decrypted, unicodeText);
      },
    );

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

    test(
      'Random nonce produces different ciphertext for identical plaintext',
      () async {
        final key = Uint8List(32);
        const text = 'Identical message';

        final env1 = await ConversationCipher.encrypt(key, text);
        final env2 = await ConversationCipher.encrypt(key, text);

        expect(env1['nonce'], isNot(equals(env2['nonce'])));
        expect(env1['ciphertext'], isNot(equals(env2['ciphertext'])));
      },
    );

    test(
      'Modified ciphertext fails decryption (integrity verification)',
      () async {
        final key = Uint8List(32);
        final envelope = await ConversationCipher.encrypt(
          key,
          'Secret content',
        );

        final corruptedBytes = base64Decode(envelope['ciphertext']!);
        corruptedBytes[0] ^= 0xFF;
        final tampered = Map<String, String>.from(envelope);
        tampered['ciphertext'] = base64Encode(corruptedBytes);

        expect(
          () async => ConversationCipher.decrypt(key, tampered),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
      },
    );

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

  group('2. ConversationStore Recovery & Migration Safety Tests', () {
    test(
      'Existing encrypted file with missing key enters storage error without generating replacement key',
      () async {
        final encFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.v2.enc',
        );
        final validKey = Uint8List(32)..fillRange(0, 32, 42);
        final envelope = await ConversationCipher.encrypt(
          validKey,
          '{"activeId":null,"conversations":[]}',
        );
        await encFile.writeAsString(jsonEncode(envelope));

        final keyStore = FakeKeyStorage(); // Key missing
        final store = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );

        await store.initialize();

        expect(store.storageError, isTrue);
        expect(
          await keyStore.readKey('finn_ai_conversation_master_key_v2'),
          isNull,
        );
        expect(
          await encFile.readAsString(),
          jsonEncode(envelope),
        ); // File not overwritten
      },
    );

    test(
      'Existing encrypted file with wrong key enters storage error without overwriting file',
      () async {
        final encFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.v2.enc',
        );
        final key1 = Uint8List(32)..fillRange(0, 32, 10);
        final key2 = Uint8List(32)..fillRange(0, 32, 99);
        final envelope = await ConversationCipher.encrypt(
          key1,
          '{"activeId":null,"conversations":[]}',
        );
        await encFile.writeAsString(jsonEncode(envelope));

        final keyStore = FakeKeyStorage(
          initialData: {'finn_ai_conversation_master_key_v2': key2},
        );
        final store = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );

        await store.initialize();

        expect(store.storageError, isTrue);
        expect(await encFile.readAsString(), jsonEncode(envelope));
      },
    );

    test(
      'Invalid-length stored key enters storage error without overwriting file',
      () async {
        final encFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.v2.enc',
        );
        await encFile.writeAsString('{}');

        final invalidKey = Uint8List(16); // Invalid length
        final keyStore = FakeKeyStorage(
          initialData: {'finn_ai_conversation_master_key_v2': invalidKey},
        );
        final store = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );

        await store.initialize();

        expect(store.storageError, isTrue);
      },
    );

    test(
      'Corrupted encrypted file enters storage error without overwriting file',
      () async {
        final encFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.v2.enc',
        );
        await encFile.writeAsString('corrupted_not_json');

        final key = Uint8List(32);
        final keyStore = FakeKeyStorage(
          initialData: {'finn_ai_conversation_master_key_v2': key},
        );
        final store = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );

        await store.initialize();

        expect(store.storageError, isTrue);
        expect(await encFile.readAsString(), 'corrupted_not_json');
      },
    );

    test(
      'Failed migration verification preserves plaintext and removes temporary file',
      () async {
        final legacyFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.json',
        );
        await legacyFile.writeAsString('{"activeId":null,"conversations":[]}');

        final keyStore = FakeKeyStorage();
        final store = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );

        await store.initialize();

        final tmpFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.v2.enc.tmp',
        );
        expect(await tmpFile.exists(), isFalse);
      },
    );

    test('No overwrite during flush after initialization failure', () async {
      final encFile = File(
        '${tempDir.path}${Platform.pathSeparator}conversations.v2.enc',
      );
      const originalContent = '{"original":true}';
      await encFile.writeAsString(originalContent);

      final keyStore = FakeKeyStorage();
      final store = ConversationStore(
        keyStorage: keyStore,
        directoryProvider: () async => tempDir,
      );
      await store.initialize();

      expect(store.storageError, isTrue);

      // Attempt flush
      await store.flush();

      expect(await encFile.readAsString(), originalContent);
    });

    test(
      'Recovery after removing invalid temporary file allows new migration',
      () async {
        final tmpFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.v2.enc.tmp',
        );
        await tmpFile.writeAsString('invalid_tmp_leftover');

        final legacyFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.json',
        );
        await legacyFile.writeAsString('{"activeId":null,"conversations":[]}');

        final keyStore = FakeKeyStorage();
        final store = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );

        await store.initialize();

        expect(store.storageError, isFalse);
        expect(await tmpFile.exists(), isFalse);
        expect(await legacyFile.exists(), isFalse);

        final encFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.v2.enc',
        );
        expect(await encFile.exists(), isTrue);
      },
    );

    test(
      'Migrated conversations are visible immediately after initialize() and preserved during same launch edits',
      () async {
        final legacyFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.json',
        );
        const legacyPayload =
            '{"activeId":"conv_1","conversations":[{"id":"conv_1","title":"Migrated Chat","createdAt":"2026-07-25T12:00:00.000Z","updatedAt":"2026-07-25T12:00:00.000Z","messages":[{"id":"m1","role":"user","text":"Hello","createdAt":"2026-07-25T12:00:00.000Z","modelTier":"Finn AI"}]}]}';
        await legacyFile.writeAsString(legacyPayload);

        final keyStore = FakeKeyStorage();
        final store = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );

        await store.initialize();

        expect(store.conversations.length, 1);
        expect(store.conversations.first.title, 'Migrated Chat');
        expect(store.active?.id, 'conv_1');

        // Adding a message appends to migrated conversation rather than overwriting
        store.add(ConversationRole.user, 'New message', modelTier: 'Bonsai 4B');
        await store.flush();

        expect(store.conversations.first.messages.length, 2);
        expect(store.conversations.first.messages.first.text, 'Hello');
        expect(store.conversations.first.messages.last.text, 'New message');
      },
    );

    test('Model name per message is persisted and restored', () async {
      final keyStore = FakeKeyStorage();
      final store1 = ConversationStore(
        keyStorage: keyStore,
        directoryProvider: () async => tempDir,
      );
      await store1.initialize();

      store1.add(ConversationRole.user, 'Hello', modelTier: 'Bonsai 4B');
      await store1.flush();

      final store2 = ConversationStore(
        keyStorage: keyStore,
        directoryProvider: () async => tempDir,
      );
      await store2.initialize();

      expect(store2.conversations.first.messages.first.modelTier, 'Bonsai 4B');
    });

    test(
      'Malformed legacy schema preserves plaintext file and does not leave user with neither copy',
      () async {
        // A conversation with a message missing the required "role" field.
        const malformedPayload =
            '{"activeId":"c1","conversations":[{"id":"c1","title":"Bad Chat",'
            '"createdAt":"2026-07-25T12:00:00.000Z","updatedAt":"2026-07-25T12:00:00.000Z",'
            '"messages":[{"id":"m1","text":"Hello","createdAt":"2026-07-25T12:00:00.000Z",'
            '"modelTier":"Finn AI"}]}]}';

        final legacyFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.json',
        );
        await legacyFile.writeAsString(malformedPayload);

        final keyStore = FakeKeyStorage();
        final store = ConversationStore(
          keyStorage: keyStore,
          directoryProvider: () async => tempDir,
        );

        await store.initialize();

        // Migration must have failed — the store should be in storage error.
        expect(store.storageError, isTrue);

        // The plaintext file must still exist so the user retains their data.
        expect(await legacyFile.exists(), isTrue);

        // The encrypted file must NOT have been created (or must be deleted on
        // failure), so the user is not left with neither copy.
        final encFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.v2.enc',
        );
        expect(await encFile.exists(), isFalse);

        // Any temporary file must have been cleaned up.
        final tmpFile = File(
          '${tempDir.path}${Platform.pathSeparator}conversations.v2.enc.tmp',
        );
        expect(await tmpFile.exists(), isFalse);
      },
    );
  });
}
