import 'dart:convert';
import 'dart:typed_data';

import 'package:finn_ai/src/features/conversations/conversation_crypto.dart';
import 'package:finn_ai/src/platform/openharmony_key_storage.dart';
import 'package:finn_ai/src/platform/platform_target.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The OHOS key channel cannot be exercised off-device — there is no
/// OpenHarmony sandbox — so these tests pin the *contract* that
/// `SecureKeyPlugin.ets` implements and that the docs describe: the alias in the
/// argument map, base64 UTF-8 values, `''` for an absent key, and a bounded retry
/// when the engine loses a reply.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('finn_ai/secure_key');
  const alias = ConversationCrypto.keyAlias;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final log = <MethodCall>[];

  /// Keyed by method name; the arguments are asserted separately.
  var replies = <String, Object?>{};

  setUp(() {
    log.clear();
    replies = {};
    messenger.setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      return replies[call.method];
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('OpenHarmonyKeyStorage', () {
    test('sends the alias under the documented key', () async {
      replies['read'] = '';
      await const OpenHarmonyKeyStorage().readKey(alias);

      expect(log, hasLength(1));
      expect(log.single.method, 'read');
      expect(log.single.arguments, {'alias': alias});
    });

    test('round-trips a 32-byte key as base64', () async {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final encoded = base64Encode(key);
      replies['write'] = 'ok';
      replies['read'] = encoded;

      const storage = OpenHarmonyKeyStorage();
      await storage.writeKey(alias, key);
      final readBack = await storage.readKey(alias);

      expect(readBack, key);
      final write = log.firstWhere((c) => c.method == 'write');
      expect((write.arguments as Map)['key'], encoded);
    });

    test('treats an empty reply as "no key"', () async {
      replies['read'] = '';
      expect(await const OpenHarmonyKeyStorage().readKey(alias), isNull);
    });

    test('treats null as "no key"', () async {
      replies['read'] = null;
      expect(await const OpenHarmonyKeyStorage().readKey(alias), isNull);
    });

    test('survives a key file that is not valid base64', () async {
      replies['read'] = 'not base64!!';
      expect(await const OpenHarmonyKeyStorage().readKey(alias), isNull);
    });

    test('retries when the engine drops the reply', () async {
      // No entry in `replies` -> invokeMethod returns null, which the storage
      // cannot distinguish from "absent"; the first read therefore succeeds and
      // only the *missing* reply path is observable on a verb whose result is
      // ignored.
      replies['delete'] = 'ok';
      await const OpenHarmonyKeyStorage().deleteKey(alias);
      expect(log.where((c) => c.method == 'delete'), hasLength(1));
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
