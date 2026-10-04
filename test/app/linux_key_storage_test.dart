import 'dart:io';
import 'dart:typed_data';

import 'package:finn_ai/src/features/conversations/conversation_crypto.dart';
import 'package:finn_ai/src/platform/linux_key_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// A keyring that behaves like a session with no Secret Service running.
class _BrokenKeyring implements SecureKeyStorage {
  @override
  Future<Uint8List?> readKey(String alias) async => throw StateError('no bus');

  @override
  Future<void> writeKey(String alias, Uint8List key) async =>
      throw StateError('no bus');

  @override
  Future<void> deleteKey(String alias) async => throw StateError('no bus');
}

class _MemoryKeyring implements SecureKeyStorage {
  final values = <String, Uint8List>{};

  @override
  Future<Uint8List?> readKey(String alias) async => values[alias];

  @override
  Future<void> writeKey(String alias, Uint8List key) async =>
      values[alias] = key;

  @override
  Future<void> deleteKey(String alias) async => values.remove(alias);
}

void main() {
  late Directory dir;
  final key = Uint8List.fromList(List<int>.generate(32, (i) => i));

  setUp(() => dir = Directory.systemTemp.createTempSync('finn_key_'));
  tearDown(() => dir.deleteSync(recursive: true));

  LinuxKeyStorage storage(SecureKeyStorage keyring) =>
      LinuxKeyStorage(keyring: keyring, directory: () async => dir);

  test('uses the keyring when it works and writes no file', () async {
    final keyring = _MemoryKeyring();
    await storage(keyring).writeKey('alias', key);
    expect(keyring.values['alias'], key);
    expect(dir.listSync(), isEmpty);
  });

  test('falls back to a private file when there is no keyring', () async {
    final s = storage(_BrokenKeyring());
    await s.writeKey('alias', key);
    expect(await s.readKey('alias'), key);
    final file = dir.listSync().single as File;
    expect(file.statSync().mode & 0x1ff, 0x180, reason: 'mode 0600');
  });

  test('a file key survives a keyring appearing later', () async {
    await storage(_BrokenKeyring()).writeKey('alias', key);
    expect(await storage(_MemoryKeyring()).readKey('alias'), key);
  });

  test('delete removes both copies', () async {
    final keyring = _MemoryKeyring();
    final s = storage(keyring);
    await storage(_BrokenKeyring()).writeKey('alias', key);
    await s.writeKey('other', key);
    await s.deleteKey('alias');
    expect(await s.readKey('alias'), isNull);
    expect(keyring.values.containsKey('other'), isTrue);
  });
}
