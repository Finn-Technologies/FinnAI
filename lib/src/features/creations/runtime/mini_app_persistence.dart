import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_state.dart';

/// What a mini app remembers between launches.
///
/// A shopping list that forgets its items when it is closed is a toy. The
/// values live beside the creations on the device, one small JSON file per app,
/// and are read back through [MiniAppState.restore], which treats the file as
/// untrusted.
class MiniAppStateStore {
  MiniAppStateStore({CreationStore? store})
      : _store = store ?? CreationStore.instance;

  final CreationStore _store;

  /// A file larger than this is ignored rather than parsed.
  static const int maxFileBytes = 256 * 1024;

  Future<File> _file(String creationId) async {
    final directory = await _store.appStateDirectory();
    final safe = creationId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File('${directory.path}/$safe.json');
  }

  /// The saved values, or an empty map when there are none or they are damaged.
  Future<Map<String, Object?>> load(String creationId) async {
    try {
      final file = await _file(creationId);
      if (!await file.exists() || await file.length() > maxFileBytes) {
        return const {};
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map && decoded['values'] is Map) {
        return Map<String, Object?>.from(decoded['values']! as Map);
      }
    } on Object catch (error) {
      debugPrint('FINN_APP_STATE load failed: $error');
    }
    return const {};
  }

  Future<void> save(String creationId, Map<String, Object?> values) async {
    try {
      final file = await _file(creationId);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode({'version': 1, 'values': values}),
        flush: true,
      );
      await temporary.rename(file.path);
    } on Object catch (error) {
      debugPrint('FINN_APP_STATE save failed: $error');
    }
  }

  Future<void> clear(String creationId) async {
    try {
      final file = await _file(creationId);
      if (await file.exists()) await file.delete();
    } on Object {
      // Nothing to forget is the same as forgotten.
    }
  }
}

/// Keeps a [MiniAppState] saved: loads it once, then writes it shortly after
/// each change so a burst of typing is one write.
class MiniAppAutosave {
  MiniAppAutosave({
    required this.creationId,
    required this.state,
    required this.store,
    this.delay = const Duration(milliseconds: 400),
  });

  final String creationId;
  final MiniAppState state;
  final MiniAppStateStore store;
  final Duration delay;

  Timer? _timer;
  bool _disposed = false;
  bool _restored = false;

  /// Restores the saved values, then starts saving changes.
  Future<void> start() async {
    final saved = await store.load(creationId);
    if (_disposed) return;
    state.restore(saved);
    _restored = true;
    state.addListener(_changed);
  }

  void _changed() {
    if (!_restored || _disposed) return;
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  /// Writes now. Called when the screen closes so the last tap is not lost.
  Future<void> flush() async {
    _timer?.cancel();
    if (!_restored) return;
    await store.save(creationId, state.values);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    state.removeListener(_changed);
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      // The screen is closing: write what is there, without waiting for it.
      unawaited(store.save(creationId, state.values));
    }
  }
}
