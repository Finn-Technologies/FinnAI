import 'dart:io';

import 'package:finn_ai/src/features/conversations/conversation_crypto.dart';
import 'package:finn_ai/src/platform/openharmony_key_storage.dart';
import 'package:finn_ai/src/platform/platform_target.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests run against a real temporary directory rather than a mocked
/// channel, because the storage is now plain `dart:io`: there is no channel to
/// mock, and the thing worth pinning is the on-disk contract.
///
/// Two properties are load-bearing and are asserted explicitly:
///
///  * **the filename and the raw-bytes format match what `SecureKeyPlugin.ets`
///    wrote**, so a HarmonyOS install that already has a key file keeps its
///    conversation history across this change; and
///  * **writes are atomic**, because a truncated key makes every stored
///    conversation permanently unreadable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const alias = ConversationCrypto.keyAlias;
  late Directory sandbox;
  late OpenHarmonyKeyStorage storage;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('finn_ohos_key_test');
    storage = OpenHarmonyKeyStorage(directoryOverride: sandbox);
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  File keyFile() => File('${sandbox.path}/finn_secure_key_$alias');

  group('OpenHarmonyKeyStorage', () {
    test('returns null when no key has been written', () async {
      expect(await storage.readKey(alias), isNull);
    });

    test('round-trips a 32-byte key', () async {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
      await storage.writeKey(alias, key);
      expect(await storage.readKey(alias), key);
    });

    test('survives a store reopen, which is the whole point', () async {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));
      await storage.writeKey(alias, key);

      // A second instance, as a fresh process would build.
      final reopened = OpenHarmonyKeyStorage(directoryOverride: sandbox);
      expect(await reopened.readKey(alias), key);
    });

    test('writes the legacy filename and raw bytes', () async {
      // Byte-for-byte what SecureKeyPlugin.ets produced: raw key bytes (not
      // base64) at <filesDir>/finn_secure_key_<alias>.
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
      await storage.writeKey(alias, key);

      expect(keyFile().existsSync(), isTrue);
      expect(keyFile().readAsBytesSync(), key);
    });

    test('reads a key file written by the previous native plugin', () async {
      final legacy = Uint8List.fromList(List<int>.generate(32, (i) => i * 3));
      await keyFile().writeAsBytes(legacy, flush: true);

      expect(await storage.readKey(alias), legacy);
    });

    test('sanitises the alias into the filename', () async {
      await storage.writeKey('weird/alias name', Uint8List(32));
      expect(
        File('${sandbox.path}/finn_secure_key_weird_alias_name').existsSync(),
        isTrue,
      );
    });

    test('overwrites an existing key', () async {
      await storage.writeKey(alias, Uint8List.fromList(List.filled(32, 1)));
      await storage.writeKey(alias, Uint8List.fromList(List.filled(32, 2)));
      expect(
          await storage.readKey(alias), Uint8List.fromList(List.filled(32, 2)));
    });

    test('leaves no temp file behind after a write', () async {
      await storage.writeKey(alias, Uint8List(32));
      final strays = sandbox
          .listSync()
          .map((e) => e.path.split('/').last)
          .where((name) => name.endsWith('.tmp'))
          .toList();
      expect(strays, isEmpty);
    });

    test('delete removes the key and is idempotent', () async {
      await storage.writeKey(alias, Uint8List(32));
      await storage.deleteKey(alias);
      expect(await storage.readKey(alias), isNull);

      // Deleting twice must not throw; "delete all data" can run on a fresh
      // install where nothing was ever written.
      await storage.deleteKey(alias);
      expect(await storage.readKey(alias), isNull);
    });

    test('reads an empty key file as absent', () async {
      await keyFile().writeAsBytes(const <int>[], flush: true);
      expect(await storage.readKey(alias), isNull);
    });

    test('reads a directory in place of the key file as absent', () async {
      await keyFile().create(recursive: true);
      expect(await storage.readKey(alias), isNull);
    });

    test('creates a missing sandbox directory', () async {
      final nested = Directory('${sandbox.path}/deep/er');
      final nestedStorage = OpenHarmonyKeyStorage(directoryOverride: nested);
      expect(await nested.exists(), isFalse);
      await nestedStorage.writeKey(alias, Uint8List(32));
      expect(await nested.exists(), isTrue);
    });

    test('ignores a path_provider channel that has no answer', () async {
      // Production falls back to the documented sandbox layout when the
      // channel is unreachable, so the override is what keeps this test off
      // the device filesystem.
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      await storage.writeKey(alias, Uint8List(32));
      expect(await storage.readKey(alias), isNotNull);
    });
  });

  group('KeyedConversationCrypto on the sandbox store', () {
    test('prepare/encrypt/decrypt/destroy round-trips', () async {
      final crypto = KeyedConversationCrypto(keyStorage: storage);

      await crypto.prepare();
      expect(await crypto.hasExistingKey(), isTrue);

      final envelope = await crypto.encrypt('hello harmony');
      expect(await crypto.decrypt(envelope), 'hello harmony');

      // The key must be the one on disk, so a second instance can read it.
      final reopened = KeyedConversationCrypto(keyStorage: storage);
      await reopened.prepare();
      expect(await reopened.decrypt(envelope), 'hello harmony');

      await reopened.destroy();
      expect(await reopened.hasExistingKey(), isFalse);
    });

    test('prepare reuses the key already on disk', () async {
      final first = KeyedConversationCrypto(keyStorage: storage);
      await first.prepare();
      final envelope = await first.encrypt('persisted');

      final second = KeyedConversationCrypto(keyStorage: storage);
      await second.prepare();
      expect(await second.decrypt(envelope), 'persisted');
    });
  });

  group('createConversationCrypto', () {
    tearDown(() => debugSetFinnPlatformOverride(null));

    test('OpenHarmony gets the sandbox store, not flutter_secure_storage', () {
      debugSetFinnPlatformOverride(FinnPlatform.openHarmony);
      final crypto = createConversationCrypto() as KeyedConversationCrypto;
      expect(crypto.keyStorage, isA<OpenHarmonyKeyStorage>());
    });

    test('Android keeps the KeyStore-backed storage', () {
      debugSetFinnPlatformOverride(FinnPlatform.android);
      final crypto = createConversationCrypto() as KeyedConversationCrypto;
      expect(crypto.keyStorage, isA<DefaultFlutterSecureKeyStorage>());
    });
  });
}
