part of '../finn_accelerator.dart';

extension FinnAcceleratorInstall on FinnAccelerator {
  Future<void> initialize() async {
    _deviceProfile = await DeviceProfiler.read();
    _deviceProfileCache = _deviceProfile;
    _deviceProfileCacheAt = DateTime.now();
    _plan = DeviceProfiler.plan(_deviceProfile!);
    // Clean up any retired legacy artifacts in background without blocking startup
    unawaited(_removeRetiredModelArtifacts());
    _selected = finnModels.single;
    _automaticSelection = true;
  }

  void select(FinnModelTier tier) {
    if (tier != FinnModelTier.standard || !_automaticSelection) return;
    _automaticSelection = false;
    _setStatus(
      InferencePhase.idle,
      'Ready',
      key: FinnStatusKey.ready,
    );
  }

  void useAutomaticSelection() {
    _automaticSelection = true;
    _setStatus(
      InferencePhase.idle,
      'Optimized automatically',
      key: FinnStatusKey.optimizedAutomatically,
    );
  }

  Future<bool> isInstalled(FinnModelSpec model) async {
    if (_verifiedModels.contains(model.tier)) return true;
    final file = await _modelFile(model);
    final installed = await _isVerifiedModelFile(model, file);
    if (installed) _verifiedModels.add(model.tier);
    return installed;
  }

  Future<List<ModelStorageState>> inspectModels() async {
    final states = <ModelStorageState>[];
    for (final model in finnModels) {
      final file = await _modelFile(model);
      final partial = File('${file.path}.part');
      final installed = await isInstalled(model);
      states.add(
        ModelStorageState(
          model: model,
          installedBytes: installed ? await file.length() : 0,
          partialBytes: await partial.exists() ? await partial.length() : 0,
        ),
      );
    }
    return states;
  }

  Future<FinnModelTier> recommendedTier() async {
    return FinnModelTier.standard;
  }

  Future<void> install(FinnModelSpec model) {
    // A model can be verified from a previous app run while the post-model
    // component is still missing. Re-entering install must finish that second
    // artifact instead of treating the whole install as complete.
    if (_verifiedModels.contains(model.tier)) return _preinstallMmproj();
    final running = _installJob;
    if (running != null) {
      if (_workingModel == model) return running;
      return Future<void>.error(
        StateError('Another model download is already in progress.'),
      );
    }
    _workingModel = model;
    _cancelDownload = false;
    final job = _runInstall(model);
    _installJob = job;
    // ignore: invalid_use_of_protected_member
    notifyListeners();
    return job;
  }

  Future<void> installRequiredModels() async {
    for (final model in requiredModels) {
      if (!await isInstalled(model)) await install(model);
    }
    // The projector is a separate artifact by design. It is downloaded only
    // after the language model has been verified, but it is not loaded or
    // exposed as an input capability in this release.
    await _preinstallMmproj();
  }

  Future<void> resumeInterruptedDownloads() async {
    for (final model in requiredModels) {
      final target = await _modelFile(model);
      // Avoid the full SHA-256 verification here; a right-sized target is
      // treated as installed and re-verified lazily when the engine loads it.
      if (await target.exists() &&
          await target.length() == model.expectedBytes) {
        continue;
      }
      final partial = File('${target.path}.part');
      if (!await partial.exists() || await partial.length() <= 0) continue;
      unawaited(
        install(model).catchError((Object _) {
          // _runInstall already surfaced the failure through the status
          // listener; this only prevents an unhandled async error at startup.
        }),
      );
    }
    await _resumeInterruptedMmproj();
  }

  Future<void> _resumeInterruptedMmproj() async {
    if (await isMmprojInstalled()) return;
    // The projector is only meaningful once the language model is present;
    // otherwise onboarding drives the whole install.
    final model = finnModels.single;
    if (!await _isVerifiedModelFile(model, await _modelFile(model))) return;
    final target = await _mmprojFile();
    final partial = File('${target.path}.part');
    if (!await partial.exists() || await partial.length() <= 0) return;
    // _preinstallMmproj sizes the aggregate progress and swallows transfer
    // errors, so resuming here cannot surface as an unhandled async error.
    unawaited(_preinstallMmproj());
  }

