part of '../finn_accelerator.dart';

Future<bool> _looksLikeGgufFile(File file) async {
  if (!await file.exists() || await file.length() < 4) return false;
  final handle = await file.open();
  try {
    final magic = await handle.read(4);
    return magic.length == 4 &&
        magic[0] == 0x47 &&
        magic[1] == 0x47 &&
        magic[2] == 0x55 &&
        magic[3] == 0x46;
  } finally {
    await handle.close();
  }
}

/// Promotes a complete resumable download without making another network
/// request.
///
/// A process can be killed after the final byte is flushed but before the
/// `.part` file is renamed. Treating that state as another range request
/// causes some CDNs to return an unsatisfiable range response. The exact byte
/// count enforced by the transfer is the integrity gate here, and callers
/// verify the GGUF magic right after promotion. Full-file SHA-256 is
/// deliberately skipped because it made the post-download "Verifying" step
/// take tens of seconds on budget devices.
@visibleForTesting
Future<bool> promoteVerifiedModelPartial({
  required File partial,
  required File target,
  required int expectedBytes,
}) async {
  if (!await partial.exists() || await partial.length() != expectedBytes) {
    return false;
  }
  if (await target.exists()) await target.delete();
  await partial.rename(target.path);
  if (!await _looksLikeGgufFile(target)) {
    await target.delete();
    return false;
  }
  return true;
}

/// Deletes an installed model file and everything that belongs to it:
/// the `.part` of an interrupted download, its range side-files, and the
/// `.finn_repack` repacked-weight cache the vendored native build writes next
/// to the model.
///
/// The repack cache is the reason this exists. It is worth ~693MB for the 1.6B
/// and was never deleted, so "Delete All Local Data" and model removal left a
/// third of a gigabyte behind — found on the device, not in the code.
///
/// Returns the paths that were removed. A missing file is not a failure, and a
/// file that refuses to delete is logged and skipped rather than aborting the
/// rest of the cleanup.
@visibleForTesting
Future<List<String>> removeModelArtifactFiles(File file) async {
  final removed = <String>[];
  for (final suffix in FinnAccelerator.modelFileSuffixes) {
    final candidate = File('${file.path}$suffix');
    if (!await candidate.exists()) continue;
    try {
      await candidate.delete();
      removed.add(candidate.path);
    } on FileSystemException catch (error) {
      debugPrint('Model artifact removal failed for ${candidate.path}: $error');
    }
  }
  try {
    await deleteRangeFiles(File('${file.path}.part'));
  } on FileSystemException catch (error) {
    debugPrint('Model range-file removal failed for ${file.path}: $error');
  }
  return removed;
}

/// Deletes the `<partial>.r0` … scratch files a segmented download leaves.
///
/// So interrupted downloads leave nothing behind on model removal or
/// "delete all local data". Top-level so [removeModelArtifactFiles] and the
/// accelerator share one implementation of the segment count.
Future<void> deleteRangeFiles(File partial) async {
  final segments = FinnAccelerator.dartDownloadSegments;
  for (var i = 0; i < segments; i++) {
    try {
      final rangeFile = File('${partial.path}.r$i');
      if (await rangeFile.exists()) await rangeFile.delete();
    } catch (_) {}
  }
}
