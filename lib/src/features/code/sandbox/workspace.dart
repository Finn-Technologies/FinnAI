import 'dart:convert';
import 'dart:io';

/// A path the agent asked for that would leave its project folder.
class WorkspaceEscape implements Exception {
  const WorkspaceEscape(this.path);

  final String path;

  @override
  String toString() => 'Path is outside the project folder: $path';
}

/// One file or folder inside a [CodeWorkspace], relative to its root.
class WorkspaceEntry {
  const WorkspaceEntry({
    required this.path,
    required this.isDirectory,
    required this.bytes,
  });

  /// Slash-separated and relative to the workspace root.
  final String path;
  final bool isDirectory;
  final int bytes;

  String get name => path.split('/').last;
}

/// The project folder one coding session works in.
///
/// Every file the agent writes and every command it runs is confined to
/// [root]. The rules live in one place so the file tool, the shell and the
/// Files screen cannot disagree about what "inside" means.
class CodeWorkspace {
  CodeWorkspace(this.root);

  final Directory root;

  /// Largest file the agent may write in one go.
  static const int maxFileBytes = 256 * 1024;

  /// Largest file the Files screen will open as text.
  static const int maxReadBytes = 128 * 1024;

  /// Folders the sandbox itself uses; hidden from listings and the agent.
  static const String scratchDir = '.tmp';

  Future<void> ensureCreated() async {
    await root.create(recursive: true);
    await Directory('${root.path}/$scratchDir').create(recursive: true);
  }

  /// Normalises [path] to a slash-separated path relative to the root.
  ///
  /// Throws [WorkspaceEscape] for anything absolute, anything that climbs out
  /// with `..`, and anything with characters a path cannot carry. The agent
  /// is a small language model: it is told to use relative paths, and this is
  /// what makes that a rule instead of a hope.
  static String normalize(String path) {
    final raw = path.trim();
    if (raw.isEmpty ||
        raw.contains('\u0000') ||
        raw.contains('\\') ||
        raw.startsWith('/') ||
        raw.startsWith('~')) {
      throw WorkspaceEscape(path);
    }
    final parts = <String>[];
    for (final part in raw.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isEmpty) throw WorkspaceEscape(path);
        parts.removeLast();
        continue;
      }
      parts.add(part);
    }
    if (parts.isEmpty) throw WorkspaceEscape(path);
    if (parts.first == scratchDir) throw WorkspaceEscape(path);
    return parts.join('/');
  }

  File fileFor(String path) => File('${root.path}/${normalize(path)}');

  /// True when [target], with symbolic links followed, is still under [root].
  ///
  /// `normalize` stops `..`; this stops a link the shell made pointing out of
  /// the folder.
  Future<bool> _contained(FileSystemEntity target) async {
    try {
      final base = await root.resolveSymbolicLinks();
      final resolved = await (await target.exists() ? target : target.parent)
          .resolveSymbolicLinks();
      return resolved == base || resolved.startsWith('$base/');
    } on FileSystemException {
      return false;
    }
  }

  /// Writes [content] to [path], creating folders as needed. Returns the
  /// normalised relative path.
  Future<String> writeFile(String path, String content) async {
    final relative = normalize(path);
    if (utf8.encode(content).length > maxFileBytes) {
      throw FileSystemException(
        'File is larger than ${maxFileBytes ~/ 1024} KB',
        relative,
      );
    }
    await ensureCreated();
    final file = File('${root.path}/$relative');
    await file.parent.create(recursive: true);
    if (!await _contained(file.parent)) throw WorkspaceEscape(path);
    if (await FileSystemEntity.isLink(file.path)) throw WorkspaceEscape(path);
    await file.writeAsString(content, flush: true);
    return relative;
  }

  /// Largest file the user may add from outside the folder.
  static const int maxImportBytes = 8 * 1024 * 1024;

  /// Copies [source] (a file the user picked) into the top of the folder and
  /// returns its relative path. A name already taken gets " (2)", " (3)"…
  /// so an import never overwrites the project.
  Future<String> importFile(File source, {String? name}) async {
    final length = await source.length();
    if (length > maxImportBytes) {
      throw FileSystemException(
        'File is larger than ${maxImportBytes ~/ (1024 * 1024)} MB',
        source.path,
      );
    }
    final original =
        normalize((name ?? source.uri.pathSegments.last).replaceAll('/', '_'));
    final dot = original.lastIndexOf('.');
    final stem = dot > 0 ? original.substring(0, dot) : original;
    final extension = dot > 0 ? original.substring(dot) : '';
    var candidate = original;
    for (var n = 2;
        await File('${root.path}/$candidate').exists() ||
            await Directory('${root.path}/$candidate').exists();
        n++) {
      candidate = '$stem ($n)$extension';
    }
    await ensureCreated();
    await source.copy('${root.path}/$candidate');
    return candidate;
  }

  /// Reads up to [maxReadBytes] of [path] as text.
  Future<String> readFile(String path) async {
    final file = fileFor(path);
    if (!await file.exists()) {
      throw FileSystemException('No such file', normalize(path));
    }
    if (!await _contained(file)) throw WorkspaceEscape(path);
    final length = await file.length();
    final bytes = await file
        .openRead(0, length > maxReadBytes ? maxReadBytes : length)
        .expand((chunk) => chunk)
        .toList();
    final text = utf8.decode(bytes, allowMalformed: true);
    return length > maxReadBytes ? '$text\n…' : text;
  }

  /// Everything under [directory] (the root by default), folders first, then
  /// by name. Links are shown but never followed.
  Future<List<WorkspaceEntry>> list({String directory = ''}) async {
    final base = directory.isEmpty
        ? root
        : Directory('${root.path}/${normalize(directory)}');
    if (!await base.exists()) return const [];
    if (!await _contained(base)) throw WorkspaceEscape(directory);
    final prefix = directory.isEmpty ? '' : '${normalize(directory)}/';
    final entries = <WorkspaceEntry>[];
    await for (final entity in base.list(followLinks: false)) {
      final name = entity.path.split('/').last;
      if (name == scratchDir) continue;
      final isDirectory = entity is Directory;
      var bytes = 0;
      if (entity is File) {
        try {
          bytes = await entity.length();
        } on FileSystemException {
          bytes = 0;
        }
      }
      entries.add(
        WorkspaceEntry(
          path: '$prefix$name',
          isDirectory: isDirectory,
          bytes: bytes,
        ),
      );
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  /// Every file in the workspace, relative paths, capped at [limit].
  Future<List<String>> allFiles({int limit = 400}) async {
    final out = <String>[];
    Future<void> walk(String directory) async {
      for (final entry in await list(directory: directory)) {
        if (out.length >= limit) return;
        if (entry.isDirectory) {
          await walk(entry.path);
        } else {
          out.add(entry.path);
        }
      }
    }

    await walk('');
    return out;
  }

  Future<void> delete(String path) async {
    final relative = normalize(path);
    final target = FileSystemEntity.typeSync('${root.path}/$relative',
                followLinks: false) ==
            FileSystemEntityType.directory
        ? Directory('${root.path}/$relative')
        : File('${root.path}/$relative');
    if (!await _contained(target.parent)) throw WorkspaceEscape(path);
    if (await target.exists() || await FileSystemEntity.isLink(target.path)) {
      await target.delete(recursive: true);
    }
  }

  /// Bytes used by everything in the workspace.
  Future<int> sizeBytes() async {
    var total = 0;
    if (!await root.exists()) return 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on FileSystemException {
          // Removed while measuring.
        }
      }
    }
    return total;
  }

  Future<void> deleteAll() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
