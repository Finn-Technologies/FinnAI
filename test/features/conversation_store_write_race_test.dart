import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';

class RaceKeyStorage implements SecureKeyStorage {
  final Map<String, Uint8List> _data = {};

  @override
  Future<Uint8List?> readKey(String alias) async => _data[alias];

  @override
  Future<void> writeKey(String alias, Uint8List key) async {
    _data[alias] = key;
  }

  @override
  Future<void> deleteKey(String alias) async {
    _data.remove(alias);
  }
}

/// Regression coverage for the shared temp-file race that used to make the
/// encrypted conversation store drop snapshots.
///
/// Writers previously all staged to one fixed path
/// (`conversations.v2.enc.tmp`), which `initialize()` also deletes when the
/// main file is missing. Two stores opened on the same directory — the normal
/// shape of a reload-after-restart — could therefore rename away or delete a
/// temp file another writer was about to rename. The loser raised ENOENT,
/// latched `storageError`, and silently stopped persisting. It surfaced as a
/// flaky `flutter test` failure and a red `tool/verify_release.sh`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finn_store_race_');
  });
  tearDown(() async {
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  ConversationStore openStore(SecureKeyStorage keys, Directory dir) =>
      ConversationStore(
        keyStorage: keys,
        directoryProvider: () async => dir,
        maxConversationsInMemory: 80,
      );

  test('initialize() leaves a fresh temp file from another writer alone',
      () async {
    final inFlight = File(
      '${tempDir.path}${Platform.pathSeparator}'
      'conversations.v2.enc.7-1700000000000000.tmp',
    );
    await inFlight.writeAsString('in-flight');

    final store = openStore(RaceKeyStorage(), tempDir);
    await store.initialize();

    expect(
      await inFlight.exists(),
      isTrue,
      reason: 'initialize() deleted a temp file a live writer may own',
    );
  });

  test('a flush in flight while another store initializes still lands',
      () async {
    final keys = RaceKeyStorage();
    final store = openStore(keys, tempDir);
    await store.initialize();
    for (var i = 0; i < 85; i++) {
      store.startNew();
      store.add(ConversationRole.user, 'message $i');
    }

    final pending = store.flush();
    final reloaded = openStore(keys, tempDir);
    await reloaded.initialize();
    await pending;

    expect(store.storageError, isFalse,
        reason: 'flush latched: ${store.storageErrorMessage}');
    expect(
      await File(
        '${tempDir.path}${Platform.pathSeparator}conversations.v2.enc',
      ).exists(),
      isTrue,
      reason: 'main encrypted file was never written',
    );

    final verify = openStore(keys, tempDir);
    await verify.initialize();
    expect(verify.storageError, isFalse);
    expect(verify.residentConversationCount, 80);
  });

  test('two stores writing the same directory both keep their data', () async {
    final keys = RaceKeyStorage();

    for (var iteration = 0; iteration < 20; iteration++) {
      final dir = Directory(
        '${tempDir.path}${Platform.pathSeparator}round_$iteration',
      );
      await dir.create(recursive: true);

      final a = openStore(keys, dir);
      await a.initialize();
      a.startNew();
      a.add(ConversationRole.user, 'from a');

      final b = openStore(keys, dir);
      await b.initialize();
      b.startNew();
      b.add(ConversationRole.user, 'from b');

      await Future.wait<void>([a.flush(), b.flush()]);

      expect(a.storageError, isFalse,
          reason: 'round $iteration writer a latched: '
              '${a.storageErrorMessage}');
      expect(b.storageError, isFalse,
          reason: 'round $iteration writer b latched: '
              '${b.storageErrorMessage}');

      final verify = openStore(keys, dir);
      await verify.initialize();
      expect(verify.storageError, isFalse,
          reason: 'round $iteration reload failed: '
              '${verify.storageErrorMessage}');
      expect(verify.residentConversationCount, greaterThan(0),
          reason: 'round $iteration lost every conversation');
    }
  });
}
