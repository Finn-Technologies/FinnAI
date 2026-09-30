part of '../finn_accelerator.dart';

extension FinnAcceleratorProjector on FinnAccelerator {
  /// Brings the image projector in for a turn that carries an image, on a
  /// device that loaded text-only (ADR 0004).
  ///
  /// The projector can only be attached when the engine is spawned, so the
  /// first image on a Lite device costs one reload; the projector then stays
  /// until the runtime is released. A capable device already has it, and a
  /// device without the projector file falls through to the existing "image
  /// component not installed" answer.
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

  bool _isImageAttachment(LocalChatTurn turn) {
    if (turn.imageBytes != null) return true;
    final path = turn.imagePath;
    return path != null &&
        (FinnAccelerator._isImageFile(path) ||
            FinnAccelerator._isHeicPath(path));
  }
}
