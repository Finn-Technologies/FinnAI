import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

enum ConversationRole { user, assistant }

@immutable
class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.modelTier = 'Finn AI',
  });

  final String id;
  final ConversationRole role;
  final String text;
  final DateTime createdAt;
  final String modelTier;

  ConversationMessage copyWith({String? text, String? modelTier}) =>
      ConversationMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        createdAt: createdAt,
        modelTier: modelTier ?? this.modelTier,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'modelTier': modelTier,
  };

  factory ConversationMessage.fromJson(Map<String, Object?> json) =>
      ConversationMessage(
        id: json['id'] as String,
        role: ConversationRole.values.byName(json['role'] as String),
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        modelTier: (json['modelTier'] as String?) ?? 'Finn AI',
      );
}

@immutable
class FinnConversation {
  const FinnConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ConversationMessage> messages;

  FinnConversation copyWith({
    String? title,
    DateTime? updatedAt,
    List<ConversationMessage>? messages,
  }) => FinnConversation(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    messages: messages ?? this.messages,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((message) => message.toJson()).toList(),
  };

  factory FinnConversation.fromJson(Map<String, Object?> json) =>
      FinnConversation(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        messages: (json['messages'] as List<Object?>)
            .map(
              (item) => ConversationMessage.fromJson(
                (item as Map<Object?, Object?>).cast<String, Object?>(),
              ),
            )
            .toList(),
      );
}

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

class ConversationStore extends ChangeNotifier {
  ConversationStore({SecureKeyStorage? keyStorage, this._directoryProvider})
    : _keyStorage = keyStorage ?? const DefaultFlutterSecureKeyStorage();

  static final instance = ConversationStore();

  static const String _keyStorageAlias = 'finn_ai_conversation_master_key_v2';
  final SecureKeyStorage _keyStorage;
  final Future<Directory> Function()? _directoryProvider;

  final List<FinnConversation> _conversations = [];
  String? _activeId;
  Timer? _saveDebounce;
  bool _initialized = false;
  Uint8List? _masterKey;
  bool _storageError = false;
  String? _storageErrorMessage;

  List<FinnConversation> get conversations => List.unmodifiable(_conversations);
  FinnConversation? get active => _activeId == null
      ? null
      : _conversations.where((item) => item.id == _activeId).firstOrNull;

  bool get storageError => _storageError;
  String? get storageErrorMessage => _storageErrorMessage;

