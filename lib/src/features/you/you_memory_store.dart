import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The groups the design sorts what FinnAI remembers into.
enum YouCategory { people, work, routines, preferences, places, interests }

/// One thing FinnAI remembers about the user.
@immutable
class YouMemory {
  const YouMemory({
    required this.id,
    required this.text,
    required this.category,
    required this.createdAt,
    this.sources = const [],
    this.pending = false,
    this.useInChats = true,
  });

  final String id;
  final String text;
  final YouCategory category;
  final DateTime createdAt;

  /// Titles of the chats it was noticed in.
  final List<String> sources;

  /// Noticed by FinnAI but not yet kept by the user.
  final bool pending;
  final bool useInChats;

  YouMemory copyWith({
    String? text,
    YouCategory? category,
    List<String>? sources,
    bool? pending,
    bool? useInChats,
  }) =>
      YouMemory(
        id: id,
        text: text ?? this.text,
        category: category ?? this.category,
        createdAt: createdAt,
        sources: sources ?? this.sources,
        pending: pending ?? this.pending,
        useInChats: useInChats ?? this.useInChats,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'text': text,
        'category': category.name,
        'createdAt': createdAt.toIso8601String(),
        'sources': sources,
        'pending': pending,
        'useInChats': useInChats,
      };

  static YouMemory? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text']?.toString() ?? '';
    final id = raw['id']?.toString() ?? '';
    final category = YouCategory.values
        .where((value) => value.name == raw['category'])
        .firstOrNull;
    final created = DateTime.tryParse(raw['createdAt']?.toString() ?? '');
    if (text.isEmpty || id.isEmpty || category == null || created == null) {
      return null;
    }
    return YouMemory(
      id: id,
      text: text,
      category: category,
      createdAt: created,
      sources: [
        for (final source in (raw['sources'] as List? ?? const []))
          source.toString(),
      ],
      pending: raw['pending'] == true,
      useInChats: raw['useInChats'] != false,
    );
  }
}

/// What FinnAI has learned about the user, kept on this device.
///
/// Items come from the user (typed, or "Remember in You" on a reply) and from
/// [observe], which notices plain statements in the user's own messages and
/// queues them for review rather than trusting them.
class YouMemoryStore extends ChangeNotifier {
  YouMemoryStore({this.directoryProvider});

  static final instance = YouMemoryStore();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;

  static const int maxItems = 400;
  static const int promptItems = 6;

  final List<YouMemory> _items = [];
  bool _learn = true;
  bool _useInNewChats = true;
  final Set<String> _offChats = {};
  final Map<YouCategory, bool> _learnAbout = {
    for (final c in YouCategory.values) c: true,
  };
  bool _initialized = false;
  Future<void>? _initializeJob;

  /// The ids [promptContextFor] used for the latest turn.
  List<YouMemory> lastUsed = const [];

  bool get initialized => _initialized;
  bool get learn => _learn;
  bool get useInNewChats => _useInNewChats;
  bool usesYouIn(String? chatId) =>
      _useInNewChats && !_offChats.contains(chatId);

  Future<void> setUseInChat(String chatId, bool value) {
    value ? _offChats.remove(chatId) : _offChats.add(chatId);
    return _save();
  }

  bool learnsAbout(YouCategory category) => _learnAbout[category] ?? true;

  List<YouMemory> get kept =>
      List.unmodifiable(_items.where((item) => !item.pending));
  List<YouMemory> get pending =>
      List.unmodifiable(_items.where((item) => item.pending));
  int get keptCount => kept.length;

  List<YouMemory> inCategory(YouCategory category) => List.unmodifiable(
        _items.where((item) => !item.pending && item.category == category),
      );

