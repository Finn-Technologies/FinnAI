part of '../finn_accelerator.dart';

extension FinnAcceleratorArtifacts on FinnAccelerator {
  /// Refuses a transfer that cannot fit before it starts, on desktop Linux.
  ///
  /// Android's download service does this on its side. Elsewhere the Dart
  /// downloader would write until the disk is full and report an opaque write
  /// error, leaving a partial file behind that blocks the next attempt too.
  /// A host that cannot report free space is let through.
  Future<void> _requireDesktopStorage(
    int remainingBytes, {
    required int reserve,
    required String what,
  }) async {
    final profile = await DeviceProfiler.read();
    final available = profile.availableStorageBytes;
    if (!profile.desktop || available == null) return;
    if (available < remainingBytes + reserve) {
      throw FileSystemException(
        'Not enough storage for $what and a safety reserve: '
        '${_formatMegabytes(remainingBytes + reserve)} needed, '
        '${_formatMegabytes(available)} free.',
      );
    }
  }

  static String _formatMegabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).ceil()} MB';

  Future<File> _ensureDownloaded(FinnModelSpec model) async {
    final target = await _modelFile(model);
    if (_verifiedModels.contains(model.tier) ||
        await _isVerifiedModelFile(model, target)) {
      _verifiedModels.add(model.tier);
      return target;
    }

    final partial = File('${target.path}.part');
    var existing = await partial.exists() ? await partial.length() : 0;
    if (existing > model.expectedBytes) {
      await partial.delete();
      existing = 0;
    }
    if (existing == model.expectedBytes) {
      _setStatus(
        InferencePhase.loading,
        'Checking the download',
        key: FinnStatusKey.checkingDownload,
      );
      final promoted = await promoteVerifiedModelPartial(
        partial: partial,
        target: target,
        expectedBytes: model.expectedBytes,
      );
      if (promoted) {
        _verifiedModels.add(model.tier);
        _completeInstallArtifact(model.expectedBytes);
        return target;
      }
      existing = 0;
    }
    if (Platform.isAndroid) {
      final freshProfile = await DeviceProfiler.read();
      final available = freshProfile.availableStorageBytes;
      final remaining = math.max(0, model.expectedBytes - existing);
      final reserve = math.max(256 * 1024 * 1024, model.expectedBytes ~/ 20);
      if (available != null && available < remaining + reserve) {
        throw const FileSystemException(
          'Not enough storage for the model and safety reserve.',
        );
      }
      return _ensureArtifactWithService(
        url: model.downloadUrl,
        target: target,
        partial: partial,
        expectedBytes: model.expectedBytes,
        label: 'FinnAI model',
        sha256Digest: model.sha256Digest,
      );
    }
    await _requireDesktopStorage(
      math.max(0, model.expectedBytes - existing),
      reserve: math.max(256 * 1024 * 1024, model.expectedBytes ~/ 20),
      what: 'the model',
    );
    // Default certificate validation stays enabled: the production model is
    // additionally pinned via its SHA-256 digest after the transfer, but TLS
    // must not be weakened for every other request on this client.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    _downloadClient = client;
    try {
      _setStatus(
        InferencePhase.downloading,
        'Downloading the AI model',
        key: FinnStatusKey.downloadingModel,
        progress: 0,
        totalBytes: model.expectedBytes,
      );
      final modelUri = Uri.parse(model.downloadUrl);
      final request = await client.getUrl(modelUri);
      request.followRedirects = true;
      if (existing > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
      }
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException(
          'Model download failed (${response.statusCode})',
          uri: modelUri,
        );
      }
      if (response.statusCode == HttpStatus.ok && existing > 0) {
        await partial.writeAsBytes(const [], flush: true);
        existing = 0;
      }
      final total = _contentTotal(response, existing) ?? model.expectedBytes;
      final sink = partial.openWrite(
        mode: existing > 0 ? FileMode.append : FileMode.write,
      );
      var received = existing;
      var lastNotification = DateTime.fromMillisecondsSinceEpoch(0);
      final updateInterval = Duration(
        milliseconds: switch (_deviceProfile?.processor) {
          ProcessorClass.flagship => 140,
          ProcessorClass.balanced => 190,
          _ => 260,
        },
      );
      try {
        await for (final bytes in response) {
          if (_cancelDownload) throw const HttpException('Download paused');
          sink.add(bytes);
          received += bytes.length;
          final now = DateTime.now();
          if (now.difference(lastNotification) > updateInterval) {
            lastNotification = now;
            _setStatus(
              InferencePhase.downloading,
              'Downloading the AI model',
              key: FinnStatusKey.downloadingModel,
              progress: (received / total).clamp(0, 1),
              totalBytes: total,
            );
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (_cancelDownload) throw const HttpException('Download paused');
      _setStatus(
        InferencePhase.loading,
        'Checking the download',
        key: FinnStatusKey.checkingDownload,
      );
      if (await partial.length() != model.expectedBytes) {
        await partial.delete();
        throw const FormatException('Downloaded model has an invalid size');
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      if (!await _looksLikeGguf(target)) {
        await target.delete();
        throw const FormatException(
          'Downloaded model is not a valid GGUF file',
        );
      }
      await _verifyPromotedArtifact(target, model.sha256Digest);
      _verifiedModels.add(model.tier);
      _completeInstallArtifact(model.expectedBytes);
      return target;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _sha256File(File file) async {
    try {
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString();
    } on StateError {
      throw const FormatException('Downloaded file is empty or unreadable');
    }
  }

  Future<void> _verifyArtifactDigest(File file, String expectedDigest) async {
    if (expectedDigest.isEmpty) return;
    final actual = await _sha256File(file);
    if (actual.toLowerCase() != expectedDigest.toLowerCase()) {
      throw const FormatException(
        'Downloaded artifact failed SHA-256 verification',
      );
    }
  }

  Future<void> _verifyPromotedArtifact(
    File target,
    String expectedDigest,
  ) async {
    if (expectedDigest.isEmpty) return;
    try {
      await _verifyArtifactDigest(target, expectedDigest);
    } catch (_) {
      try {
        if (await target.exists()) await target.delete();
      } on FileSystemException {
        // Best effort: still surface the verification failure to the caller.
      }
      rethrow;
    }
  }
}
