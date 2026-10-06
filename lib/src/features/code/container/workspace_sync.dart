import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:finn_ai/src/features/code/sandbox/workspace.dart';

/// The project folder is larger than the container will carry.
class WorkspaceTooLarge implements Exception {
  const WorkspaceTooLarge(this.bytes);

  final int bytes;
}

/// What a pull changed on the device.
class SyncReport {
  const SyncReport({this.written = 0, this.deleted = 0, this.skipped = 0});

  final int written;
  final int deleted;

  /// Links, special files and paths that would leave the folder: never
  /// brought back.
  final int skipped;
}

/// Moves a project folder into the container and back, as a tar.
///
/// The device's folder is the truth. Before a command it is packed and
/// unpacked over the container's copy; after, the container's copy is packed
/// and applied back: changed files written, vanished files deleted. Only
/// regular files and folders cross. A link made inside the container stays
/// there, so nothing in the guest can point the device at anything outside
/// the folder.
///
/// Permissions do not survive every device file system (iOS cannot set them),
/// so the modes the container last reported are kept beside the folder in
/// [modesFile] and reapplied on the next push. That is what keeps
/// `chmod +x run.sh` working from one command to the next.
class WorkspaceSync {
  WorkspaceSync(this.workspace, {this.maxBytes = 24 * 1024 * 1024});

  final CodeWorkspace workspace;
  final int maxBytes;

  static const String modesFile = 'container-modes.json';

  File get _modes =>
      File('${workspace.root.path}/${CodeWorkspace.scratchDir}/$modesFile');

  Future<Map<String, int>> _readModes() async {
    try {
      final decoded = jsonDecode(await _modes.readAsString());
      if (decoded is Map) {
        return {
          for (final entry in decoded.entries)
            if (entry.value is int) '${entry.key}': entry.value as int,
        };
      }
    } catch (_) {
      // No modes yet, or unreadable: plain files.
    }
    return {};
  }

  /// Packs the folder. Throws [WorkspaceTooLarge] past [maxBytes].
  Future<Uint8List> pack() async {
    await workspace.ensureCreated();
    final modes = await _readModes();
    final tar = UstarWriter();
    var total = 0;
    final base = workspace.root.path;
    await for (final entity
        in workspace.root.list(recursive: true, followLinks: false)) {
      final relative = entity.path.substring(base.length + 1);
      if (relative == CodeWorkspace.scratchDir ||
          relative.startsWith('${CodeWorkspace.scratchDir}/')) {
        continue;
      }
      if (entity is Directory) {
        tar.directory(relative);
      } else if (entity is File) {
        final bytes = await entity.readAsBytes();
        total += bytes.length;
        if (total > maxBytes) throw WorkspaceTooLarge(total);
        final stat = await entity.stat();
        final executable =
            (stat.mode & 0x49) != 0 || ((modes[relative] ?? 0) & 0x49) != 0;
        tar.file(
          relative,
          bytes,
          mode: executable ? 0x1ed : 0x1a4,
          modified: stat.modified,
        );
      }
    }
    return tar.finish();
  }

