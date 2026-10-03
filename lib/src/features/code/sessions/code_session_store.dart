import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/code/sandbox/workspace.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';

/// The coding sessions, saved on the device, and the folder each one works in.
///
/// Sessions are plain JSON in the app's private storage. They are not in the
/// encrypted conversation file: that store belongs to FinnAI's chat, and a
/// coding session's real content is its project folder, which is plain files
/// by nature. `docs/decisions/0010-finnai-code.md` records the trade-off.
class CodeSessionStore extends ChangeNotifier {
  CodeSessionStore({
    this.directoryProvider,
    DateTime Function()? clock,
    String Function()? idGenerator,
    this.saveDelay = const Duration(milliseconds: 400),
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? _randomId;

  static final instance = CodeSessionStore();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;
  final DateTime Function() _clock;
  final String Function() _newId;
  final Duration saveDelay;

  static const int maxSessions = 60;
  static const int maxMessages = 400;

  final List<CodeSession> _sessions = [];
  String? _activeId;
  bool _initialized = false;
  Timer? _saveTimer;
  Future<void> _writing = Future<void>.value();
  Directory? _supportDirectory;

  bool get initialized => _initialized;

  /// Pinned first, then newest.
  List<CodeSession> get sessions {
    final sorted = <CodeSession>[..._sessions]..sort(CodeSession.byRecency);
    return List.unmodifiable(sorted);
  }

  String? get activeId => _activeId;

  CodeSession? get active => byId(_activeId);

  /// The open session, or the most recent one when none is open (just after
  /// a restart). Files and Terminal use this so they have a folder to show.
  CodeSession? get activeOrLatest => active ?? sessions.firstOrNull;

  CodeSession? byId(String? id) {
    if (id == null) return null;
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  static String _randomId() {
    final random = math.Random.secure();
    final tail = List.generate(4, (_) => random.nextInt(36).toRadixString(36));
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${tail.join()}';
  }

  /// A session's name before the user renames it: the first line of what they
  /// asked, cut at a word.
  static String titleFrom(String text) {
    final line = text.trim().split('\n').first.trim();
    if (line.length <= 40) return line;
    final cut = line.substring(0, 40);
    final space = cut.lastIndexOf(' ');
    return '${space > 20 ? cut.substring(0, space) : cut}…';
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        final list = decoded is Map ? decoded['sessions'] : null;
        if (list is List) {
          for (final raw in list) {
            if (CodeSession.fromJson(raw) case final session?) {
              _sessions.add(session);
            }
          }
        }
      }
    } catch (_) {
      // An unreadable file starts empty rather than blocking the screen.
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ changes

  /// Starts a session and makes it the active one.
  CodeSession create({String title = ''}) {
    final now = _clock();
    final session = CodeSession(
      id: _newId(),
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    _sessions.add(session);
    _activeId = session.id;
    _trim();
    _changed();
    return session;
  }

  void activate(String id) {
    if (byId(id) == null || _activeId == id) return;
    _activeId = id;
    notifyListeners();
  }

  /// Shows the blank screen. No session exists until the first message.
  void clearActive() {
    if (_activeId == null) return;
    _activeId = null;
    notifyListeners();
  }

  void appendMessage(String sessionId, CodeMessage message) =>
      _update(sessionId, (session) {
        var messages = [...session.messages, message];
        if (messages.length > maxMessages) {
          messages = messages.sublist(messages.length - maxMessages);
        }
        return session.copyWith(
          messages: messages,
          updatedAt: _clock(),
          title: session.title.isEmpty && message.isUser
              ? titleFrom(message.text)
              : session.title,
        );
      });

  /// Replaces the message with the same id.
  void replaceMessage(String sessionId, CodeMessage message) =>
      _update(sessionId, (session) {
        final index = session.messages.indexWhere((m) => m.id == message.id);
        if (index < 0) return session;
        final messages = [...session.messages]..[index] = message;
        return session.copyWith(messages: messages, updatedAt: _clock());
      });

  /// Removes the message with [messageId].
  void removeMessage(String sessionId, String messageId) =>
      _update(sessionId, (session) {
        final messages = [
          for (final m in session.messages)
            if (m.id != messageId) m,
        ];
        return messages.length == session.messages.length
            ? session
            : session.copyWith(messages: messages);
      });

  void rename(String id, String title) => _update(id, (session) {
        final trimmed = title.trim();
        return trimmed.isEmpty ? session : session.copyWith(title: trimmed);
      });

  void setPinned(String id, bool pinned) =>
      _update(id, (session) => session.copyWith(pinned: pinned));

  void _update(String id, CodeSession Function(CodeSession) change) {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index < 0) return;
    final next = change(_sessions[index]);
    if (identical(next, _sessions[index])) return;
    _sessions[index] = next;
    _changed();
  }

  /// Removes a session and everything it made.
  Future<void> delete(String id) async {
    final removed = byId(id);
    if (removed == null) return;
    _sessions.removeWhere((s) => s.id == id);
    if (_activeId == id) _activeId = null;
    _changed();
    try {
      await (await workspaceOf(id)).deleteAll();
    } catch (_) {
      // The session is gone either way; a leftover folder is reclaimed with
      // "delete all data".
    }
  }

  void _trim() {
    while (_sessions.length > maxSessions) {
      final oldest = ([..._sessions]..sort(CodeSession.byRecency))
          .reversed
          .firstWhere((s) => s.id != _activeId, orElse: () => _sessions.first);
      unawaited(delete(oldest.id));
      _sessions.removeWhere((s) => s.id == oldest.id);
    }
  }

  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(flush()));
  }

  // -------------------------------------------------------- persistence

  /// Writes pending changes now. Safe to call often.
  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final snapshot = jsonEncode({
      'version': 1,
      'sessions': [for (final session in _sessions) session.toJson()],
    });
    // Writes are chained so two flushes never interleave on the same file.
    return _writing = _writing.then((_) async {
      try {
        final file = await _file();
        await file.parent.create(recursive: true);
        final temp = File('${file.path}.tmp');
        await temp.writeAsString(snapshot, flush: true);
        await temp.rename(file.path);
      } catch (_) {
        // The sessions are still in memory for this run.
      }
    });
  }

  Future<Directory> _support() async =>
      _supportDirectory ??= directoryProvider != null
          ? await directoryProvider!()
          : await getApplicationSupportDirectory();

  Future<File> _file() async =>
      File('${(await _support()).path}/code/sessions.json');

  /// The project folder for [sessionId].
  Future<CodeWorkspace> workspaceOf(String sessionId) async => CodeWorkspace(
        Directory('${(await _support()).path}/code/workspaces/$sessionId'),
      );

  /// Removes every session and project folder. Returns what could not be
  /// removed, for the delete-all report.
  Future<List<String>> deleteStorage() async {
    _saveTimer?.cancel();
    await _writing;
    _sessions.clear();
    _activeId = null;
    notifyListeners();
    final failures = <String>[];
    try {
      final root = Directory('${(await _support()).path}/code');
      if (await root.exists()) await root.delete(recursive: true);
    } catch (error) {
      failures.add('FinnAI Code sessions ($error)');
    }
    return failures;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
