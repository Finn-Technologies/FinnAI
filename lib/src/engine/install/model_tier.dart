part of '../finn_accelerator.dart';

/// Which tier this device runs, and moving between tiers (ADR 0013).
///
/// The choice, once made, is kept in `models/tier` so an app update or a
/// policy change never switches someone's model under them. Without a stored
/// choice: a model already on the device keeps its tier (no surprise 2 GB
/// download), otherwise [ModelTierPolicy] decides.
extension FinnAcceleratorTier on FinnAccelerator {
  Future<void> _initTier(DeviceProfile profile) async {
    try {
      _recommendedTier = ModelTierPolicy.recommend(
        totalRamBytes: profile.totalRamBytes,
        soc: profile.soc,
        cores: await ModelTierPolicy.readCores(),
      );
    } catch (_) {
      _recommendedTier = FinnModelTier.standard;
    }
    final stored = await _storedTier();
    var tier = stored;
    if (tier == null) {
      for (final model in finnModels) {
        final file = await _modelFile(model);
        if (await file.exists() && await file.length() == model.expectedBytes) {
          tier = model.tier;
          break;
        }
      }
    }
    _selected = finnModelFor(tier ?? _recommendedTier);
    debugPrint(
      'FINN_TIER recommended=${_recommendedTier.name} '
      'selected=${_selected.tier.name} stored=${stored?.name}',
    );
  }

  /// What the policy recommends for this device.
  FinnModelTier get recommendedTierNow => _recommendedTier;

  /// This device could run the larger model but has the smaller one.
  bool get betterTierAvailable =>
      _recommendedTier == FinnModelTier.plus &&
      _selected.tier == FinnModelTier.standard;

  /// Makes [tier] the selected model. Nothing is downloaded or deleted here:
  /// the caller installs it, then calls [removeOtherTiers] once it is ready,
  /// so a switch that fails half-way leaves the old model working.
  Future<void> chooseTier(FinnModelTier tier) async {
    if (_selected.tier == tier) {
      await _storeTier(tier);
      return;
    }
    if (_installJob != null) await _cancelActiveInstallForRemoval();
    await _unload();
    _selected = finnModelFor(tier);
    await _storeTier(tier);
    // ignore: invalid_use_of_protected_member
    notifyListeners();
  }

  /// Deletes the models (and projectors) of every tier but the selected one.
  Future<Set<String>> removeOtherTiers() async {
    final failures = <String>{};
    for (final model in finnModels) {
      if (model.tier == _selected.tier) continue;
      failures.addAll(await remove(model));
    }
    failures.addAll(await _removeProjectorsExcept(activeProjector));
    return failures;
  }

  Future<Set<String>> _removeProjectorsExcept(FinnModelArtifact? keep) async {
    final failures = <String>{};
    final directory = await (_modelDirectoryJob ??= _createModelDirectory());
    for (final model in finnModels) {
      final projector = model.projector;
      if (projector == null || projector.fileName == keep?.fileName) continue;
      try {
        await removeModelArtifactFiles(File(
          '${directory.path}${Platform.pathSeparator}${projector.fileName}',
        ));
      } catch (_) {
        failures.add(projector.name);
      }
    }
    return failures;
  }

  Future<File> _tierFile() async {
    final directory = await (_modelDirectoryJob ??= _createModelDirectory());
    return File('${directory.path}${Platform.pathSeparator}tier');
  }

  Future<FinnModelTier?> _storedTier() async {
    try {
      final file = await _tierFile();
      if (!await file.exists()) return null;
      final name = (await file.readAsString()).trim();
      return FinnModelTier.values.where((t) => t.name == name).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<void> _storeTier(FinnModelTier tier) async {
    try {
      await (await _tierFile()).writeAsString(tier.name, flush: true);
    } catch (error) {
      debugPrint('FINN_TIER could not store choice: $error');
    }
  }
}