  /// Applies the container's copy back to the folder.
  Future<SyncReport> apply(List<int> tar) async {
    final archive = TarDecoder().decodeBytes(tar);
    final seenFiles = <String>{};
    final seenDirs = <String>{};
    final modes = <String, int>{};
    var written = 0;
    var skipped = 0;
    final pending = <String, Uint8List>{};
    var total = 0;
    for (final entry in archive) {
      final String relative;
      try {
        relative = CodeWorkspace.normalize(
            entry.name.startsWith('./') ? entry.name.substring(2) : entry.name);
      } on WorkspaceEscape {
        // `./` itself, or something that would climb out.
        if (entry.name != './' && entry.name != '.') skipped++;
        continue;
      }
      if (entry.isSymbolicLink) {
        skipped++;
        continue;
      }
      if (!entry.isFile) {
        seenDirs.add(relative);
        continue;
      }
      final bytes = entry.readBytes() ?? Uint8List(0);
      total += bytes.length;
      if (total > maxBytes) throw WorkspaceTooLarge(total);
      pending[relative] = bytes;
      seenFiles.add(relative);
      if ((entry.mode & 0x49) != 0) modes[relative] = entry.mode & 0x1ff;
    }

    final root = workspace.root.path;
    for (final dir in seenDirs) {
      final directory = Directory('$root/$dir');
      if (FileSystemEntity.typeSync(directory.path, followLinks: false) ==
          FileSystemEntityType.notFound) {
        await directory.create(recursive: true);
      }
    }
    for (final MapEntry(key: relative, value: bytes) in pending.entries) {
      final file = File('$root/$relative');
      final type = FileSystemEntity.typeSync(file.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        skipped++;
        continue;
      }
      if (type == FileSystemEntityType.file &&
          await file.length() == bytes.length &&
          _same(await file.readAsBytes(), bytes)) {
        continue;
      }
      if (type == FileSystemEntityType.directory) {
        await Directory(file.path).delete(recursive: true);
      }
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      written++;
    }

    // Whatever the container no longer has, the folder no longer has.
    var deleted = 0;
    final existing = <FileSystemEntity>[];
    await for (final entity
        in workspace.root.list(recursive: true, followLinks: false)) {
      existing.add(entity);
    }
    // Deepest first, so a folder is emptied before it is judged.
    existing.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final entity in existing) {
      final relative = entity.path.substring(root.length + 1);
      if (relative == CodeWorkspace.scratchDir ||
          relative.startsWith('${CodeWorkspace.scratchDir}/')) {
        continue;
      }
      final keep = entity is Directory
          ? seenDirs.contains(relative) ||
              seenFiles.any((file) => file.startsWith('$relative/'))
          : seenFiles.contains(relative);
      if (keep) continue;
      try {
        await entity.delete(recursive: true);
        deleted++;
      } on FileSystemException {
        skipped++;
      }
    }

    try {
      await _modes.parent.create(recursive: true);
      await _modes.writeAsString(jsonEncode(modes));
    } on FileSystemException {
      // Modes are a convenience; the files are what matter.
    }
    return SyncReport(written: written, deleted: deleted, skipped: skipped);
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Writes a POSIX ustar archive.
///
/// `package:archive` writes the older v7 header, which busybox `tar` refuses
/// ("invalid tar magic"); reading busybox's output with it is fine. Paths
/// longer than ustar can carry (100 characters, or 255 split at a slash) are
/// left out and counted in [skipped].
class UstarWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);
  int skipped = 0;

  void directory(String path, {int mode = 0x1ed}) =>
      _entry('$path/', Uint8List(0), mode: mode, type: 0x35);

  void file(String path, List<int> bytes,
          {int mode = 0x1a4, DateTime? modified}) =>
      _entry(path, bytes, mode: mode, type: 0x30, modified: modified);

  void _entry(
    String path,
    List<int> bytes, {
    required int mode,
    required int type,
    DateTime? modified,
  }) {
    final encoded = utf8.encode(path);
    var name = encoded;
    var prefix = <int>[];
    if (encoded.length > 100) {
      // Split at a slash so the name fits in 100 and the rest in 155.
      var split = -1;
      for (var i = encoded.length - 1; i > 0; i--) {
        if (encoded[i] == 0x2f &&
            encoded.length - i - 1 <= 100 &&
            i <= 155 &&
            i < encoded.length - 1) {
          split = i;
          break;
        }
      }
      if (split < 0) {
        skipped++;
        return;
      }
      prefix = encoded.sublist(0, split);
      name = encoded.sublist(split + 1);
    }
    final header = Uint8List(512);
    void put(int offset, List<int> value) =>
        header.setRange(offset, offset + value.length, value);
    String octal(int value, int width) =>
        value.toRadixString(8).padLeft(width - 1, '0');
    put(0, name);
    put(100, ascii.encode(octal(mode, 8)));
    put(108, ascii.encode(octal(0, 8)));
    put(116, ascii.encode(octal(0, 8)));
    put(124, ascii.encode(octal(bytes.length, 12)));
    final seconds = (modified ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    put(136, ascii.encode(octal(seconds, 12)));
    header.fillRange(148, 156, 0x20);
    header[156] = type;
    put(257, ascii.encode('ustar'));
    put(263, ascii.encode('00'));
    put(345, prefix);
    final sum = header.fold<int>(0, (a, b) => a + b);
    put(148, ascii.encode('${octal(sum, 7)}\u0000 '));
    _out.add(header);
    _out.add(bytes);
    final pad = (512 - bytes.length % 512) % 512;
    if (pad > 0) _out.add(Uint8List(pad));
  }

  Uint8List finish() {
    _out.add(Uint8List(1024));
    return _out.takeBytes();
  }
}
