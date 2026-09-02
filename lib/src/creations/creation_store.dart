import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'creation_model.dart';

typedef CreationDirectoryProvider = Future<Directory> Function();

class CreationStore {
  CreationStore({CreationDirectoryProvider? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  static final instance = CreationStore();

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

  /// Removes every persisted creation and returns whether storage existed.
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
      if (decoded is! Map || decoded['version'] != 1) {
        return await _quarantine(file, 'Unsupported creations storage format.');
      }
      final records = decoded['creations'];
      if (records is! List) {
        return await _quarantine(file, 'Invalid creations storage.');
      }
      final creations = <FinnCreation>[];
      for (final record in records.whereType<Map<dynamic, dynamic>>()) {
        try {
          creations.add(
            FinnCreation.fromJson(Map<String, Object?>.from(record)),
          );
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
      'version': 1,
      'creations': creations.map((creation) => creation.toJson()).toList(),
    });
    await temporary.writeAsString(payload, flush: true);
    await temporary.rename(file.path);
  }
}
