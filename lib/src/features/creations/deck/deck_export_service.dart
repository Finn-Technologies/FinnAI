import 'dart:io';

import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/features/creations/deck/pptx_writer.dart';
import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';

/// Writes a generated deck to a `.pptx` file on the device.
class DeckExportService {
  DeckExportService({CreationStore? store})
      : _store = store ?? CreationStore.instance;

  final CreationStore _store;

  /// Exports [deck] and returns the file that was written.
  ///
  /// Exports land in a dedicated `exports` folder beside the creations store,
  /// which is also what the "delete all data" purge removes.
  Future<File> export(
    DeckSpec deck, {
    required String title,
    DateTime? now,
  }) async {
    final directory = await _store.exportsDirectory();
    final file = await _uniqueFile(directory, PptxWriter.slugify(title));
    await file.writeAsBytes(PptxWriter.build(deck, now: now), flush: true);
    return file;
  }

  Future<File> _uniqueFile(Directory directory, String slug) async {
    var candidate = File('${directory.path}/$slug.pptx');
    var suffix = 2;
    while (await candidate.exists()) {
      candidate = File('${directory.path}/$slug-$suffix.pptx');
      suffix++;
    }
    return candidate;
  }
}
