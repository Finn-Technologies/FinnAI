import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
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
  });

  final String id;
  final ConversationRole role;
  final String text;
  final DateTime createdAt;

  ConversationMessage copyWith({
    String? text,
  }) => ConversationMessage(
    id: id,
    role: role,
    text: text ?? this.text,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ConversationMessage.fromJson(Map<String, Object?> json) =>
      ConversationMessage(
        id: json['id'] as String,
        role: ConversationRole.values.byName(json['role'] as String),
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
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

/// Pure Dart AES-256 Engine for CTR mode.
class _Aes256Engine {
  _Aes256Engine(List<int> key) {
    if (key.length != 32) {
      throw ArgumentError('AES-256 requires a 32-byte key.');
    }
    _expandKey(Uint8List.fromList(key));
  }

  static const List<int> _sbox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
  ];

  static const List<int> _rcon = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
  ];

  late final Int32List _w;

  void _expandKey(Uint8List key) {
    _w = Int32List(60);
    for (var i = 0; i < 8; i++) {
      _w[i] = (key[4 * i] << 24) |
          (key[4 * i + 1] << 16) |
          (key[4 * i + 2] << 8) |
          key[4 * i + 3];
    }
    for (var i = 8; i < 60; i++) {
      var temp = _w[i - 1];
      if (i % 8 == 0) {
        temp = _subWord(_rotWord(temp)) ^ (_rcon[i ~/ 8] << 24);
      } else if (i % 8 == 4) {
        temp = _subWord(temp);
      }
      _w[i] = _w[i - 8] ^ temp;
    }
  }

  static int _rotWord(int w) => ((w << 8) & 0xffffffff) | ((w >> 24) & 0xff);

  static int _subWord(int w) =>
      (_sbox[(w >> 24) & 0xff] << 24) |
      (_sbox[(w >> 16) & 0xff] << 16) |
      (_sbox[(w >> 8) & 0xff] << 8) |
      _sbox[w & 0xff];

  Uint8List encryptBlock(Uint8List input) {
    var state = Uint8List(16);
    for (var i = 0; i < 4; i++) {
      final word = _w[i];
      state[i * 4] = (word >> 24) & 0xff;
      state[i * 4 + 1] = (word >> 16) & 0xff;
      state[i * 4 + 2] = (word >> 8) & 0xff;
      state[i * 4 + 3] = word & 0xff;
      for (var row = 0; row < 4; row++) {
        state[i * 4 + row] ^= input[row * 4 + i];
      }
    }

    for (var round = 1; round < 14; round++) {
      _subBytes(state);
      _shiftRows(state);
      _mixColumns(state);
      _addRoundKey(state, round);
    }

    _subBytes(state);
    _shiftRows(state);
    _addRoundKey(state, 14);

    var out = Uint8List(16);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        out[r * 4 + c] = state[c * 4 + r];
      }
    }
    return out;
  }

  static void _subBytes(Uint8List state) {
    for (var i = 0; i < 16; i++) {
      state[i] = _sbox[state[i]];
    }
  }

  static void _shiftRows(Uint8List state) {
    var t = state[1]; state[1] = state[5]; state[5] = state[9]; state[9] = state[13]; state[13] = t;
    t = state[2]; state[2] = state[10]; state[10] = t;
    t = state[6]; state[6] = state[14]; state[14] = t;
    t = state[15]; state[15] = state[11]; state[11] = state[7]; state[7] = state[3]; state[3] = t;
  }

  static void _mixColumns(Uint8List state) {
    for (var c = 0; c < 4; c++) {
      final i = c * 4;
      final a0 = state[i], a1 = state[i + 1], a2 = state[i + 2], a3 = state[i + 3];
      state[i] = _gmul(2, a0) ^ _gmul(3, a1) ^ a2 ^ a3;
      state[i + 1] = a0 ^ _gmul(2, a1) ^ _gmul(3, a2) ^ a3;
      state[i + 2] = a0 ^ a1 ^ _gmul(2, a2) ^ _gmul(3, a3);
      state[i + 3] = _gmul(3, a0) ^ a1 ^ a2 ^ _gmul(2, a3);
    }
  }

  static int _gmul(int a, int b) {
    var p = 0;
    var hiBit = 0;
    for (var counter = 0; counter < 8; counter++) {
      if ((b & 1) != 0) p ^= a;
      hiBit = a & 0x80;
      a = (a << 1) & 0xff;
      if (hiBit != 0) a ^= 0x1b;
      b >>= 1;
    }
    return p;
  }

  void _addRoundKey(Uint8List state, int round) {
    for (var c = 0; c < 4; c++) {
      final w = _w[round * 4 + c];
      state[c * 4] ^= (w >> 24) & 0xff;
      state[c * 4 + 1] ^= (w >> 16) & 0xff;
      state[c * 4 + 2] ^= (w >> 8) & 0xff;
      state[c * 4 + 3] ^= w & 0xff;
    }
  }
}

