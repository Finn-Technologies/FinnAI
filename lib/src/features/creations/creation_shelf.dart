import 'dart:async';

import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_store.dart';

/// Finds a saved creation by id for something that only remembers the id (a
/// card in a chat).
///
/// Reads the creations file once and again only after a save, however many
/// cards ask, because a long chat can hold dozens of them.
class CreationShelf {
  CreationShelf({CreationStore? store})
      : _store = store ?? CreationStore.instance;

  static final instance = CreationShelf();

  final CreationStore _store;
  Future<List<FinnCreation>>? _loading;
  int _loadedAt = -1;

  Future<List<FinnCreation>> _all() {
    final current = CreationStore.revision.value;
    if (_loading == null || _loadedAt != current) {
      _loadedAt = current;
      _loading = _store.load().catchError((Object _) => const <FinnCreation>[]);
    }
    return _loading!;
  }

  /// The creation with [id], or null when it was deleted.
  Future<FinnCreation?> find(String id) async {
    for (final creation in await _all()) {
      if (creation.id == id) return creation;
    }
    return null;
  }
}
