part of '../finn_accelerator.dart';

extension FinnAcceleratorDartDownload on FinnAccelerator {
  Future<File> _ensureArtifactDart({
    required String url,
    required File target,
    required int expectedBytes,
    required String label,
    required String sha256Digest,
  }) async {
    final partial = File('${target.path}.part');
    var existing = await partial.exists() ? await partial.length() : 0;
    if (existing > expectedBytes) {
      await partial.delete();
      existing = 0;
    }
    if (existing == expectedBytes) {
      if (!await _looksLikeGguf(partial)) {
        await partial.delete();
        existing = 0;
      } else {
        if (await target.exists()) await target.delete();
        await partial.rename(target.path);
        if (sha256Digest.isNotEmpty) {
          await _verifyPromotedArtifact(target, sha256Digest);
        }
        _completeInstallArtifact(expectedBytes);
        return target;
      }
    }
    // Default certificate validation stays enabled (see _ensureDownloaded).
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..maxConnectionsPerHost = FinnAccelerator.dartDownloadSegments + 2;
    _downloadClient = client;
    try {
      _setStatus(
        InferencePhase.downloading,
        'Downloading $label',
        progress: 0,
        key: FinnStatusKey.downloadingArtifact,
      );

      // Probe for range support + total size.
      final probeRequest = await client.getUrl(Uri.parse(url));
      probeRequest.followRedirects = true;
      probeRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final probe = await probeRequest.close();
      final ranged = probe.statusCode == HttpStatus.partialContent;
      final total = ranged
          ? _contentTotal(probe, 0) ?? expectedBytes
          : probe.contentLength > 0
              ? probe.contentLength
              : expectedBytes;
      await probe.drain<void>();

      if (!ranged || total <= 0) {
        // Server doesn't support ranges: fall back to a single stream.
        await _downloadSingleStream(
          url: url,
          partial: partial,
          total: total,
          expectedBytes: expectedBytes,
          label: label,
        );
      } else {
        await _downloadSegmented(
          url: url,
          partial: partial,
          total: total,
          existing: existing,
          label: label,
        );
      }

      if (_cancelDownload) throw const HttpException('Download paused');
      _setStatus(
        InferencePhase.loading,
        'Verifying $label',
        key: FinnStatusKey.verifyingArtifact,
      );
      if (await partial.length() != expectedBytes) {
        await partial.delete();
        throw const FormatException('Downloaded file has an invalid size');
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      if (!await _looksLikeGguf(target)) {
        await target.delete();
        throw const FormatException('Downloaded file is not a valid GGUF file');
      }
      if (sha256Digest.isNotEmpty) {
        await _verifyPromotedArtifact(target, sha256Digest);
      }
      _completeInstallArtifact(expectedBytes);
      return target;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _downloadSingleStream({
    required String url,
    required File partial,
    required int total,
    required int expectedBytes,
    required String label,
  }) async {
    var attempt = 0;
    while (true) {
      HttpClient? attemptClient;
      try {
        attemptClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 20);
        _downloadClient = attemptClient;
        _activeDownloadClients.add(attemptClient);
        var resumeFrom = await partial.exists() ? await partial.length() : 0;
        if (resumeFrom > expectedBytes) {
          await partial.delete();
          resumeFrom = 0;
        }
        final request = await attemptClient.getUrl(Uri.parse(url));
        request.followRedirects = true;
        if (resumeFrom > 0) {
          request.headers.set(
            HttpHeaders.rangeHeader,
            'bytes=$resumeFrom-',
          );
        }
        final response =
            await request.close().timeout(const Duration(seconds: 30));
        if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
            resumeFrom > 0) {
          // The prefix already holds the whole file; let the caller's size
          // and digest checks below decide.
          return;
        }
        if (response.statusCode != HttpStatus.ok &&
            response.statusCode != HttpStatus.partialContent) {
          throw HttpException('Download failed (${response.statusCode})');
        }
        var received = resumeFrom;
        if (response.statusCode == HttpStatus.ok && resumeFrom > 0) {
          await partial.writeAsBytes(const [], flush: true);
          received = 0;
        }
        final effectiveTotal = _contentTotal(response, received) ?? total;
        final sink = partial.openWrite(
          mode: received > 0 ? FileMode.append : FileMode.write,
        );
        var lastNotification = DateTime.fromMillisecondsSinceEpoch(0);
        final updateInterval = Duration(
          milliseconds: switch (_deviceProfile?.processor) {
            ProcessorClass.flagship => 140,
            ProcessorClass.balanced => 190,
            _ => 260,
          },
        );
        var lastByteAt = DateTime.now();
        final watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
          if (DateTime.now().difference(lastByteAt) >
              FinnAccelerator._dartDownloadIdleTimeout) {
            // Abort the wedged read; the loop below errors out and the
            // attempt is retried from the persisted prefix.
            try {
              attemptClient?.close(force: true);
            } catch (_) {}
          }
        });
        try {
          await for (final bytes in response) {
            if (_cancelDownload) throw const HttpException('Download paused');
            sink.add(bytes);
            received += bytes.length;
            lastByteAt = DateTime.now();
            final now = DateTime.now();
            if (now.difference(lastNotification) > updateInterval) {
              lastNotification = now;
              _setStatus(
                InferencePhase.downloading,
                'Downloading $label',
                key: FinnStatusKey.downloadingArtifact,
                progress: (received / effectiveTotal).clamp(0, 1),
                totalBytes: effectiveTotal,
              );
            }
          }
        } finally {
          watchdog.cancel();
          await sink.flush();
          await sink.close();
        }
        // A completed loop means every expected byte arrived; a watchdog
        // firing in the same instant must not discard the finished stream.
        return;
      } catch (error) {
        if (_cancelDownload) rethrow;
        attempt++;
        if (attempt >= FinnAccelerator._dartDownloadMaxAttempts) rethrow;
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
      } finally {
        if (attemptClient != null) {
          _activeDownloadClients.remove(attemptClient);
          try {
            attemptClient.close(force: true);
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _downloadSegmented({
    required String url,
    required File partial,
    required int total,
    required int existing,
    required String label,
  }) async {
    final count = FinnAccelerator.dartDownloadSegments;
    final chunkSize = (total + count - 1) ~/ count;
    final startOffsets = List<int>.generate(count, (i) => i * chunkSize);
    final endOffsets = List<int>.generate(
      count,
      (i) => math.min((i + 1) * chunkSize - 1, total - 1),
    );
    final rangeFiles = List<File>.generate(
      count,
      (i) => File('${partial.path}.r$i'),
    );
    // Adopt a legacy contiguous `.part` prefix (written by older builds
    // straight into [partial]) into per-range files, so progress from before
    // the upgrade resumes instead of re-downloading.
    await _seedRangeFilesFromPrefix(
      partial: partial,
      rangeFiles: rangeFiles,
      startOffsets: startOffsets,
      endOffsets: endOffsets,
      existing: existing,
    );
    final receivedByRange = <int>[
      for (var i = 0; i < count; i++)
        await rangeFiles[i].exists() ? await rangeFiles[i].length() : 0,
    ];
    // Drop over-long range files (e.g. from a server that ignored Range and
    // returned the whole file); they resume cleanly from zero below.
    for (var i = 0; i < count; i++) {
      final rangeLen = endOffsets[i] - startOffsets[i] + 1;
      if (receivedByRange[i] > rangeLen) {
        try {
          await rangeFiles[i].delete();
        } catch (_) {}
        receivedByRange[i] = 0;
      }
    }
    var lastNotification = DateTime.fromMillisecondsSinceEpoch(0);
    var lastLoggedBucket = -1;
    final updateInterval = Duration(
      milliseconds: switch (_deviceProfile?.processor) {
        ProcessorClass.flagship => 140,
        ProcessorClass.balanced => 190,
        _ => 260,
      },
    );
    void reportProgress() {
      final received = receivedByRange.fold<int>(0, (a, b) => a + b);
      final fraction = (received / total).clamp(0.0, 1.0).toDouble();
      final bucket = (fraction * 20).floor();
      if (bucket != lastLoggedBucket) {
        lastLoggedBucket = bucket;
        debugPrint(
          'FINN_SEGMENTED_PROGRESS: ${(fraction * 100).toStringAsFixed(0)}% '
          '($received/$total bytes)',
        );
      }
      _setStatus(
        InferencePhase.downloading,
        'Downloading $label',
        key: FinnStatusKey.downloadingArtifact,
        progress: fraction,
        totalBytes: total,
      );
    }

    Future<void> fetchRange(int index) async {
      final rangeLen = endOffsets[index] - startOffsets[index] + 1;
      var attempt = 0;
      while (receivedByRange[index] < rangeLen) {
        HttpClient? rangeClient;
        try {
          rangeClient = HttpClient()
            ..connectionTimeout = const Duration(seconds: 20);
          _activeDownloadClients.add(rangeClient);
          final from = startOffsets[index] + receivedByRange[index];
          final request = await rangeClient.getUrl(Uri.parse(url));
          request.followRedirects = true;
          request.headers.set(
            HttpHeaders.rangeHeader,
            'bytes=$from-${endOffsets[index]}',
          );
          final response =
              await request.close().timeout(const Duration(seconds: 30));
          final wantLen = endOffsets[index] - from + 1;
          if (response.statusCode == HttpStatus.ok &&
              from == startOffsets[index] &&
              (response.contentLength < 0 ||
                  response.contentLength == rangeLen)) {
            // Server ignored Range but returned the range from its start.
          } else if (response.statusCode != HttpStatus.partialContent ||
              (response.contentLength >= 0 &&
                  response.contentLength != wantLen)) {
            throw HttpException('Range $index failed (${response.statusCode})');
          }
          var lastByteAt = DateTime.now();
          final watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
            if (DateTime.now().difference(lastByteAt) >
                FinnAccelerator._dartDownloadIdleTimeout) {
              // Abort the wedged read; the loop below errors out and the
              // range is retried from its persisted offset.
              try {
                rangeClient?.close(force: true);
              } catch (_) {}
            }
          });
          try {
            final sink = rangeFiles[index].openWrite(mode: FileMode.append);
            try {
              await for (final bytes in response) {
                if (_cancelDownload) {
                  throw const HttpException('Download paused');
                }
                sink.add(bytes);
                receivedByRange[index] += bytes.length;
                lastByteAt = DateTime.now();
                final now = DateTime.now();
                if (now.difference(lastNotification) > updateInterval) {
                  lastNotification = now;
                  reportProgress();
                }
              }
            } finally {
              await sink.flush();
              await sink.close();
            }
          } finally {
            watchdog.cancel();
          }
          // A short read without an error is a stall, not success: retry from
          // the persisted offset instead of accepting a gap.
          if (receivedByRange[index] < rangeLen) {
            throw HttpException(
              'Range $index truncated '
              '(${receivedByRange[index]}/$rangeLen)',
            );
          }
          return;
        } catch (error) {
          if (_cancelDownload) rethrow;
          attempt++;
          if (attempt >= FinnAccelerator._dartDownloadMaxAttempts) rethrow;
          await Future<void>.delayed(Duration(seconds: 2 * attempt));
        } finally {
          if (rangeClient != null) {
            _activeDownloadClients.remove(rangeClient);
            try {
              rangeClient.close(force: true);
            } catch (_) {}
          }
        }
      }
    }

    await Future.wait([for (var i = 0; i < count; i++) fetchRange(i)]);
    reportProgress();
    // Concatenate the complete ranges into the partial in order.
    final out = partial.openWrite(mode: FileMode.write);
    try {
      for (var i = 0; i < count; i++) {
        final rangeLen = endOffsets[i] - startOffsets[i] + 1;
        final len = await rangeFiles[i].length();
        if (len != rangeLen) {
          throw HttpException(
            'Range $i incomplete ($len/$rangeLen)',
          );
        }
        await out.addStream(rangeFiles[i].openRead());
      }
    } finally {
      await out.flush();
      await out.close();
    }
    for (var i = 0; i < count; i++) {
      try {
        await rangeFiles[i].delete();
      } catch (_) {}
    }
  }

  Future<void> _seedRangeFilesFromPrefix({
    required File partial,
    required List<File> rangeFiles,
    required List<int> startOffsets,
    required List<int> endOffsets,
    required int existing,
  }) async {
    if (existing <= 0 || !await partial.exists()) return;
    final prefix = math.min(existing, await partial.length());
    if (prefix <= 0) return;
    final raf = await partial.open(mode: FileMode.read);
    try {
      for (var i = 0; i < rangeFiles.length; i++) {
        final start = startOffsets[i];
        if (start >= prefix) break;
        if (await rangeFiles[i].exists() && await rangeFiles[i].length() > 0) {
          continue;
        }
        final end = math.min(endOffsets[i], prefix - 1);
        final need = end - start + 1;
        if (need <= 0) continue;
        await raf.setPosition(start);
        final sink = rangeFiles[i].openWrite(mode: FileMode.write);
        var left = need;
        try {
          while (left > 0) {
            final chunk = await raf.read(math.min(left, 64 * 1024));
            if (chunk.isEmpty) break;
            sink.add(chunk);
            left -= chunk.length;
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
      }
    } finally {
      await raf.close();
    }
    // The prefix now lives in the range files; drop the legacy file so a
    // resumed download never pays for the same bytes twice. Small disks
    // (e.g. a 6 GB emulator data partition holding the 696 MB model plus an
    // 854 MB component) cannot afford the duplicated footprint, and every
    // later resume re-seeds from — and re-deletes — nothing.
    try {
      await partial.delete();
    } catch (_) {}
  }
}
