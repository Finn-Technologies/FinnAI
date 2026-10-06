import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/inference/finn_inference.dart';

/// An optional download that rides along with the language model — today the
/// on-device speech model. Onboarding does not know what it is; the app layer
/// supplies it, so this feature stays free of other features.
abstract class InstallAddon {
  int get totalBytes;

  /// 0..1 while [install] runs.
  ValueListenable<double> get progress;

  Future<bool> isInstalled();

  /// Whether an upgrading user should be taken to the install screen for this.
  /// False once it has been tried and failed, so an offline launch is not held
  /// up on every start.
  Future<bool> shouldOfferOnUpgrade();

  /// Throws when the download could not finish.
  Future<void> install();

  /// Remembers that an install was tried and did not finish.
  Future<void> markFailed();
}

/// What [ModelInstall] needs from the engine, so a test can stand in for it.
abstract class ModelInstallSource implements Listenable {
  List<FinnModelSpec> get requiredModels;

  /// Aggregate 0..1 across the language model and its projector, or null.
  double? get installProgress;

  Future<void> install(FinnModelSpec model);

  Future<bool> isInstalled(FinnModelSpec model);
}

class _EngineSource implements ModelInstallSource {
  _EngineSource(this._inference);

  final FinnInference _inference;

  @override
  List<FinnModelSpec> get requiredModels => _inference.requiredModels;

  @override
  double? get installProgress => _inference.installProgress;

  @override
  Future<void> install(FinnModelSpec model) => _inference.install(model);

  @override
  Future<bool> isInstalled(FinnModelSpec model) =>
      _inference.isInstalled(model);

  @override
  void addListener(VoidCallback listener) => _inference.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _inference.removeListener(listener);
}

/// Installs the language model and then every add-on, and reports one
/// progress value across all of it.
///
/// The language model is required: if it fails, [run] throws and the screen
/// shows its retry. An add-on is not: the app works without it, so a failure
/// is logged and the screen carries on. Holding someone on a download screen
/// for a feature they have not asked for yet would be worse than the feature
/// asking for itself later, which voice mode does.
class ModelInstall {
  ModelInstall({
    ModelInstallSource? source,
    List<InstallAddon> addons = const [],
    required this.onChanged,
  })  : _inference = source ?? _EngineSource(FinnInference.instance),
        _addons = addons;

  final ModelInstallSource _inference;
  final List<InstallAddon> _addons;

  /// Called when [progress] may have changed.
  final VoidCallback onChanged;

  double progress = .02;

  /// Bytes counted in [progress], so a read-out beside it agrees with it.
  int receivedBytes = 0;

  bool _modelDone = false;
  double _modelFraction = 0;

  void attach() {
    _inference.addListener(_onInference);
    for (final addon in _addons) {
      addon.progress.addListener(_recompute);
    }
  }

  void detach() {
    _inference.removeListener(_onInference);
    for (final addon in _addons) {
      addon.progress.removeListener(_recompute);
    }
  }

  int get _modelBytes =>
      _inference.requiredModels.fold<int>(0, (s, m) => s + m.expectedBytes) +
      finnMmproj.expectedBytes;

  int get _addonBytes => _addons.fold<int>(0, (s, a) => s + a.totalBytes);

  /// Everything the install will fetch, for the byte read-out.
  int get totalBytes => _modelBytes + _addonBytes;

  void _onInference() {
    // Aggregate progress spans the language model and the multimodal
    // component, so the bar keeps moving across the switch between them.
    final aggregate = _inference.installProgress;
    if (aggregate != null && !_modelDone) _modelFraction = aggregate;
    _recompute();
  }

  void _recompute() {
    final total = totalBytes;
    if (total <= 0) return;
    var done = (_modelDone ? 1.0 : _modelFraction) * _modelBytes;
    for (final addon in _addons) {
      done += addon.progress.value * addon.totalBytes;
    }
    progress = (done / total).clamp(0.0, 1.0);
    receivedBytes = done.round().clamp(0, total);
    onChanged();
  }

  /// Installs and verifies every required model, then the add-ons.
  Future<void> run({
    required String verificationFailedMessage,
    bool Function()? isCancelled,
  }) async {
    final models = _inference.requiredModels;
    for (var index = 0; index < models.length; index++) {
      final model = models[index];
      debugPrint('FINN_INSTALLING_MODEL: ${model.name} (${model.downloadUrl})');
      // Calling install even for an existing language model also completes the
      // post-model projector download after an upgrade or an interrupted
      // first run.
      await _inference.install(model);
      if (!await _inference.isInstalled(model)) {
        throw FormatException(verificationFailedMessage);
      }
    }
    _modelDone = true;
    _recompute();
    for (final addon in _addons) {
      if (isCancelled?.call() ?? false) return;
      try {
        if (!await addon.isInstalled()) await addon.install();
      } catch (error) {
        debugPrint('FINN_INSTALL addon failed (continuing): $error');
        await addon.markFailed();
      }
    }
  }
}
