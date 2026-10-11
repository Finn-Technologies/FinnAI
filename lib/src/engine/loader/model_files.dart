part of '../finn_accelerator.dart';

extension FinnAcceleratorModelFiles on FinnAccelerator {
  Future<void> _unload() async {
    await _generation?.cancel();
    _generation = null;
    final output = _activeOutput;
    _activeOutput = null;
    if (output != null && !output.isClosed) await output.close();
    final runtimes = _runtimes.values.toList(growable: false);
    _runtimes.clear();
    _projectorRequested = false;
    for (final runtime in runtimes) {
      for (final entry in runtime.sessions.values) {
        await entry.session.dispose();
      }
      await runtime.engine.dispose();
    }
  }

  void _queueUnload() {
    _runtimeEpoch++;
    _pendingUnload = _pendingUnload.then((_) => _unload());
  }

  Future<void> _unloadModel(FinnModelTier tier) async {
    // Direct tier unloads must invalidate an in-flight load too. Otherwise an
    // old load can finish after this unload and resurrect a removed runtime.
    _runtimeEpoch++;
    final runtime = _runtimes.remove(tier);
    if (runtime == null) return;
    for (final entry in runtime.sessions.values) {
      await entry.session.dispose();
    }
    await runtime.engine.dispose();
  }

  Future<File> _modelFile(FinnModelSpec model) async {
    final directory = await (_modelDirectoryJob ??= _createModelDirectory());
    return File('${directory.path}${Platform.pathSeparator}${model.fileName}');
  }

  Future<File> _mmprojFile() async {
    final directory = await (_modelDirectoryJob ??= _createModelDirectory());
    return File(
      '${directory.path}${Platform.pathSeparator}${activeProjector.fileName}',
    );
  }

  Future<bool> hasMmprojFile() async {
    final file = await _mmprojFile();
    return await file.exists() &&
        await file.length() == activeProjector.expectedBytes;
  }

  Future<bool> isMmprojInstalled() async {
    final file = await _mmprojFile();
    if (!await file.exists() ||
        await file.length() != activeProjector.expectedBytes) {
      return false;
    }
    try {
      await _verifyArtifactDigest(file, activeProjector.sha256Digest);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> installMmproj() async {
    if (await isMmprojInstalled()) return;
    if (Platform.isAndroid) {
      final storageProfile = await DeviceProfiler.read();
      final availableStorage = storageProfile.availableStorageBytes;
      const reserve = 256 * 1024 * 1024;
      if (availableStorage != null &&
          availableStorage < activeProjector.expectedBytes + reserve) {
        throw const FileSystemException(
          'Not enough storage for the multimodal component and safety reserve.',
        );
      }
    }
    final target = await _mmprojFile();
    if (!await isInstalled(_selected)) {
      throw StateError(
        'Download the language model before its component.',
      );
    }
    if (Platform.isAndroid) {
      final partial = File('${target.path}.part');
      await _ensureArtifactWithService(
        url: activeProjector.downloadUrl,
        target: target,
        partial: partial,
        expectedBytes: activeProjector.expectedBytes,
        label: 'Multimodal vision component',
        sha256Digest: activeProjector.sha256Digest,
      );
      return;
    }
    final partialBytes = await File('${target.path}.part').exists()
        ? await File('${target.path}.part').length()
        : 0;
    await _requireDesktopStorage(
      math.max(0, activeProjector.expectedBytes - partialBytes),
      reserve: 256 * 1024 * 1024,
      what: 'the multimodal component',
    );
    await _ensureArtifactDart(
      url: activeProjector.downloadUrl,
      target: target,
      expectedBytes: activeProjector.expectedBytes,
      label: 'Multimodal vision component',
      sha256Digest: activeProjector.sha256Digest,
    );
  }

  Future<Directory> _createModelDirectory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}models');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<void> _removePrefixStatesFor(String modelSha256) async {
    if (modelSha256.isEmpty) return;
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}prefix_states'
      '${Platform.pathSeparator}$modelSha256',
    );
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> _removeRetiredModelArtifacts() async {
    try {
      final modelDirectory =
          await (_modelDirectoryJob ??= _createModelDirectory());
      for (final fileName in FinnAccelerator._retiredModelFiles) {
        for (final suffix in FinnAccelerator.modelFileSuffixes) {
          final file = File(
            '${modelDirectory.path}${Platform.pathSeparator}$fileName$suffix',
          );
          if (await file.exists()) await file.delete();
        }
      }
      final support = await getApplicationSupportDirectory();
      for (final hash in FinnAccelerator._retiredPrefixHashes) {
        final directory = Directory(
          '${support.path}${Platform.pathSeparator}prefix_states'
          '${Platform.pathSeparator}$hash',
        );
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    } on FileSystemException catch (error) {
      debugPrint('Retired model cleanup failed: $error');
    }
  }

  Future<bool> _isVerifiedModelFile(FinnModelSpec model, File file) async {
    if (!await file.exists() || await file.length() != model.expectedBytes) {
      return false;
    }
    return _looksLikeGguf(file);
  }

  Future<bool> _looksLikeGguf(File file) async {
    if (!await file.exists() || await file.length() < 1024 * 1024) return false;
    final handle = await file.open();
    try {
      final magic = await handle.read(4);
      return magic.length == 4 &&
          magic[0] == 0x47 &&
          magic[1] == 0x47 &&
          magic[2] == 0x55 &&
          magic[3] == 0x46;
    } finally {
      await handle.close();
    }
  }

  int? _contentTotal(HttpClientResponse response, int existing) {
    final range = response.headers.value(HttpHeaders.contentRangeHeader);
    if (range != null) {
      final slash = range.lastIndexOf('/');
      if (slash >= 0) return int.tryParse(range.substring(slash + 1));
    }
    final length = response.contentLength;
    return length >= 0 ? length + existing : null;
  }
}
