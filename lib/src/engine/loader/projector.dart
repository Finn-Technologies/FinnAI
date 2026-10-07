part of '../finn_accelerator.dart';

extension FinnAcceleratorProjector on FinnAccelerator {
  /// Brings the image projector in for a turn that carries an image; every
  /// phone loads text-only (ADR 0004, extended to all phones).
  ///
  /// The projector can only be attached when the engine is spawned, so the
  /// first image costs one reload ([prepareForImages] starts it on attach);
  /// the projector then stays until the runtime is released. A device without
  /// the projector file falls through to the "image component not installed"
  /// answer.
  Future<void> _ensureProjectorIfNeeded(
    FinnModelSpec model,
    List<LocalChatTurn> history,
  ) async {
    if (_projectorRequested) return;
    final attachment = newestAttachmentTurn(history);
    if (attachment == null || !_isImageAttachment(attachment)) return;
    final profile = _deviceProfile ?? await DeviceProfiler.read();
    if (DeviceProfiler.loadsProjectorEagerly(profile)) return;
    if (!await hasMmprojFile()) return;
    _projectorRequested = true;
    final resident = _runtimes[model.tier];
    if (resident != null && !resident.engine.multimodalLoaded) {
      debugPrint('FINN_PROJECTOR reloading with the image projector');
      await _unloadModel(model.tier);
    }
  }

  /// Starts bringing the projector in as soon as an image is attached, so the
  /// reload runs while the user is still typing instead of after Send.
  ///
  /// Best effort: does nothing while a reply or another load is running, or
  /// when the projector is already in; the turn itself still calls
  /// [_ensureProjectorIfNeeded] and waits on the same deduplicated load.
  Future<void> prepareForImages() async {
    if (_projectorRequested || _replyInFlight || _benchmarkRunning) return;
    try {
      final profile = _deviceProfile ?? await DeviceProfiler.read();
      if (DeviceProfiler.loadsProjectorEagerly(profile)) return;
      if (!await hasMmprojFile()) return;
      final model = selected;
      if (!await isInstalled(model)) return;
      _projectorRequested = true;
      final resident = _runtimes[model.tier];
      if (resident != null && resident.engine.multimodalLoaded) return;
      if (_replyInFlight) return; // the turn reloads it itself
      debugPrint('FINN_PROJECTOR preloading for an attached image');
      if (resident != null) await _unloadModel(model.tier);
      final file = await _modelFile(model);
      final runtime = await _ensureLoaded(model, file.path);
      await _prepareBasePrefixState(runtime);
    } catch (error) {
      // Let the turn bring it in itself (and reload if it has to).
      _projectorRequested = false;
      debugPrint('FINN_PROJECTOR preload failed: ${error.runtimeType}');
    }
  }

  bool _isImageAttachment(LocalChatTurn turn) {
    if (turn.imageBytes != null) return true;
    final path = turn.imagePath;
    return path != null &&
        (FinnAccelerator._isImageFile(path) ||
            FinnAccelerator._isHeicPath(path));
  }
}