/// Authenticated Encryption (AES-256-CTR + HMAC-SHA256 Encrypt-Then-MAC).
class ConversationCipher {
  static Map<String, Object?> encrypt(Uint8List key, String plainText) {
    if (key.length < 64) {
      throw ArgumentError('Key must be at least 64 bytes (32 enc + 32 mac)');
    }
    final encKey = key.sublist(0, 32);
    final macKey = key.sublist(32, 64);
    final engine = _Aes256Engine(encKey);

    final random = Random.secure();
    final iv = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      iv[i] = random.nextInt(256);
    }

    final bytes = utf8.encode(plainText);
    final cipherText = Uint8List(bytes.length);
    final counter = Uint8List.fromList(iv);

    for (var i = 0; i < bytes.length; i += 16) {
      final keystream = engine.encryptBlock(counter);
      final blockLen = min(16, bytes.length - i);
      for (var j = 0; j < blockLen; j++) {
        cipherText[i + j] = bytes[i + j] ^ keystream[j];
      }
      for (var k = 15; k >= 0; k--) {
        counter[k] = (counter[k] + 1) & 0xff;
        if (counter[k] != 0) break;
      }
    }

    final hmac = Hmac(sha256, macKey);
    final macPayload = Uint8List(iv.length + cipherText.length)
      ..setAll(0, iv)
      ..setAll(iv.length, cipherText);
    final mac = hmac.convert(macPayload).bytes;

    return {
      'version': 1,
      'algorithm': 'AES-256-CTR-HMAC-SHA256',
      'iv': base64Encode(iv),
      'ciphertext': base64Encode(cipherText),
      'mac': base64Encode(mac),
    };
  }

  static String decrypt(Uint8List key, Map<String, Object?> envelope) {
    if (envelope['version'] != 1 || envelope['algorithm'] != 'AES-256-CTR-HMAC-SHA256') {
      throw FormatException('Unsupported encryption format');
    }

    final encKey = key.sublist(0, 32);
    final macKey = key.sublist(32, 64);
    final iv = base64Decode(envelope['iv'] as String);
    final cipherText = base64Decode(envelope['ciphertext'] as String);
    final mac = base64Decode(envelope['mac'] as String);

    final hmac = Hmac(sha256, macKey);
    final macPayload = Uint8List(iv.length + cipherText.length)
      ..setAll(0, iv)
      ..setAll(iv.length, cipherText);
    final expectedMac = hmac.convert(macPayload).bytes;

    if (!_constantTimeEquals(mac, expectedMac)) {
      throw FormatException('Authentication tag mismatch. Data corrupted or key invalid.');
    }

    final engine = _Aes256Engine(encKey);
    final plainTextBytes = Uint8List(cipherText.length);
    final counter = Uint8List.fromList(iv);

    for (var i = 0; i < cipherText.length; i += 16) {
      final keystream = engine.encryptBlock(counter);
      final blockLen = min(16, cipherText.length - i);
      for (var j = 0; j < blockLen; j++) {
        plainTextBytes[i + j] = cipherText[i + j] ^ keystream[j];
      }
      for (var k = 15; k >= 0; k--) {
        counter[k] = (counter[k] + 1) & 0xff;
        if (counter[k] != 0) break;
      }
    }

    return utf8.decode(plainTextBytes);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var res = 0;
    for (var i = 0; i < a.length; i++) {
      res |= a[i] ^ b[i];
    }
    return res == 0;
  }
}

class ConversationStore extends ChangeNotifier {
  ConversationStore._();

  static final instance = ConversationStore._();

  static const String _keyStorageAlias = 'finn_ai_conversation_master_key_v1';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final List<FinnConversation> _conversations = [];
  String? _activeId;
  Timer? _saveDebounce;
  bool _initialized = false;
  Uint8List? _masterKey;

  List<FinnConversation> get conversations => List.unmodifiable(_conversations);
  FinnConversation? get active => _activeId == null
      ? null
      : _conversations.where((item) => item.id == _activeId).firstOrNull;

