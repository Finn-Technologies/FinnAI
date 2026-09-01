import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../search/web_search_service.dart';

enum ConversationRole { user, assistant }

enum ConversationMessageStatus {
  complete,
  generating,
  stopped,
  interrupted,
  tokenLimited,
  failed,
}

@immutable
class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.imagePath,
    this.modelTier = 'FinnAI',
    this.status = ConversationMessageStatus.complete,
    this.generationId,
    this.finishReason,
    this.continuationCount = 0,
    this.sources = const [],
  });

  final String id;
  final ConversationRole role;
  final String text;
  final DateTime createdAt;
  final String? imagePath;
  final String modelTier;
  final ConversationMessageStatus status;
  final String? generationId;
  final String? finishReason;
  final int continuationCount;
  final List<WebSource> sources;

  ConversationMessage copyWith({
    String? text,
    String? imagePath,
    bool clearImagePath = false,
    String? modelTier,
    ConversationMessageStatus? status,
    String? generationId,
    String? finishReason,
    bool clearFinishReason = false,
    int? continuationCount,
    List<WebSource>? sources,
    bool clearSources = false,
  }) => ConversationMessage(
    id: id,
    role: role,
    text: text ?? this.text,
    createdAt: createdAt,
    imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
    modelTier: modelTier ?? this.modelTier,
    status: status ?? this.status,
    generationId: generationId ?? this.generationId,
    finishReason: clearFinishReason ? null : finishReason ?? this.finishReason,
    continuationCount: continuationCount ?? this.continuationCount,
    sources: clearSources ? const [] : sources ?? this.sources,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    if (imagePath != null) 'imagePath': imagePath,
    'modelTier': modelTier,
    'status': status.name,
    if (generationId != null) 'generationId': generationId,
    if (finishReason != null) 'finishReason': finishReason,
    'continuationCount': continuationCount,
    if (sources.isNotEmpty)
      'sources': [
        for (final source in sources)
          {
            'title': source.title,
            'url': source.url.toString(),
            'snippet': source.snippet,
          },
      ],
  };

  factory ConversationMessage.fromJson(Map<String, Object?> json) =>
      ConversationMessage(
        id: json['id'] as String,
        role: ConversationRole.values.byName(json['role'] as String),
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        imagePath: json['imagePath'] as String?,
        modelTier: (json['modelTier'] as String?) ?? 'FinnAI',
        status: ConversationMessageStatus.values.byName(
          (json['status'] as String?) ??
              ConversationMessageStatus.complete.name,
        ),
        generationId: json['generationId'] as String?,
        finishReason: json['finishReason'] as String?,
        continuationCount: (json['continuationCount'] as int?) ?? 0,
        sources: _sourcesFromJson(json['sources']),
      );
}

