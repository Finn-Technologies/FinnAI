part of '../finn_accelerator.dart';

extension FinnAcceleratorResidency on FinnAccelerator {
  Future<void> prewarm() async {
    final profile = (Platform.isAndroid || Platform.isLinux)
        ? await DeviceProfiler.read()
        : _deviceProfile;
    if (profile != null) {
      _deviceProfile = profile;
      if (_runtimes.isEmpty) _plan = DeviceProfiler.plan(profile);
    }
    // The selected automatic tier is the product's recommended/default model.
    // Loading Lite first made every direct Plus request pay two cold loads.
    final model = _selected;
    if (!await isInstalled(model)) return;
    final file = await _modelFile(model);
    try {
      final runtime = await _ensureLoaded(model, file.path);
      await _prepareBasePrefixState(runtime);
      _setStatus(
        InferencePhase.idle,
        'Ready',
        key: FinnStatusKey.ready,
      );
    } catch (error, stack) {
      // Prewarm is opportunistic. A background failure must not become the
      // visible result of the user's next request; foreground generation can
      // retry through its normal error handling.
      debugPrint('FINN_PREWARM failed: $error\n$stack');
      _setStatus(
        InferencePhase.idle,
        'Ready',
        key: FinnStatusKey.ready,
      );
    }
  }

  Future<void> prewarmTier(FinnModelTier tier) async {
    final model = finnModels.firstWhere((candidate) => candidate.tier == tier);
    if (!await isInstalled(model)) return;
    final file = await _modelFile(model);
    final runtime = await _ensureLoaded(model, file.path);
    await _prepareBasePrefixState(runtime);
    _setStatus(
      InferencePhase.idle,
      'Ready',
      key: FinnStatusKey.ready,
    );
  }

  Future<void> releaseConversationSessions() async {
    for (final runtime in _runtimes.values) {
      final sessions = runtime.sessions.values.toList(growable: false);
      runtime.sessions.clear();
      for (final entry in sessions) {
        await entry.session.dispose();
      }
    }
  }

  Future<void> releaseMemory() {
    _invalidateDeviceProfileCache();
    _queueUnload();
    return _pendingUnload;
  }

  Future<void> handleMemoryPressure() async {
    for (final runtime in _runtimes.values) {
      if (runtime.sessions.length <= 1) continue;
      final newest = runtime.sessions.values.reduce(
        (a, b) => a.lastUsed >= b.lastUsed ? a : b,
      );
      final inactive = runtime.sessions.values
          .where((entry) => !identical(entry, newest))
          .toList(growable: false);
      for (final entry in inactive) {
        runtime.sessions.remove(entry.conversationId);
        await entry.session.dispose();
      }
    }
    for (final runtime in _runtimes.values) {
      final active = runtime.sessions.values.toList(growable: false);
      runtime.sessions.clear();
      for (final entry in active) {
        await entry.session.dispose();
      }
    }
    for (final tier in _runtimes.keys.toList(growable: false)) {
      if (tier != _selected.tier) await _unloadModel(tier);
    }
    // Memory pressure is exactly when a stale profile would mislead the
    // low-RAM decisions below, so force a fresh read and re-prime the cache.
    _invalidateDeviceProfileCache();
    final profile = await _profileForTurn();
    final tightRam = profile.availableRamBytes != null &&
        profile.availableRamBytes! < 1200 * 1024 * 1024;
    if (profile.lowMemory || tightRam) await _unloadModel(_selected.tier);
  }

  ModelResidencyLevel residencyFor(FinnModelTier tier) {
    final runtime = _runtimes[tier];
    if (runtime == null) return ModelResidencyLevel.unloaded;
    if (runtime.sessions.values.any((entry) => entry.primed)) {
      return ModelResidencyLevel.conversationWarm;
    }
    return ModelResidencyLevel.engineReady;
  }

  @visibleForTesting
  bool get hasDuplicateLoadJobs => _deduplicatedLoads.activeJobCount > 1;

  Future<Set<String>> remove(FinnModelSpec model) async {
    final failures = <String>{};
    await _unloadModel(model.tier);
    try {
      final file = await _modelFile(model);
      final removed = await removeModelArtifactFiles(file);
      if (removed.isEmpty) {
        debugPrint('No model artifacts to remove for ${file.path}');
      }
    } catch (e) {
      if (!e.toString().contains('MissingPluginException')) {
        debugPrint('Model file removal error: $e');
        failures.add('Downloaded model (${model.name})');
      }
    }
    try {
      await _removePrefixStatesFor(model.sha256Digest);
    } catch (error) {
      if (!error.toString().contains('MissingPluginException')) {
        debugPrint('Prefix cache removal error: $error');
        failures.add('Model prefix cache (${model.name})');
      }
    }
    _verifiedModels.remove(model.tier);
    _setStatus(
      InferencePhase.idle,
      'Model removed',
      key: FinnStatusKey.modelRemoved,
    );
    return failures;
  }

  Future<Set<String>> removeAllModels() async {
    await _cancelActiveInstallForRemoval();
    final failures = <String>{};
    for (final model in finnModels) {
      final res = await remove(model);
      failures.addAll(res);
    }
    failures.addAll(await removeMmproj());
    return failures;
  }

  Future<Set<String>> removeMmproj() async {
    final failures = <String>{};
    try {
      final file = await _mmprojFile();
      // removeModelArtifactFiles already clears the .part range side-files.
      await removeModelArtifactFiles(file);
    } catch (error) {
      if (!error.toString().contains('MissingPluginException')) {
        debugPrint('Projector file removal error: $error');
        failures.add('Post-model component');
      }
    }
    _setStatus(
      InferencePhase.idle,
      'Model removed',
      key: FinnStatusKey.modelRemoved,
    );
    return failures;
  }
}