  Future<Uint8List?> _getOrCreateMasterKey() async {
    if (_masterKey != null) return _masterKey;
    try {
      final existingKey = await _keyStorage.readKey(_keyStorageAlias);
      if (existingKey != null && existingKey.length == 32) {
        _masterKey = existingKey;
        return _masterKey;
      }

      final random = Random.secure();
      final newKey = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        newKey[i] = random.nextInt(256);
      }

      await _keyStorage.writeKey(_keyStorageAlias, newKey);
      final readBack = await _keyStorage.readKey(_keyStorageAlias);

      if (readBack == null || !listEquals(readBack, newKey)) {
        throw StateError('Secure key read-back verification failed.');
      }

      _masterKey = newKey;
      return _masterKey;
    } catch (e) {
      _storageError = true;
      _storageErrorMessage = 'Secure key storage unavailable: $e';
      debugPrint(_storageErrorMessage);
      return null;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (_conversations.isNotEmpty) {
      _initialized = true;
      return;
    }

    try {
      final encFile = await _file(filename: 'conversations.v2.enc');
      final legacyFile = await _file(filename: 'conversations.json');
      final tmpFile = File('${encFile.path}.tmp');

      if (await encFile.exists()) {
        // Encrypted file exists. DO NOT generate a replacement key if key is missing or invalid!
        final existingKey = await _keyStorage.readKey(_keyStorageAlias);
        if (existingKey == null || existingKey.length != 32) {
          _storageError = true;
          _storageErrorMessage =
              'Encrypted history exists but key is missing, invalid or incorrect length.';
          _initialized = true;
          notifyListeners();
          return;
        }

        try {
          final rawEnvelopeStr = await encFile.readAsString();
          final envelope = (jsonDecode(rawEnvelopeStr) as Map<Object?, Object?>)
              .cast<String, Object?>();
          final decryptedJsonStr = await ConversationCipher.decrypt(
            existingKey,
            envelope,
          );
          final data = (jsonDecode(decryptedJsonStr) as Map<Object?, Object?>)
              .cast<String, Object?>();

          _masterKey = existingKey;
          _activeId = data['activeId'] as String?;
          _conversations
            ..clear()
            ..addAll(
              (data['conversations'] as List<Object?>).map(
                (item) => FinnConversation.fromJson(
                  (item as Map<Object?, Object?>).cast<String, Object?>(),
                ),
              ),
            );
        } catch (e) {
          _storageError = true;
          _storageErrorMessage =
              'Failed to decrypt existing encrypted conversation file: $e';
          _initialized = true;
          notifyListeners();
          return;
        }
      } else {
        // Encrypted file does NOT exist. Clean up any invalid temporary file first.
        if (await tmpFile.exists()) {
          try {
            await tmpFile.delete();
          } catch (_) {}
        }

        final key = await _getOrCreateMasterKey();
        if (key == null) {
          _initialized = true;
          notifyListeners();
          return;
        }

        // Check legacy migration if legacy plaintext file exists
        if (await legacyFile.exists()) {
          await _migrateLegacyPlaintext(legacyFile, encFile, key);
        }
      }
    } catch (e) {
      _storageError = true;
      _storageErrorMessage = 'Failed to load conversation store: $e';
      debugPrint(_storageErrorMessage);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _migrateLegacyPlaintext(
    File legacyFile,
    File encFile,
    Uint8List key,
  ) async {
    final tempFile = File('${encFile.path}.tmp');
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final plaintextStr = await legacyFile.readAsString();
      jsonDecode(plaintextStr); // Validate JSON format

      // 1. Write encrypted data to temporary file
      final envelope = await ConversationCipher.encrypt(key, plaintextStr);
      await tempFile.writeAsString(jsonEncode(envelope), flush: true);

      // 2. Read and decrypt temporary file while it is still temporary
      final tmpStr = await tempFile.readAsString();
      final tmpEnv = (jsonDecode(tmpStr) as Map<Object?, Object?>)
          .cast<String, Object?>();
      final tmpDecrypted = await ConversationCipher.decrypt(key, tmpEnv);

      // 3. Verify decrypted content equals source plaintext
      if (tmpDecrypted != plaintextStr) {
        throw StateError('Temporary file decryption verification failed.');
      }

      // 4. Atomically rename to final path
      await tempFile.rename(encFile.path);

      // 5. Read final file and confirm it decrypts correctly before deleting plaintext
      final finalStr = await encFile.readAsString();
      final finalEnv = (jsonDecode(finalStr) as Map<Object?, Object?>)
          .cast<String, Object?>();
      final finalDecrypted = await ConversationCipher.decrypt(key, finalEnv);

      if (finalDecrypted == plaintextStr) {
        await legacyFile.delete();
      } else {
        throw StateError('Final file decryption verification failed.');
      }
    } catch (e) {
      debugPrint('Legacy migration aborted cleanly: $e');
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      if (await encFile.exists()) {
        try {
          await encFile.delete();
        } catch (_) {}
      }
      _storageError = true;
      _storageErrorMessage = 'Migration failed cleanly: $e';
    }
  }

  FinnConversation startNew() {
    final now = DateTime.now();
    final conversation = FinnConversation(
      id: now.microsecondsSinceEpoch.toString(),
      title: 'New conversation',
      createdAt: now,
      updatedAt: now,
      messages: const [],
    );
    _conversations.insert(0, conversation);
    _activeId = conversation.id;
    _changed();
    return conversation;
  }

  void activate(String id) {
    if (_activeId == id || !_conversations.any((item) => item.id == id)) return;
    _activeId = id;
    _changed();
  }

  ConversationMessage add(
    ConversationRole role,
    String text, {
    String modelTier = 'Finn AI',
  }) {
    final conversation = active ?? startNew();
    final now = DateTime.now();
    final message = ConversationMessage(
      id: now.microsecondsSinceEpoch.toString(),
      role: role,
      text: text,
      createdAt: now,
      modelTier: modelTier,
    );
    final messages = [...conversation.messages, message];
    final title = conversation.messages.isEmpty && role == ConversationRole.user
        ? _title(text)
        : conversation.title;
    _replace(
      conversation.copyWith(title: title, updatedAt: now, messages: messages),
    );
    _changed();
    return message;
  }

  ConversationMessage beginExchange(
    String userText, {
    String modelTier = 'Finn AI',
  }) {
    final conversation = active ?? startNew();
    final now = DateTime.now();
    final user = ConversationMessage(
      id: now.microsecondsSinceEpoch.toString(),
      role: ConversationRole.user,
      text: userText,
      createdAt: now,
      modelTier: modelTier,
    );
    final assistant = ConversationMessage(
      id: (now.microsecondsSinceEpoch + 1).toString(),
      role: ConversationRole.assistant,
      text: '',
      createdAt: now,
      modelTier: modelTier,
    );
    final title = conversation.messages.isEmpty
        ? _title(userText)
        : conversation.title;
    _replace(
      conversation.copyWith(
        title: title,
        updatedAt: now,
        messages: [...conversation.messages, user, assistant],
      ),
    );
    _changed();
    return assistant;
  }

  void updateMessage(
    String id,
    String text, {
    bool persistSoon = false,
    bool notify = true,
  }) {
    final conversation = active;
    if (conversation == null) return;
    final index = conversation.messages.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final messages = [...conversation.messages];
    messages[index] = messages[index].copyWith(text: text);
    _replace(
      conversation.copyWith(updatedAt: DateTime.now(), messages: messages),
    );
    if (notify) notifyListeners();
    if (persistSoon) _scheduleSave();
  }

  void renameConversation(String id, String newTitle) {
    final index = _conversations.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    _conversations[index] = _conversations[index].copyWith(title: trimmed);
    _changed();
  }

  void deleteConversation(String id) {
    _conversations.removeWhere((item) => item.id == id);
    if (_activeId == id) {
      _activeId = _conversations.firstOrNull?.id;
    }
    _changed();
  }

  void clearAll() {
    _conversations.clear();
    _activeId = null;
    _changed();
  }

  /// Destroys stored local conversation files and secure encryption key.
  /// Returns a set of failure error messages (empty on complete success).
  Future<Set<String>> deleteStorageFiles() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _conversations.clear();
    _activeId = null;

    final failures = <String>{};

    try {
      final encV2 = await _file(filename: 'conversations.v2.enc');
      if (await encV2.exists()) await encV2.delete();
    } catch (e) {
      failures.add('conversations.v2.enc ($e)');
    }

    try {
      final encV2 = await _file(filename: 'conversations.v2.enc');
      final tmpV2 = File('${encV2.path}.tmp');
      if (await tmpV2.exists()) await tmpV2.delete();
    } catch (e) {
      failures.add('conversations.v2.enc.tmp ($e)');
    }

    try {
      final encV1 = await _file(filename: 'conversations.json.enc');
      if (await encV1.exists()) await encV1.delete();
    } catch (e) {
      failures.add('conversations.json.enc ($e)');
    }

    try {
      final legacyFile = await _file(filename: 'conversations.json');
      if (await legacyFile.exists()) await legacyFile.delete();
    } catch (e) {
      failures.add('conversations.json ($e)');
    }

    try {
      await _keyStorage.deleteKey(_keyStorageAlias);
    } catch (e) {
      failures.add('encryption key ($e)');
    }

    _masterKey = null;
    _storageError = false;
    _storageErrorMessage = null;
    notifyListeners();

    return failures;
  }