List<WebSource> _sourcesFromJson(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map &&
          item['title'] is String &&
          item['url'] is String &&
          item['snippet'] is String)
        if (Uri.tryParse(item['url'] as String) case final uri?
            when uri.scheme == 'https' && uri.host.isNotEmpty)
          WebSource(
            title: item['title'] as String,
            url: uri,
            snippet: item['snippet'] as String,
          ),
  ];
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
  Future<void>? _initializeJob;
  Future<void> _flushQueue = Future<void>.value();
  bool _deleting = false;
  Uint8List? _masterKey;
  bool _storageError = false;
  String? _storageErrorMessage;

  List<FinnConversation> get conversations => List.unmodifiable(_conversations);
  FinnConversation? get active => _activeId == null
      ? null
      : _conversations.where((item) => item.id == _activeId).firstOrNull;
  FinnConversation? conversationById(String id) =>
      _conversations.where((item) => item.id == id).firstOrNull;

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
    final running = _initializeJob;
    if (running != null) return running;
    final job = _initialize();
    _initializeJob = job;
    try {
      await job;
    } finally {
      if (identical(_initializeJob, job)) _initializeJob = null;
    }
  }

  Future<void> _initialize() async {
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
    if (!_storageError && _reconcileInterruptedGenerations()) {
      await flush();
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
      // Step 1: Parse and fully validate every field of the legacy schema BEFORE
      // touching the encrypted file or deleting the plaintext. If any field is
      // malformed, a FormatException/TypeError is thrown here and the plaintext
      // is preserved.
      final parsedData = (jsonDecode(plaintextStr) as Map<Object?, Object?>)
          .cast<String, Object?>();

      // Validate activeId type (null or String)
      final rawActiveId = parsedData['activeId'];
      if (rawActiveId != null && rawActiveId is! String) {
        throw FormatException(
          'Legacy schema: activeId must be String or null, got ${rawActiveId.runtimeType}',
        );
      }
      final validatedActiveId = rawActiveId as String?;

      // Validate every conversation and every message completely.
      final rawConversations = parsedData['conversations'];
      if (rawConversations is! List<Object?>) {
        throw FormatException(
          'Legacy schema: conversations must be a List, got ${rawConversations.runtimeType}',
        );
      }
      final validatedConversations = <FinnConversation>[];
      for (final item in rawConversations) {
        if (item is! Map<Object?, Object?>) {
          throw FormatException(
            'Legacy schema: conversation item must be a Map, got ${item.runtimeType}',
          );
        }
        // FinnConversation.fromJson performs full field validation; any missing
        // or wrongly-typed field will throw before we write any encrypted data.
        validatedConversations.add(
          FinnConversation.fromJson(item.cast<String, Object?>()),
        );
      }

      // Step 2: Write encrypted data to temporary file
      final envelope = await ConversationCipher.encrypt(key, plaintextStr);
      await tempFile.writeAsString(jsonEncode(envelope), flush: true);

      // Step 3: Read and decrypt temporary file while it is still temporary
      final tmpStr = await tempFile.readAsString();
      final tmpEnv = (jsonDecode(tmpStr) as Map<Object?, Object?>)
          .cast<String, Object?>();
      final tmpDecrypted = await ConversationCipher.decrypt(key, tmpEnv);

      // Step 4: Verify decrypted content equals source plaintext
      if (tmpDecrypted != plaintextStr) {
        throw StateError('Temporary file decryption verification failed.');
      }

      // Step 5: Atomically rename to final path
      await tempFile.rename(encFile.path);

      // Step 6: Read final file and confirm it decrypts correctly before deleting plaintext
      final finalStr = await encFile.readAsString();
      final finalEnv = (jsonDecode(finalStr) as Map<Object?, Object?>)
          .cast<String, Object?>();
      final finalDecrypted = await ConversationCipher.decrypt(key, finalEnv);

      if (finalDecrypted != plaintextStr) {
        throw StateError('Final file decryption verification failed.');
      }

      // Step 7: All validation and verification passed — safe to delete plaintext
      await legacyFile.delete();

      // Immediately load the pre-validated model objects so they are visible and
      // cannot be overwritten by a new conversation on the same launch.
      _masterKey = key;
      _activeId = validatedActiveId;
      _conversations
        ..clear()
        ..addAll(validatedConversations);
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

  /// Switches to the blank compose slate without creating a conversation.
  /// A conversation is only created once the user actually sends a message
  /// (the send path uses `active ?? startNew()`).
  void clearActive() {
    if (_activeId == null) return;
    _activeId = null;
    _changed();
  }

  ConversationMessage add(
    ConversationRole role,
    String text, {
    String? imagePath,
    String modelTier = 'FinnAI',
  }) {
    final conversation = active ?? startNew();
    final now = DateTime.now();
    final message = ConversationMessage(
      id: now.microsecondsSinceEpoch.toString(),
      role: role,
      text: text,
      createdAt: now,
      imagePath: imagePath,
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
    String? imagePath,
    String modelTier = 'FinnAI',
    String? generationId,
  }) {
    final conversation = active ?? startNew();
    return beginExchangeInConversation(
      conversation.id,
      userText,
      imagePath: imagePath,
      modelTier: modelTier,
      generationId: generationId,
    );
  }

  ConversationMessage beginExchangeInConversation(
    String conversationId,
    String userText, {
    String? imagePath,
    String modelTier = 'FinnAI',
    String? generationId,
  }) {
    final conversation = conversationById(conversationId);
    if (conversation == null) {
      throw StateError('Conversation $conversationId no longer exists.');
    }
    final now = DateTime.now();
    final user = ConversationMessage(
      id: now.microsecondsSinceEpoch.toString(),
      role: ConversationRole.user,
      text: userText,
      createdAt: now,
      imagePath: imagePath,
      modelTier: modelTier,
    );

    final assistant = ConversationMessage(
      id: (now.microsecondsSinceEpoch + 1).toString(),
      role: ConversationRole.assistant,
      text: '',
      createdAt: now,
      modelTier: modelTier,
      status: ConversationMessageStatus.generating,
      generationId: generationId,
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
    String? modelTier,
    bool persistSoon = false,
    bool notify = true,
  }) {
    final conversation = active;
    if (conversation == null) return;
    updateMessageInConversation(
      conversation.id,
      id,
      text,
      modelTier: modelTier,
      persistSoon: persistSoon,
      notify: notify,
    );
  }

  bool updateMessageInConversation(
    String conversationId,
    String messageId,
    String text, {
    String? expectedGenerationId,
    String? modelTier,
    ConversationMessageStatus? status,
    String? finishReason,
    int? continuationCount,
    List<WebSource>? sources,
    bool persistSoon = false,
    bool notify = true,
  }) {
    final conversation = conversationById(conversationId);
    if (conversation == null) return false;
    final index = conversation.messages.indexWhere(
      (item) => item.id == messageId,
    );
    if (index < 0) return false;
    final previous = conversation.messages[index];
    if (previous.role != ConversationRole.assistant ||
        (expectedGenerationId != null &&
            previous.generationId != expectedGenerationId)) {
      return false;
    }
    final messages = [...conversation.messages];
    messages[index] = previous.copyWith(
      text: text,
      modelTier: modelTier ?? previous.modelTier,
      status: status,
      finishReason: finishReason,
      continuationCount: continuationCount,
      sources: sources,
    );
    _replace(
      conversation.copyWith(updatedAt: DateTime.now(), messages: messages),
    );
    if (notify) notifyListeners();
    if (persistSoon) _scheduleSave();
    return true;
  }

  /// Replaces an existing assistant turn in place for a regenerate action.
  ConversationMessage? beginRegeneration({
    required String conversationId,
    required String messageId,
    required String generationId,
  }) {
    final conversation = conversationById(conversationId);
    if (conversation == null) return null;
    final index = conversation.messages.indexWhere(
      (message) =>
          message.id == messageId &&
          message.role == ConversationRole.assistant &&
          message.status != ConversationMessageStatus.generating,
    );
    if (index < 0) return null;
    final messages = [...conversation.messages];
    messages[index] = messages[index].copyWith(
      text: '',
      generationId: generationId,
      status: ConversationMessageStatus.generating,
      clearFinishReason: true,
      clearSources: true,
    );
    _replace(
      conversation.copyWith(updatedAt: DateTime.now(), messages: messages),
    );
    _changed();
    return messages[index];
  }

  /// Appends an assistant placeholder for an already-existing user turn.
  ConversationMessage? beginAssistantReply({
    required String conversationId,
    required String generationId,
    String modelTier = 'FinnAI',
  }) {
    final conversation = conversationById(conversationId);
    if (conversation == null || conversation.messages.isEmpty) return null;
    final now = DateTime.now();
    final assistant = ConversationMessage(
      id: '${now.microsecondsSinceEpoch}-assistant',
      role: ConversationRole.assistant,
      text: '',
      createdAt: now,
      modelTier: modelTier,
      status: ConversationMessageStatus.generating,
      generationId: generationId,
    );
    _replace(
      conversation.copyWith(
        updatedAt: now,
        messages: [...conversation.messages, assistant],
      ),
    );
    _changed();
    return assistant;
  }

  /// Edits a user turn and removes all later turns so the reply can be
  /// generated without duplicating the edited user message.
  bool editUserMessage({
    required String conversationId,
    required String messageId,
    required String newText,
  }) {
    final conversation = conversationById(conversationId);
    if (conversation == null) return false;
    final index = conversation.messages.indexWhere(
      (message) =>
          message.id == messageId && message.role == ConversationRole.user,
    );
    final value = newText.trim();
    if (index < 0 || value.isEmpty) return false;
    final edited = conversation.messages[index].copyWith(text: value);
    final messages = [...conversation.messages.take(index), edited];
    _replace(
      conversation.copyWith(
        title: index == 0 ? _title(value) : conversation.title,
        updatedAt: DateTime.now(),
        messages: messages,
      ),
    );
    _changed();
    return true;
  }

  ConversationMessage? beginContinuation({
    required String conversationId,
    required String messageId,
    required String generationId,
  }) {
    final conversation = conversationById(conversationId);
    if (conversation == null) return null;
    final index = conversation.messages.indexWhere(
      (message) =>
          message.id == messageId &&
          message.role == ConversationRole.assistant &&
          message.status == ConversationMessageStatus.tokenLimited &&
          message.continuationCount < 1,
    );
    if (index < 0) return null;
    final messages = [...conversation.messages];
    messages[index] = messages[index].copyWith(
      generationId: generationId,
      status: ConversationMessageStatus.generating,
      clearFinishReason: true,
      continuationCount: messages[index].continuationCount + 1,
    );
    _replace(
      conversation.copyWith(updatedAt: DateTime.now(), messages: messages),
    );
    _changed();
    return messages[index];
  }

  void removeMessage(String id) {
    final conversation = active;
    if (conversation == null) return;
    removeMessageInConversation(conversation.id, id);
  }

  bool removeMessageInConversation(
    String conversationId,
    String messageId, {
    String? expectedGenerationId,
  }) {
    final conversation = conversationById(conversationId);
    if (conversation == null) return false;
    final target = conversation.messages
        .where((message) => message.id == messageId)
        .firstOrNull;
    if (target == null ||
        (expectedGenerationId != null &&
            target.generationId != expectedGenerationId)) {
      return false;
    }
    final messages = conversation.messages
        .where((message) => message.id != messageId)
        .toList(growable: false);
    _replace(
      conversation.copyWith(updatedAt: DateTime.now(), messages: messages),
    );
    _changed();
    return true;
  }

  void renameConversation(String id, String newTitle) {
    final index = _conversations.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    _conversations[index] = _conversations[index].copyWith(title: trimmed);
    _changed();
  }

  bool deleteConversation(String id) {
    final conversation = conversationById(id);
    if (conversation == null ||
        conversation.messages.any(
          (message) => message.status == ConversationMessageStatus.generating,
        )) {
      return false;
    }
    _conversations.removeWhere((item) => item.id == id);
    if (_activeId == id) {
      _activeId = _conversations.firstOrNull?.id;
    }
    _changed();
    return true;
  }

  /// Clears all conversations and waits until the encrypted snapshot is
  /// durably rewritten before the caller reports success.
  Future<void> clearAllAndFlush() async {
    _conversations.clear();
    _activeId = null;
    notifyListeners();
    if (!_storageError) await flush();
  }

  /// Legacy synchronous entry point. New destructive UI flows should use
  /// [clearAllAndFlush] so a success message is not shown before persistence.
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
    _deleting = true;
    await _flushQueue;
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
    _deleting = false;
    notifyListeners();

    return failures;
  }

  Future<void> flush() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    if (_storageError || _deleting) {
      debugPrint('Flush aborted: ConversationStore is in storage error state.');
      return Future<void>.value();
    }
    final plaintext = jsonEncode(<String, Object?>{
      'activeId': _activeId,
      'conversations': _conversations.map((item) => item.toJson()).toList(),
    });
    _flushQueue = _flushQueue.then((_) => _writeEncrypted(plaintext));
    return _flushQueue;
  }

  Future<void> _writeEncrypted(String plaintext) async {
    if (_deleting) return;
    try {
      final key = await _getOrCreateMasterKey();
      if (key == null) {
        debugPrint('Flush aborted: Secure key unavailable.');
        return;
      }
      final file = await _file(filename: 'conversations.v2.enc');
      final temp = File('${file.path}.tmp');
      final envelope = await ConversationCipher.encrypt(key, plaintext);

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

  bool _reconcileInterruptedGenerations() {
    var changed = false;
    for (
      var conversationIndex = 0;
      conversationIndex < _conversations.length;
      conversationIndex++
    ) {
      final conversation = _conversations[conversationIndex];
      final messages = [
        for (final message in conversation.messages)
          if (message.status == ConversationMessageStatus.generating)
            message.copyWith(
              status: ConversationMessageStatus.interrupted,
              finishReason: 'interrupted',
            )
          else
            message,
      ];
      if (!listEquals(messages, conversation.messages)) {
        changed = true;
        _conversations[conversationIndex] = conversation.copyWith(
          updatedAt: DateTime.now(),
          messages: messages,
        );
      }
    }
    return changed;
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
