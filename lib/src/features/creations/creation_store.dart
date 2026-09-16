import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/creations/creation_model.dart';

typedef CreationDirectoryProvider = Future<Directory> Function();

/// Converts a version-1 creation record into the version-2 shape.
///
/// Version 1 stored only `{title, summary, sections[]}` — a description, not
/// anything runnable. Upgrading wraps those sections in a
/// [LegacyDocumentArtifact] so the records keep rendering instead of being
/// quarantined, and carries the original `kind` across so the creations stay in
/// the filter category the user last saw them in.
Map<String, Object?> migrateCreationRecordV1(Map<String, Object?> record) {
  final sections = record['sections'];
  return {
    'id': record['id'],
    'prompt': record['prompt'],
    'title': record['title'],
    'summary': record['summary'],
    'createdAt': record['createdAt'],
    'artifact': {
      'type': 'document',
      'kind': record['kind'],
      'summary': record['summary'],
      'sections': sections is List ? sections : const <Object?>[],
    },
  };
}

class CreationStore {
  CreationStore({CreationDirectoryProvider? directoryProvider})
      : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  static final instance = CreationStore();

  /// Current on-disk schema version.
  static const int currentVersion = 2;

  final CreationDirectoryProvider _directoryProvider;

  Future<Directory> _directory({required bool create}) async {
    final root = await _directoryProvider();
    final directory = Directory('${root.path}/creations');
    if (create && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _file() async =>
      File('${(await _directory(create: true)).path}/creations.json');

  /// Directory holding exported files such as `.pptx` decks.
  Future<Directory> exportsDirectory() async {
    final directory = await _directory(create: true);
    final exports = Directory('${directory.path}/exports');
    if (!await exports.exists()) {
      await exports.create(recursive: true);
    }
    return exports;
  }

  /// Removes every persisted creation and export, returning whether storage
  /// existed.
  ///
  /// Errors deliberately propagate so a caller performing a full local-data
  /// purge can report a partial deletion instead of claiming success.
  Future<bool> deleteStorage() async {
    final directory = await _directory(create: false);
    if (!await directory.exists()) return false;
    await directory.delete(recursive: true);
    return true;
  }

  Future<List<FinnCreation>> load() async {
    final file = await _file();
    if (!await file.exists()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return await _quarantine(file, 'Invalid creations storage.');
      }
      final version = decoded['version'];
      if (version is! int || version < 1 || version > currentVersion) {
        return await _quarantine(file, 'Unsupported creations storage format.');
      }
      final records = decoded['creations'];
      if (records is! List) {
        return await _quarantine(file, 'Invalid creations storage.');
      }
      final creations = <FinnCreation>[];
      for (final record in records.whereType<Map<dynamic, dynamic>>()) {
        try {
          final stored = Map<String, Object?>.from(record);
          final migrated =
              version == 1 ? migrateCreationRecordV1(stored) : stored;
          creations.add(FinnCreation.fromJson(migrated));
        } on Object {
          // One damaged entry should not make healthy creations disappear.
        }
      }
      creations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return creations;
    } on FormatException catch (error) {
      return _quarantine(file, 'Creations storage is damaged: $error');
    }
  }

  Future<Never> _quarantine(File file, String message) async {
    final damaged = File(
      '${file.path}.damaged-${DateTime.now().millisecondsSinceEpoch}',
    );
    try {
      if (await file.exists()) await file.rename(damaged.path);
    } on Object {
      // Leaving the source untouched is safer than risking data loss.
    }
    throw FormatException(message);
  }

  Future<void> save(List<FinnCreation> creations) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    final payload = jsonEncode({
      'version': currentVersion,
      'creations': creations.map((creation) => creation.toJson()).toList(),
    });
    await temporary.writeAsString(payload, flush: true);
    await temporary.rename(file.path);
  }
}
