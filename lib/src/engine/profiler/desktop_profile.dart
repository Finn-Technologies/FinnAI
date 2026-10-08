import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/engine/profiler/device_profile.dart';

/// What the profiler reads on desktop platforms (Linux and Windows), which
/// answer no mobile platform channel: CPU topology, free storage, system RAM,
/// and where the bundled model runtime lives.
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

  /// Free bytes on the volume that holds the app's data (where the model is
  /// downloaded).
  static Future<int?> freeBytes() async {
    if (Platform.isWindows) {
      try {
        final dir = await getApplicationSupportDirectory();
        final kernel32 = DynamicLibrary.open('kernel32.dll');
        final getDiskFreeSpaceEx = kernel32.lookupFunction<
            Int32 Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>,
                Pointer<Uint64>),
            int Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>,
                Pointer<Uint64>)>('GetDiskFreeSpaceExW');
        final pathPtr = dir.path.toNativeUtf16(allocator: calloc);
        final freeBytesAvailable = calloc<Uint64>();
        try {
          if (getDiskFreeSpaceEx(
                  pathPtr, freeBytesAvailable, nullptr, nullptr) !=
              0) {
            return freeBytesAvailable.value;
          }
        } finally {
          calloc.free(pathPtr);
          calloc.free(freeBytesAvailable);
        }
      } catch (_) {}
      return null;
    }
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
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      if (Platform.isWindows) {
        final lib = File('$exeDir${Platform.pathSeparator}llama.dll');
        return lib.existsSync() ? lib : null;
      }
      final lib = File('$exeDir/lib/libllama.so');
      return lib.existsSync() ? lib : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> cpuName() async {
    if (Platform.isWindows) {
      final id = Platform.environment['PROCESSOR_IDENTIFIER'];
      if (id != null && id.trim().isNotEmpty) return id.trim();
      return null;
    }
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

  /// Reads total and available physical RAM on Windows via GlobalMemoryStatusEx.
  static int? windowsMemoryBytes(String field) {
    if (!Platform.isWindows) return null;
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final globalMemoryStatusEx = kernel32.lookupFunction<
          Int32 Function(Pointer<Uint8>),
          int Function(Pointer<Uint8>)>('GlobalMemoryStatusEx');
      final buffer = calloc<Uint8>(64);
      try {
        // Set dwLength = sizeof(MEMORYSTATUSEX) = 64
        buffer
            .asTypedList(64)
            .buffer
            .asByteData()
            .setUint32(0, 64, Endian.little);
        if (globalMemoryStatusEx(buffer) != 0) {
          final data = buffer.asTypedList(64).buffer.asByteData();
          final totalPhys = data.getUint64(8, Endian.little);
          final availPhys = data.getUint64(16, Endian.little);
          if (field == 'MemTotal') return totalPhys;
          if (field == 'MemAvailable') return availPhys;
        }
      } finally {
        calloc.free(buffer);
      }
    } catch (_) {}
    return null;
  }
}
