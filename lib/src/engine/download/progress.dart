part of '../finn_accelerator.dart';

extension FinnAcceleratorProgress on FinnAccelerator {
  double? get installProgress {
    if (_installTotalBytes <= 0) return null;
    return ((_installCompletedBytes + _downloadReceivedBytes).clamp(
          0,
          _installTotalBytes,
        ) /
        _installTotalBytes);
  }

  int get installReceivedBytes =>
      _installCompletedBytes + _downloadReceivedBytes.round();

  int get installRemainingBytes =>
      math.max(0, _installTotalBytes - installReceivedBytes);

  double get downloadSpeedBps =>
      _phase == InferencePhase.downloading ? _downloadSpeedBps : 0;

  Duration? get downloadEta {
    if (_phase != InferencePhase.downloading ||
        _downloadSpeedBps <= 0 ||
        _downloadTotalBytes <= 0) {
      return null;
    }
    // The whole install when it is known: the progress shown beside the
    // estimate counts every artifact, so the estimate must too, not just the
    // file downloading now.
    final remaining = _installTotalBytes > 0
        ? installRemainingBytes
        : (_downloadRemainingBytes > 0
            ? _downloadRemainingBytes
            : _downloadTotalBytes - _downloadReceivedBytes);
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: (remaining / _downloadSpeedBps).floor());
  }

  String? get downloadSpeedLabel {
    final bps = downloadSpeedBps;
    if (bps <= 0) return null;
    if (bps >= 1024 * 1024) {
      return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(bps / 1024).toStringAsFixed(0)} KB/s';
  }

  String? get downloadEtaLabel {
    final eta = downloadEta;
    if (eta == null) return null;
    if (eta.inHours > 0) {
      return '${eta.inHours}h ${eta.inMinutes % 60}m left';
    }
    if (eta.inMinutes > 0) {
      return '${eta.inMinutes}m ${eta.inSeconds % 60}s left';
    }
    return '${eta.inSeconds}s left';
  }

  @visibleForTesting
  void reportDownloadProgressForTest(double progress, int totalBytes) {
    _setStatus(
      InferencePhase.downloading,
      'Downloading test',
      key: FinnStatusKey.downloadingModel,
      progress: progress,
      totalBytes: totalBytes,
    );
  }

  @visibleForTesting
  void resetDownloadStateForTest() {
    _setStatus(
      InferencePhase.idle,
      'Ready',
      key: FinnStatusKey.ready,
    );
  }

  void _trackDownloadSpeed(double progress, int? totalBytes) {
    if (totalBytes != null && totalBytes > 0) {
      _downloadTotalBytes = totalBytes;
    }
    final total = _downloadTotalBytes;
    if (total <= 0) return;
    final received = progress.clamp(0.0, 1.0) * total;
    final now = DateTime.now();
    final sampleAt = _downloadSampleAt;
    if (sampleAt == null || received < _downloadReceivedBytes) {
      _downloadSampleAt = now;
      _downloadReceivedBytes = received;
      return;
    }
    final elapsed = now.difference(sampleAt).inMicroseconds / 1e6;
    if (elapsed < 0.3) return;
    final deltaBytes = received - _downloadReceivedBytes;
    final instant = deltaBytes / elapsed;
    _downloadSpeedBps = _downloadSpeedBps <= 0
        ? instant
        : _downloadSpeedBps * 0.65 + instant * 0.35;
    _downloadSampleAt = now;
    _downloadReceivedBytes = received;
  }

  String _friendlyError(Object error) {
    debugPrint('FINN_RAW_ERROR $error');
    final text = error.toString();
    final lower = text.toLowerCase();
    if (text.contains('Unable to resolve host') ||
        lower.contains('resolve host') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('unknownhostexception') ||
        lower.contains('name or service not known')) {
      return 'Couldn\'t reach the model server. Check your internet or Wi-Fi and retry.';
    }
    if (text.contains('SocketException') || text.contains('HttpException')) {
      return 'Could not download the model. Check your connection.';
    }
    if (text.contains('LlamaDecodeException') ||
        text.contains('LlamaContextException') ||
        lower.contains('context full') ||
        lower.contains('decode failed') ||
        lower.contains('prefill decode failed') ||
        lower.contains('cannot shift')) {
      return 'This chat got too long for this device. Start a new chat or shorten your message.';
    }
    if (text.contains('LlamaModelLoadException') ||
        lower.contains('failed to load model') ||
        lower.contains('load_model')) {
      return 'The AI model couldn\'t load on this device. Try again, or remove and re-download the model.';
    }
    if (text.contains('LlamaLibraryException') ||
        lower.contains('failed to load dynamic library') ||
        lower.contains('dlopen') ||
        lower.contains('error relocating')) {
      // A native library that will not load is a packaging problem, not a
      // resource one. It has to be matched before the storage/memory checks
      // below: the sandbox path in these messages contains "storage", which
      // used to make this report "Not enough free storage" for what was
      // actually a missing symbol.
      return 'The local model library could not be loaded on this device. '
          'Reinstall the app to restore it.';
    }
    if (text.toLowerCase().contains('memory') || text.contains('alloc')) {
      return 'Not enough free memory. Close other apps and try again.';
    }
    if (lower.contains('no space left') ||
        lower.contains('disk full') ||
        lower.contains('quota exceeded') ||
        lower.contains('not enough storage')) {
      return 'Not enough free storage to download this model.';
    }
    if (!Platform.isAndroid && !Platform.isLinux && !Platform.isWindows) {
      return 'Local inference is available in the mobile build.';
    }
    return 'The local model could not start on this device.';
  }
}
