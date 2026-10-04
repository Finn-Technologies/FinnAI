import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../platform/linux_key_storage.dart';
import '../../platform/openharmony_key_storage.dart';
import '../../platform/platform_target.dart';

/// AES-256-GCM cipher using the maintained `cryptography` package.
class ConversationCipher {
  static final AesGcm _algorithm = AesGcm.with256bits();

  /// Encrypts plaintext string using AES-256-GCM.
  static Future<Map<String, String>> encrypt(
    Uint8List keyBytes,
    String plaintext, {
    List<int>? customNonce,
  }) async {
    if (keyBytes.length != 32) {
      throw ArgumentError('AES-256-GCM requires a 32-byte (256-bit) key.');
    }
    final secretKey = SecretKey(keyBytes);
    final nonce = customNonce ?? _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'version': '2',
      'algorithm': 'AES-256-GCM',
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  /// Decrypts envelope using AES-256-GCM.
  static Future<String> decrypt(
    Uint8List keyBytes,
    Map<String, Object?> envelope,
  ) async {
    if (keyBytes.length != 32) {
      throw ArgumentError('AES-256-GCM requires a 32-byte (256-bit) key.');
    }
    final version = envelope['version']?.toString();
    if (version != '2' || envelope['algorithm'] != 'AES-256-GCM') {
      throw const FormatException('Unsupported or legacy cipher version');
    }

    final nonce = base64Decode(envelope['nonce'] as String);
    final cipherText = base64Decode(envelope['ciphertext'] as String);
    final macBytes = base64Decode(envelope['mac'] as String);

    final secretKey = SecretKey(keyBytes);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

    final decryptedBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return utf8.decode(decryptedBytes);
  }
}

/// Payload for off-main-isolate AES-GCM encryption (must be sendable).
class _CipherEncryptPayload {
  const _CipherEncryptPayload(this.keyBytes, this.plaintext, this.customNonce);
  final Uint8List keyBytes;
  final String plaintext;
  final List<int>? customNonce;
}

Future<Map<String, String>> _encryptPayloadOnIsolate(_CipherEncryptPayload p) =>
    ConversationCipher.encrypt(p.keyBytes, p.plaintext,
        customNonce: p.customNonce);

class _CipherDecryptPayload {
  const _CipherDecryptPayload(this.keyBytes, this.envelope);
  final Uint8List keyBytes;
  final Map<String, Object?> envelope;
}

Future<String> _decryptPayloadOnIsolate(_CipherDecryptPayload p) =>
    ConversationCipher.decrypt(p.keyBytes, p.envelope);

Future<Map<String, String>> encryptOffMain(Uint8List key, String plaintext) {
  try {
    return compute(
        _encryptPayloadOnIsolate, _CipherEncryptPayload(key, plaintext, null));
  } catch (_) {
    return ConversationCipher.encrypt(key, plaintext);
  }
}

Future<String> decryptOffMain(Uint8List key, Map<String, Object?> envelope) {
  try {
    return compute(
        _decryptPayloadOnIsolate, _CipherDecryptPayload(key, envelope));
  } catch (_) {
    return ConversationCipher.decrypt(key, envelope);
  }
}

/// Abstract key storage interface for secure key persistence and unit test injection.
abstract class SecureKeyStorage {
  Future<Uint8List?> readKey(String alias);
  Future<void> writeKey(String alias, Uint8List key);
  Future<void> deleteKey(String alias);
}

/// Default implementation backed by FlutterSecureStorage with encryptedSharedPreferences.
class DefaultFlutterSecureKeyStorage implements SecureKeyStorage {
  const DefaultFlutterSecureKeyStorage();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<Uint8List?> readKey(String alias) async {
    final b64 = await _secureStorage.read(key: alias);
    return (b64 != null && b64.isNotEmpty) ? base64Decode(b64) : null;
  }

  @override
  Future<void> writeKey(String alias, Uint8List key) async {
    await _secureStorage.write(key: alias, value: base64Encode(key));
  }