  Future<void> flush() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    if (_storageError) {
      debugPrint('Flush aborted: ConversationStore is in storage error state.');
      return;
    }
    try {
      final key = await _getOrCreateMasterKey();
      if (key == null) {
        debugPrint('Flush aborted: Secure key unavailable.');
        return;
      }
      final file = await _file(filename: 'conversations.v2.enc');
      final temp = File('${file.path}.tmp');
      final payload = <String, Object?>{
        'activeId': _activeId,
        'conversations': _conversations.map((item) => item.toJson()).toList(),
      };
      final plaintextStr = jsonEncode(payload);
      final envelope = await ConversationCipher.encrypt(key, plaintextStr);

      await temp.writeAsString(jsonEncode(envelope), flush: true);
      await temp.rename(file.path);
    } catch (e) {
      _storageError = true;
      _storageErrorMessage = 'Flush error: $e';
      debugPrint(_storageErrorMessage);
    }
  }

  void _replace(FinnConversation conversation) {
    final index = _conversations.indexWhere(
      (item) => item.id == conversation.id,
    );
    if (index >= 0) _conversations[index] = conversation;
    _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  void _changed() {
    notifyListeners();
    if (!_storageError) {
      _scheduleSave();
    }
  }

  void _scheduleSave() {
    if (_storageError) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 420), flush);
  }

  Future<File> _file({required String filename}) async {
    final root = _directoryProvider != null
        ? await _directoryProvider()
        : await getApplicationSupportDirectory();
    return File('${root.path}${Platform.pathSeparator}$filename');
  }

  static String _title(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length <= 42 ? compact : '${compact.substring(0, 39)}…';
  }
}