  /// A readable summary of the most recent things, for the You header.
  String get summary =>
      (kept.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          .take(3)
          .map((item) => item.text.trim())
          .map((text) => text.endsWith('.') ? text : '$text.')
          .join(' ');

  DateTime? get updatedAt => kept.isEmpty
      ? null
      : kept.map((item) => item.createdAt).reduce(
            (a, b) => a.isAfter(b) ? a : b,
          );

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
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _learn = decoded['learn'] != false;
          _useInNewChats = decoded['use'] != false;
          _offChats.addAll(
            (decoded['offChats'] as List? ?? const []).map((e) => '$e'),
          );
          final about = decoded['learnAbout'];
          if (about is Map) {
            for (final c in YouCategory.values) {
              if (about[c.name] is bool) _learnAbout[c] = about[c.name] as bool;
            }
          }
          for (final raw in (decoded['items'] as List? ?? const [])) {
            final item = YouMemory.fromJson(raw);
            if (item != null) _items.add(item);
          }
        }
      }
    } catch (_) {
      // An unreadable file starts empty rather than blocking the app.
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_items.length}';

  Future<YouMemory?> add(
    String text,
    YouCategory category, {
    bool useInChats = true,
    List<String> sources = const [],
    bool pending = false,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty || _items.length >= maxItems) return null;
    final lower = clean.toLowerCase();
    if (_items.any((item) => item.text.toLowerCase() == lower)) return null;
    final item = YouMemory(
      id: _newId(),
      text: clean.length > 280 ? clean.substring(0, 280) : clean,
      category: category,
      createdAt: DateTime.now(),
      sources: sources,
      pending: pending,
      useInChats: useInChats,
    );
    _items.insert(0, item);
    await _save();
    return item;
  }

  Future<void> update(
    String id, {
    String? text,
    YouCategory? category,
    bool? useInChats,
    bool? pending,
  }) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(
      text: text?.trim().isEmpty ?? true ? null : text!.trim(),
      category: category,
      useInChats: useInChats,
      pending: pending,
    );
    await _save();
  }

  Future<void> forget(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _save();
  }

  Future<void> eraseAll() async {
    _items.clear();
    await _save();
  }

  Future<void> setLearn(bool value) {
    _learn = value;
    return _save();
  }

  Future<void> setUseInNewChats(bool value) {
    _useInNewChats = value;
    return _save();
  }

  Future<void> setLearnAbout(YouCategory category, bool value) {
    _learnAbout[category] = value;
    return _save();
  }

  /// The memories to give the model for [prompt], most relevant first, as a
  /// short system-prompt fragment. Empty when You is switched off or has
  /// nothing relevant. Records what it used in [lastUsed].
  String promptContextFor(String prompt, {String? chatId}) {
    lastUsed = const [];
    if (!usesYouIn(chatId)) return '';
    final usable = kept.where((item) => item.useInChats).toList();
    if (usable.isEmpty) return '';
    final words = _words(prompt);
    int score(YouMemory item) => _words(item.text).where(words.contains).length;
    usable.sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      return byScore != 0 ? byScore : b.createdAt.compareTo(a.createdAt);
    });
    final chosen = usable.take(promptItems).toList();
    lastUsed = chosen;
    return [
      'Things the user chose to share about themselves (private, local):',
      for (final item in chosen) '- ${item.text}',
      'Use them only when they help; never recite them back.',
    ].join('\n');
  }

  static Set<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((word) => word.length > 3)
      .toSet();

  static final _patterns = <(RegExp, YouCategory, String)>[
    (
      RegExp(r"\bI(?:'m| am) (?:a|an) ([^.,!?]{3,60})", caseSensitive: false),
      YouCategory.work,
      'You are a %s',
    ),
    (
      RegExp(r"\bI(?:'m| am) learning ([^.,!?]{3,40})", caseSensitive: false),
      YouCategory.interests,
      'You are learning %s',
    ),
    (
      RegExp(r'\bI work (?:as|at|in|for) ([^.,!?]{3,50})',
          caseSensitive: false),
      YouCategory.work,
      'You work as or at %s',
    ),
    (
      RegExp(r'\bI live in ([^.,!?]{2,40})', caseSensitive: false),
      YouCategory.places,
      'You live in %s',
    ),
    (
      RegExp(r'\bI (?:prefer|like|love) ([^.,!?]{3,60})', caseSensitive: false),
      YouCategory.preferences,
      'You like %s',
    ),
    (
      RegExp(r'\bmy (?:wife|husband|partner|friend|boss|sister|brother|'
          r'mom|dad|mother|father) ([A-Z][a-z]+)'),
      YouCategory.people,
      'Someone close to you is called %s',
    ),
  ];

  /// Notices plain statements in a message the user wrote and queues them for
  /// review. Does nothing while learning is off.
  Future<void> observe(String userText, String chatTitle) async {
    if (!_learn) return;
    var changed = false;
    for (final (pattern, category, template) in _patterns) {
      if (!learnsAbout(category)) continue;
      final match = pattern.firstMatch(userText);
      if (match == null) continue;
      final fact = template.replaceFirst('%s', match.group(1)!.trim());
      final lower = fact.toLowerCase();
      if (_items.any((item) => item.text.toLowerCase() == lower)) continue;
      if (_items.length >= maxItems) break;
      _items.insert(
        0,
        YouMemory(
          id: _newId(),
          text: fact,
          category: category,
          createdAt: DateTime.now(),
          sources: [chatTitle],
          pending: true,
        ),
      );
      changed = true;
    }
    if (changed) await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode({
          'version': 1,
          'learn': _learn,
          'use': _useInNewChats,
          'offChats': _offChats.toList(),
          'learnAbout': {
            for (final e in _learnAbout.entries) e.key.name: e.value
          },
          'items': [for (final item in _items) item.toJson()],
        }),
        flush: true,
      );
      await temporary.rename(file.path);
    } catch (_) {
      // The in-memory list stays correct for this run.
    }
  }

  /// Removes the stored file and resets to defaults.
  Future<List<String>> deleteStorage() async {
    final failures = <String>[];
    _items.clear();
    _offChats.clear();
    _learn = true;
    _useInNewChats = true;
    for (final c in YouCategory.values) {
      _learnAbout[c] = true;
    }
    try {
      final file = await _file();
      final temporary = File('${file.path}.tmp');
      if (await file.exists()) await file.delete();
      if (await temporary.exists()) await temporary.delete();
    } catch (error) {
      failures.add('What FinnAI remembers ($error)');
    }
    notifyListeners();
    return failures;
  }

  Future<File> _file() async {
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}you_memory.json');
  }
}
