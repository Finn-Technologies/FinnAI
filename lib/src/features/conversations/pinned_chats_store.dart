import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Which chats the user pinned to the top of the sidebar.
///
/// Kept apart from the encrypted conversation file: a pin is a display
/// preference, not chat content, and holds only opaque ids.
class PinnedChatsStore extends ChangeNotifier {
  PinnedChatsStore({this.directoryProvider});

  static final instance = PinnedChatsStore();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;

  final Set<String> _ids = {};
  bool _initialized = false;

  bool isPinned(String id) => _ids.contains(id);

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) _ids.addAll(decoded.map((e) => e.toString()));
      }
    } catch (_) {
      // Unreadable pins just start empty.
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setPinned(String id, bool pinned) async {
    final changed = pinned ? _ids.add(id) : _ids.remove(id);
    if (!changed) return;
    notifyListeners();
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(_ids.toList()), flush: true);
    } catch (_) {}
  }

  /// [chats] with the pinned ones first, each group keeping its own order.
  List<T> sorted<T>(List<T> chats, String Function(T) idOf) => [
        ...chats.where((chat) => _ids.contains(idOf(chat))),
        ...chats.where((chat) => !_ids.contains(idOf(chat))),
      ];

  Future<List<String>> deleteStorage() async {
    _ids.clear();
    notifyListeners();
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (error) {
      return ['Pinned chats ($error)'];
    }
    return const [];
  }

  Future<File> _file() async {
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}pinned_chats.json');
  }
}
