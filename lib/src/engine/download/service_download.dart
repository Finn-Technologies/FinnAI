part of '../finn_accelerator.dart';

extension FinnAcceleratorServiceDownload on FinnAccelerator {
  Future<File> _ensureArtifactWithService({
    required String url,
    required File target,
    required File partial,
    required int expectedBytes,
    required String label,
    required String sha256Digest,
  }) async {
    // A process can be killed after the final byte lands but before the
    // Android service is asked to promote the file. Verify that state locally
    // so a corrupt full-length partial is not resumed with an unsatisfiable
    // range request.
    if (await partial.exists()) {
      final partialLength = await partial.length();
      if (partialLength >= expectedBytes) {
        if (await promoteVerifiedModelPartial(
          partial: partial,
          target: target,
          expectedBytes: expectedBytes,
        )) {
          if (sha256Digest.isNotEmpty) {
            await _verifyPromotedArtifact(target, sha256Digest);
          }
          _completeInstallArtifact(expectedBytes);
          return target;
        }
        if (partialLength > expectedBytes && await partial.exists()) {
          await partial.delete();
        }
      }
    }
    _setStatus(
      InferencePhase.downloading,
      'Downloading $label',
      key: FinnStatusKey.downloadingArtifact,
      progress: 0,
      totalBytes: expectedBytes,
    );
    Future<void> requestStart() =>
        FinnAccelerator._backgroundDownloadChannel.invokeMethod<void>('start', {
          'url': url,
          'target': target.path,
          'expectedBytes': expectedBytes,
          'label': label,
        });
    await requestStart();
    var restarts = 0;
    DateTime? lastRestartAt;
    bool restarting = false;
    int? lastHeartbeat;
    DateTime? lastProgressAt;
    var sawProgress = false;
    while (true) {
      if (_cancelDownload) {
        await _cancelAndroidDownload(target.path);
        throw const HttpException('Download paused');
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final raw = await FinnAccelerator._backgroundDownloadChannel
          .invokeMapMethod<String, dynamic>('status');
      if (raw == null || raw['target'] != target.path) continue;
      final progress = (raw['progress'] as num?)?.toDouble() ?? 0;
      final speedBps = (raw['speedBps'] as num?)?.toDouble() ?? 0;
      final remainingBytes = (raw['remainingBytes'] as num?)?.toInt() ?? 0;
      final active = raw['active'] == true;
      final failed = raw['failed'] == true;
      final cancelled = raw['cancelled'] == true;
      final heartbeat = (raw['heartbeat'] as num?)?.toInt();
      if (progress > 0) sawProgress = true;
      if (!restarting) {
        _setStatus(
          InferencePhase.downloading,
          'Downloading $label',
          key: FinnStatusKey.downloadingArtifact,
          progress: progress,
          totalBytes: expectedBytes,
          speedBps: speedBps,
          remainingBytes: remainingBytes,
        );
      }
      if (raw['complete'] == true) break;

      final now = DateTime.now();
      // A dead, wedged, or failed service is restarted so the partial resumes
      // from its persisted per-range progress. Restarts are cheap, and only a
      // string of quick consecutive failures surfaces as an error — a single
      // transient blip (a read timeout, a dropped connection, a momentary DNS
      // miss) must never interrupt an in-flight download with an internet
      // error. The heartbeat advances only while a transfer is actually
      // writing bytes, so fresh progress also resets the failure counter.
      final stalled = sawProgress &&
          active &&
          lastProgressAt != null &&
          now.difference(lastProgressAt) > const Duration(seconds: 20);
      final needsRestart = !active || stalled || failed || cancelled;
      if (!needsRestart) {
        if (heartbeat != null && heartbeat != lastHeartbeat) {
          lastHeartbeat = heartbeat;
          lastProgressAt = now;
          restarts = 0;
        }
        continue;
      }
      if (restarting) {
        // A restart is already in flight. The service ignores a start while
        // its old thread is still alive (the Kotlin isRunning guard), so wait
        // for the thread to die — visible as active=false — before starting
        // the replacement.
        if (!active) {
          restarting = false;
          await requestStart();
        }
        continue;
      }
      if (lastRestartAt != null &&
          now.difference(lastRestartAt) < const Duration(seconds: 4)) {
        // Backoff: the replacement service may still be starting up.
        continue;
      }
      restarts++;
      if (restarts > 6) {
        throw HttpException(
          (raw['error'] as String?) ?? 'Model download kept stopping',
        );
      }
      lastRestartAt = now;
      restarting = true;
      lastHeartbeat = null;
      lastProgressAt = null;
      sawProgress = false;
      if (failed) {
        // The thread already finished (failure was recorded); a replacement
        // can start immediately.
        restarting = false;
        await requestStart();
        continue;
      }
      if (stalled) {
        // Ask the wedged service to stop; it observes the cancel on its next
        // read timeout and releases the liveness flag.
        await _cancelAndroidDownload(target.path);
      }
      if (!active) {
        restarting = false;
        await requestStart();
      }
    }
    _setStatus(
      InferencePhase.loading,
      'Verifying $label',
      key: FinnStatusKey.verifyingArtifact,
    );
    if (!await promoteVerifiedModelPartial(
      partial: partial,
      target: target,
      expectedBytes: expectedBytes,
    )) {
      throw const FormatException('Downloaded file failed verification');
    }
    if (sha256Digest.isNotEmpty) {
      await _verifyPromotedArtifact(target, sha256Digest);
    }
    _completeInstallArtifact(expectedBytes);
    return target;
  }
}