  @override
  Future<void> deleteKey(String alias) async {
    await _secureStorage.delete(key: alias);
  }
}

/// Encrypts and decrypts the conversation snapshot.
///
/// Every platform stores the same AES-256-GCM envelope
/// (`{ version, algorithm, nonce, ciphertext, mac }`), but the *key* lives in a
/// different keystore: Android in the AndroidKeyStore via
/// `flutter_secure_storage`, HarmonyOS in HUKS, where symmetric keys cannot be
/// exported at all. Rather than spread that branch over the store, both live
/// behind this interface.
abstract class ConversationCrypto {
  /// Alias the key is filed under. Stable across platforms so an upgraded app
  /// finds the key it wrote before.
  static const String keyAlias = 'finn_ai_conversation_master_key_v2';

  /// Resolves or creates the key material.
  ///
  /// Throws when the keystore is unusable. `ConversationStore` turns that into
  /// its sticky storage error, which is what keeps it from silently
  /// overwriting history it cannot decrypt.
  Future<void> prepare();

  /// Whether a key already exists, i.e. whether an encrypted file found on
  /// disk can be read back.
  Future<bool> hasExistingKey();

  Future<Map<String, String>> encrypt(String plaintext);

  Future<String> decrypt(Map<String, Object?> envelope);

  /// Destroys the key, making every existing envelope unreadable. Called by
  /// "delete all data".
  Future<void> destroy();
}

/// Chooses the key storage for the running platform.
///
/// `flutter_secure_storage` cannot be used on OpenHarmony: its Dart side
/// throws `UnsupportedError('unsupported_platform')` for every call there, so
/// the platform gets the sandbox-backed store instead.
ConversationCrypto createConversationCrypto() {
  if (isOpenHarmony) {
    return KeyedConversationCrypto(
      keyStorage: const OpenHarmonyKeyStorage(),
    );
  }
  if (finnPlatform == FinnPlatform.linux) {
    return KeyedConversationCrypto(keyStorage: LinuxKeyStorage());
  }
  return KeyedConversationCrypto();
}

/// Android / iOS / desktop: AES-GCM in Dart under a master key held by
/// `flutter_secure_storage`.
class KeyedConversationCrypto implements ConversationCrypto {
  KeyedConversationCrypto({
    SecureKeyStorage keyStorage = const DefaultFlutterSecureKeyStorage(),
  }) : _keyStorage = keyStorage;

  final SecureKeyStorage _keyStorage;

  /// The keystore this instance uses. Exposed so a test can assert that a
  /// platform gets the storage it is meant to get.
  @visibleForTesting
  SecureKeyStorage get keyStorage => _keyStorage;

  Uint8List? _key;

  @override
  Future<void> prepare() async {
    final existing = await _keyStorage.readKey(ConversationCrypto.keyAlias);
    if (existing != null && existing.length == 32) {
      _key = existing;
      return;
    }

    final random = Random.secure();
    final newKey = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      newKey[i] = random.nextInt(256);
    }

    await _keyStorage.writeKey(ConversationCrypto.keyAlias, newKey);
    // Read back: a keystore that silently drops writes would otherwise leave
    // the user with an unreadable history and no way to tell.
    final readBack = await _keyStorage.readKey(ConversationCrypto.keyAlias);
    if (readBack == null ||
        readBack.length != 32 ||
        !listEquals(readBack, newKey)) {
      throw StateError('Secure key read-back verification failed.');
    }
    _key = newKey;
  }

  @override
  Future<bool> hasExistingKey() async {
    final key = await _keyStorage.readKey(ConversationCrypto.keyAlias);
    return key != null && key.length == 32;
  }

  @override
  Future<Map<String, String>> encrypt(String plaintext) async {
    final key = _requireKey();
    return encryptOffMain(key, plaintext);
  }

  @override
  Future<String> decrypt(Map<String, Object?> envelope) async {
    final key = _requireKey();
    return decryptOffMain(key, envelope);
  }

  @override
  Future<void> destroy() async {
    _key = null;
    await _keyStorage.deleteKey(ConversationCrypto.keyAlias);
  }

  Uint8List _requireKey() {
    final key = _key;
    if (key == null) {
      throw StateError('prepare() must succeed before encrypt/decrypt.');
    }
    return key;
  }
}
