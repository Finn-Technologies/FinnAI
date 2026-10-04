import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../features/conversations/conversation_crypto.dart';

/// [SecureKeyStorage] for desktop Linux.
///
/// The conversation key belongs in the desktop keyring (libsecret: GNOME
/// Keyring, KWallet's Secret Service bridge), and that is tried first. Plenty
/// of Linux sessions have no keyring running at all (a bare window manager, a
/// container, a fresh VM), where `flutter_secure_storage` throws on every
/// call. Rather than leave the app unable to open its history there, the key
/// falls back to a `0600` file in the app's private data directory.
///
/// Reads look in both places, so a key written to the file before a keyring
/// appeared is still found afterwards and history never becomes unreadable
/// because the user installed a keyring. The weaker file fallback is recorded
/// in docs/architecture/SECURITY_AND_PRIVACY_ARCHITECTURE.md.
class LinuxKeyStorage implements SecureKeyStorage {
  LinuxKeyStorage({
    SecureKeyStorage keyring = const DefaultFlutterSecureKeyStorage(),
    Future<Directory> Function()? directory,
  })  : _keyring = keyring,
        _directory = directory ?? _defaultDirectory;

  final SecureKeyStorage _keyring;
  final Future<Directory> Function() _directory;

  static Future<Directory> _defaultDirectory() async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}${Platform.pathSeparator}secure');
  }

  @override
  Future<Uint8List?> readKey(String alias) async {
    try {
      final fromKeyring = await _keyring.readKey(alias);
      if (fromKeyring != null) return fromKeyring;
    } catch (error) {
      debugPrint('FINN_SECURE_KEY keyring unavailable on read: $error');
    }
    return _readFile(alias);
  }

  @override
  Future<void> writeKey(String alias, Uint8List key) async {
    try {
      await _keyring.writeKey(alias, key);
      final readBack = await _keyring.readKey(alias);
      if (readBack != null && listEquals(readBack, key)) return;
      debugPrint('FINN_SECURE_KEY keyring did not keep the key; using a file');
    } catch (error) {
      debugPrint('FINN_SECURE_KEY keyring unavailable on write: $error');
    }
    await _writeFile(alias, key);
  }

  @override
  Future<void> deleteKey(String alias) async {
    try {
      await _keyring.deleteKey(alias);
    } catch (error) {
      debugPrint('FINN_SECURE_KEY keyring unavailable on delete: $error');
    }
    final file = await _file(alias);
    if (await file.exists()) await file.delete();
  }

  Future<File> _file(String alias) async {
    final directory = await _directory();
    final safe = alias.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return File('${directory.path}${Platform.pathSeparator}$safe.key');
  }

  Future<Uint8List?> _readFile(String alias) async {
    try {
      final file = await _file(alias);
      if (!await file.exists()) return null;
      final b64 = (await file.readAsString()).trim();
      return b64.isEmpty ? null : base64Decode(b64);
    } on FormatException catch (error) {
      debugPrint('FINN_SECURE_KEY unreadable key file for "$alias": $error');
      return null;
    }
  }

  Future<void> _writeFile(String alias, Uint8List key) async {
    final file = await _file(alias);
    await file.parent.create(recursive: true);
    await _restrict(file.parent, '700');
    // Create the file empty and restrict it before the key is written, so the
    // secret is never on disk readable by another user, even briefly.
    await file.writeAsString('');
    await _restrict(file, '600');
    await file.writeAsString(base64Encode(key), flush: true);
  }

  Future<void> _restrict(FileSystemEntity entity, String mode) async {
    try {
      await Process.run('chmod', [mode, entity.path]);
    } catch (error) {
      debugPrint('FINN_SECURE_KEY could not restrict ${entity.path}: $error');
    }
  }
}