  Future<void> _preinstallMmproj() async {
    if (await isMmprojInstalled()) return;
    // Standalone projector install (the language model was already verified):
    // size the aggregate progress to this artifact alone. When called from
    // _runInstall the total was already set to model + component, so this
    // guard leaves it untouched.
    var trackedStandalone = false;
    if (_installTotalBytes <= 0) {
      _installTotalBytes = finnMmproj.expectedBytes;
      _installCompletedBytes = 0;
      trackedStandalone = true;
    }
    try {
      await installMmproj();
    } catch (error, stack) {
      // Text chat remains usable if the future-vision artifact is unavailable.
      debugPrint('FINN_MMPROJ download skipped: $error\n$stack');
      if (_phase == InferencePhase.downloading ||
          _phase == InferencePhase.loading) {
        _setStatus(
          InferencePhase.idle,
          'AI model is ready',
          key: FinnStatusKey.modelReady,
        );
      }
    } finally {
      if (trackedStandalone) {
        _installTotalBytes = 0;
        _installCompletedBytes = 0;
      }
    }
  }

  Future<void> _runInstall(FinnModelSpec model) async {
    try {
      // Size the aggregate progress across every artifact this install must
      // fetch: the language model (unless already verified) plus the
      // post-model multimodal component (unless already present).
      final modelAlreadyInstalled = await isInstalled(model);
      final componentAlreadyInstalled = await isMmprojInstalled();
      _installTotalBytes = (modelAlreadyInstalled ? 0 : model.expectedBytes) +
          (componentAlreadyInstalled ? 0 : finnMmproj.expectedBytes);
      _installCompletedBytes = 0;
      await _ensureDownloaded(model);
      _verifiedModels.add(model.tier);
      // Keep the projector out of the runtime for now, but install it as the
      // second verified artifact so a future vision release does not need to
      // redownload the model package.
      await _preinstallMmproj();
      _setStatus(
        InferencePhase.idle,
        'AI model is ready',
        key: FinnStatusKey.modelReady,
      );
    } catch (error) {
      if (_cancelDownload) {
        _setStatus(
          InferencePhase.idle,
          'Download paused',
          key: FinnStatusKey.downloadPaused,
        );
        return;
      }
      _setStatus(
        InferencePhase.error,
        _friendlyError(error),
        key: FinnStatusKey.error,
      );
      rethrow;
    } finally {
      _workingModel = null;
      _installJob = null;
      _downloadClient = null;
      _cancelDownload = false;
      _installTotalBytes = 0;
      _installCompletedBytes = 0;
    }
  }

  void _completeInstallArtifact(int expectedBytes) {
    _installCompletedBytes += expectedBytes;
    _downloadReceivedBytes = 0;
    debugPrint('FINN_INSTALL_ARTIFACT_COMPLETE: $expectedBytes bytes');
  }

  void pauseDownload() {
    if (_workingModel == null || _phase != InferencePhase.downloading) return;
    _cancelDownload = true;
    _downloadClient?.close(force: true);
    // Abort in-flight range/stream reads too: a stalled stream observes no
    // bytes, so it would never reach the cancel check on its own.
    for (final client in _activeDownloadClients.toList()) {
      try {
        client.close(force: true);
      } catch (_) {}
    }
    if (Platform.isAndroid) {
      final model = _workingModel;
      if (model != null) {
        unawaited(
          _modelFile(model).then((file) => _cancelAndroidDownload(file.path)),
        );
      }
    }
  }

  Future<void> _cancelActiveInstallForRemoval() async {
    _cancelDownload = true;
    try {
      _downloadClient?.close(force: true);
      for (final client in _activeDownloadClients.toList()) {
        try {
          client.close(force: true);
        } catch (_) {}
      }
      if (Platform.isAndroid) {
        final model = _workingModel;
        if (model != null) {
          await _cancelAndroidDownload((await _modelFile(model)).path);
        }
        await _cancelAndroidDownload((await _mmprojFile()).path);
      }
    } catch (_) {
      // Cancellation is best-effort; the delete below still has to run.
    }
    final running = _installJob;
    if (running != null) {
      try {
        await running;
      } catch (_) {
        // The install already surfaced its own failure through the status
        // listener; removal must not be blocked by it.
      }
    }
    _workingModel = null;
    _installJob = null;
    _cancelDownload = false;
  }

  Future<void> _cancelAndroidDownload(String targetPath) async {
    try {
      await FinnAccelerator._backgroundDownloadChannel
          .invokeMethod<void>('cancel', {
        'target': targetPath,
      });
    } on PlatformException {
      // The foreground download is opportunistic on unsupported platform
      // versions; Dart-side cancellation still stops its own HTTP client.
    } on MissingPluginException {
      // Background channel absent on non-Android hosts; nothing to cancel.
    }
  }
}
