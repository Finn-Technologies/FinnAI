import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/engine/profiler/device_profile.dart';

/// What the profiler reads on desktop Linux, which answers no platform channel:
/// the CPU from `/proc`, free storage from `df`, and where the bundled model
/// runtime lives.
abstract final class DesktopProfile {
  /// A desktop is not a phone chip: four real cores and 6 GB is comfortably
  /// past what the Balanced plan (4096 context, flash attention, full-size
  /// batches) assumes.
  static ProcessorClass classify(int cores, int? totalRamBytes) {
    final ram = totalRamBytes;
    if (cores >= 4 && ram != null && ram >= 6 * 1000 * 1000 * 1000) {
      return ProcessorClass.balanced;
    }
    return ProcessorClass.entry;
  }

  /// The runtime a desktop bundle ships in `lib/` beside the executable, or
  /// `null` when it is not there (a `flutter run` from source before
  /// `tool/rebuild_llama_linux.sh`, or a system that provides its own).
  /// Free bytes on the volume that holds the app's data (where the model is
  /// downloaded), or `null` when `df` is unavailable.
  static Future<int?> freeBytes() async {
    try {
      final dir = await getApplicationSupportDirectory();
      var probe = dir;
      // The data directory may not exist yet on a first run; ask about the
      // nearest parent that does.
      while (!probe.existsSync() && probe.parent.path != probe.path) {
        probe = probe.parent;
      }
      final result = await Process.run('df', ['-Pk', probe.path]);
      if (result.exitCode != 0) return null;
      return parseDfAvailableBytes(result.stdout as String);
    } catch (_) {
      return null;
    }
  }

  /// The "Available" column of `df -Pk` output, in bytes.
  @visibleForTesting
  static int? parseDfAvailableBytes(String output) {
    final lines = output
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.length < 2) return null;
    // POSIX format: Filesystem 1024-blocks Used Available Capacity Mounted-on.
    // The filesystem name can contain spaces, so count from the right.
    final fields = lines[1].trim().split(RegExp(r'\s+'));
    if (fields.length < 6) return null;
    final kilobytes = int.tryParse(fields[fields.length - 3]);
    return kilobytes == null ? null : kilobytes * 1024;
  }

  static File? bundledLlamaLibrary() {
    try {
      final lib = File(
        '${File(Platform.resolvedExecutable).parent.path}/lib/libllama.so',
      );
      return lib.existsSync() ? lib : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> cpuName() async {
    try {
      final info = await File('/proc/cpuinfo').readAsString();
      final match = RegExp(
        r'^(?:model name|Model|Hardware)\s*:\s*(.+)$',
        multiLine: true,
      ).firstMatch(info);
      final name = match?.group(1)?.trim();
      return name == null || name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }
}
