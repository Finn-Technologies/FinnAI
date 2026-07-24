import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

class ConversationStore extends ChangeNotifier {
  ConversationStore._();

  static final instance = ConversationStore._();

  final List<FinnConversation> _conversations = [];
  String? _activeId;
  Timer? _saveDebounce;
  bool _initialized = false;

  List<FinnConversation> get conversations => List.unmodifiable(_conversations);
  FinnConversation? get active => _activeId == null
      ? null
      : _conversations.where((item) => item.id == _activeId).firstOrNull;

  Future<void> initialize() async {
    if (_initialized) return;
    if (_conversations.isNotEmpty) {
      _initialized = true;
      return;
    }
    try {
      final file = await _file();
      if (!await file.exists()) {
        _initialized = true;
        notifyListeners();
        return;
      }
      final data = await compute(_decodeStore, await file.readAsString());
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
    } catch (_) {
      // Preserve in-memory conversations if storage initialization fails
    }
    _initialized = true;
    notifyListeners();
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

  /// Appends a user prompt and its pending reply with one notification/save.
  /// This avoids rebuilding the full chat twice at the start of every turn.
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

  Future<void> flush() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    try {
      final file = await _file();
      final temp = File('${file.path}.tmp');
      final payload = <String, Object?>{
        'activeId': _activeId,
        'conversations': _conversations.map((item) => item.toJson()).toList(),
      };
      final encoded = await compute(_encodeStore, payload);
      await temp.writeAsString(encoded, flush: true);
      await temp.rename(file.path);
    } catch (_) {
      // A conversation remains live in memory if storage is unavailable.
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

  Future<File> _file() async {
    final root = await getApplicationSupportDirectory();
    return File('${root.path}${Platform.pathSeparator}conversations.json');
  }

  static String _title(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length <= 42 ? compact : '${compact.substring(0, 39)}…';
  }
}

Map<String, Object?> _decodeStore(String source) =>
    (jsonDecode(source) as Map<Object?, Object?>).cast<String, Object?>();

String _encodeStore(Map<String, Object?> data) => jsonEncode(data);