  Future<Uint8List> _getOrCreateMasterKey() async {
    if (_masterKey != null) return _masterKey!;
    try {
      final storedKeyBase64 = await _secureStorage.read(key: _keyStorageAlias);
      if (storedKeyBase64 != null && storedKeyBase64.isNotEmpty) {
        final decoded = base64Decode(storedKeyBase64);
        if (decoded.length >= 64) {
          _masterKey = decoded;
          return _masterKey!;
        }
      }

      final random = Random.secure();
      final newKey = Uint8List(64);
      for (var i = 0; i < 64; i++) {
        newKey[i] = random.nextInt(256);
      }
      await _secureStorage.write(
        key: _keyStorageAlias,
        value: base64Encode(newKey),
      );
      _masterKey = newKey;
      return _masterKey!;
    } catch (e) {
      debugPrint('Secure storage error, using session memory key: $e');
      if (_masterKey == null) {
        final random = Random.secure();
        final newKey = Uint8List(64);
        for (var i = 0; i < 64; i++) {
          newKey[i] = random.nextInt(256);
        }
        _masterKey = newKey;
      }
      return _masterKey!;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (_conversations.isNotEmpty) {
      _initialized = true;
      return;
    }

    try {
      final key = await _getOrCreateMasterKey();
      final encFile = await _file(encrypted: true);
      final legacyFile = await _file(encrypted: false);

      // Check legacy migration first
      if (!await encFile.exists() && await legacyFile.exists()) {
        await _migrateLegacyPlaintext(legacyFile, encFile, key);
      }

      if (await encFile.exists()) {
        final rawEnvelopeStr = await encFile.readAsString();
        final envelope = (jsonDecode(rawEnvelopeStr) as Map<Object?, Object?>).cast<String, Object?>();
        final decryptedJsonStr = ConversationCipher.decrypt(key, envelope);
        final data = (jsonDecode(decryptedJsonStr) as Map<Object?, Object?>).cast<String, Object?>();

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
      }
    } catch (e) {
      debugPrint('ConversationStore initialize error: $e');
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _migrateLegacyPlaintext(File legacyFile, File encFile, Uint8List key) async {
    try {
      final plaintextStr = await legacyFile.readAsString();
      jsonDecode(plaintextStr); // Validate JSON format

      // Encrypt legacy data
      final envelope = ConversationCipher.encrypt(key, plaintextStr);
      final tempFile = File('${encFile.path}.tmp');
      await tempFile.writeAsString(jsonEncode(envelope), flush: true);
      await tempFile.rename(encFile.path);

      // Verify readback
      final checkStr = await encFile.readAsString();
      final checkEnvelope = (jsonDecode(checkStr) as Map<Object?, Object?>).cast<String, Object?>();
      final verifiedDecrypted = ConversationCipher.decrypt(key, checkEnvelope);
      if (verifiedDecrypted == plaintextStr) {
        // Safe to remove legacy file
        await legacyFile.delete();
        debugPrint('Legacy plaintext conversation migration succeeded.');
      }
    } catch (e) {
      debugPrint('Legacy migration failed without data loss: $e');
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

  ConversationMessage add(ConversationRole role, String text) {
    final conversation = active ?? startNew();
    final now = DateTime.now();
    final message = ConversationMessage(
      id: now.microsecondsSinceEpoch.toString(),
      role: role,
      text: text,
      createdAt: now,
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

  ConversationMessage beginExchange(String userText) {
    final conversation = active ?? startNew();
    final now = DateTime.now();
    final user = ConversationMessage(
      id: now.microsecondsSinceEpoch.toString(),
      role: ConversationRole.user,
      text: userText,
      createdAt: now,
    );
    final assistant = ConversationMessage(
      id: (now.microsecondsSinceEpoch + 1).toString(),
      role: ConversationRole.assistant,
      text: '',
      createdAt: now,
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

  /// Destroys all stored local conversation data and encryption keys.
  Future<void> deleteStorageFiles() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _conversations.clear();
    _activeId = null;
    try {
      final encFile = await _file(encrypted: true);
      if (await encFile.exists()) await encFile.delete();

      final legacyFile = await _file(encrypted: false);
      if (await legacyFile.exists()) await legacyFile.delete();

      await _secureStorage.delete(key: _keyStorageAlias);
      _masterKey = null;
    } catch (e) {
      debugPrint('Error deleting conversation storage files: $e');
    }
    notifyListeners();
  }

  Future<void> flush() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    try {
      final key = await _getOrCreateMasterKey();
      final file = await _file(encrypted: true);
      final temp = File('${file.path}.tmp');
      final payload = <String, Object?>{
        'activeId': _activeId,
        'conversations': _conversations.map((item) => item.toJson()).toList(),
      };
      final plaintextStr = jsonEncode(payload);
      final envelope = ConversationCipher.encrypt(key, plaintextStr);

      await temp.writeAsString(jsonEncode(envelope), flush: true);
      await temp.rename(file.path);
    } catch (e) {
      debugPrint('Flush error: $e');
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
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 420), flush);
  }

  Future<File> _file({bool encrypted = true}) async {
    final root = await getApplicationSupportDirectory();
    final name = encrypted ? 'conversations.json.enc' : 'conversations.json';
    return File('${root.path}${Platform.pathSeparator}$name');
  }

  static String _title(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length <= 42 ? compact : '${compact.substring(0, 39)}…';
  }
}
