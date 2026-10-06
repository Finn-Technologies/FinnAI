import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// How much space FinnAI uses on this device, grouped the way Settings shows it.
class StorageUsage {
  const StorageUsage({
    this.chats = 0,
    this.creations = 0,
    this.you = 0,
    this.model = 0,
  });

  final int chats;
  final int creations;
  final int you;
  final int model;

  static final String _sep = Platform.pathSeparator;

  /// Measures the app's own folders. Never throws: unreadable files count as 0.
  static Future<StorageUsage> measure() async {
    var chats = 0;
    var creations = 0;
    var you = 0;
    var model = 0;
    try {
      final support = await getApplicationSupportDirectory();
      await for (final entity in support.list(recursive: true)) {
        if (entity is! File) continue;
        final length = await _length(entity);
        final path = entity.path;
        if (path.contains('${_sep}models$_sep')) {
          model += length;
        } else if (path.contains('conversations')) {
          chats += length;
        } else if (path.contains('user_personalization') ||
            path.contains('you_memory')) {
          you += length;
        } else if (path.contains('flows') || path.contains('creations')) {
          creations += length;
        }
      }
    } catch (_) {}
    try {
      final documents = await getApplicationDocumentsDirectory();
      final directory = Directory('${documents.path}${_sep}creations');
      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) creations += await _length(entity);
        }
      }
    } catch (_) {}
    return StorageUsage(
      chats: chats,
      creations: creations,
      you: you,
      model: model,
    );
  }

  /// When the model file was written, or null when it is not installed.
  static Future<DateTime?> modelInstalledAt() async {
    try {
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}${_sep}models');
      if (!await directory.exists()) return null;
      DateTime? newest;
      await for (final entity in directory.list()) {
        if (entity is! File || !entity.path.endsWith('.gguf')) continue;
        final modified = await entity.lastModified();
        if (newest == null || modified.isAfter(newest)) newest = modified;
      }
      return newest;
    } catch (_) {
      return null;
    }
  }

  static Future<int> _length(File file) async {
    try {
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

  /// `120MB`, `1.49GB`, `4MB`: the short form the design uses.
  static String label(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).round()} MB';
    if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
    return '$bytes B';
  }
}
