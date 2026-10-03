import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where API keys live: the platform's secure storage, never a plain file and
/// never the log. An interface so tests need no platform channel.
abstract class CodeSecretStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
}

/// Android Keystore-backed encrypted preferences, the same mechanism that
/// protects the conversation key.
class PlatformCodeSecretStore implements CodeSecretStore {
  const PlatformCodeSecretStore();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);

  @override
  Future<void> delete(String name) => _storage.delete(key: name);
}

/// Keeps keys in memory only. For tests.
class MemoryCodeSecretStore implements CodeSecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String value) async => values[name] = value;

  @override
  Future<void> delete(String name) async => values.remove(name);
}
