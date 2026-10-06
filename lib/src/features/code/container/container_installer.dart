import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/code/container/container_image.dart';

enum ContainerInstallState { unknown, missing, downloading, installed, failed }

/// Why an install failed, for the settings page to name.
enum ContainerInstallError { network, verification, storage }

/// Downloads, verifies and removes the container's Linux image.
///
/// Each artifact is written to `<name>.part`, hashed while it streams, and
/// renamed only when both its size and its SHA-256 match. A stopped download
/// starts over: the files are small, and a resume would be a second code path
/// to get wrong.
class ContainerInstaller extends ChangeNotifier {
  ContainerInstaller({
    this.directoryProvider,
    http.Client Function()? clientFactory,
    List<ContainerArtifact>? artifacts,
  })  : _clientFactory = clientFactory ?? http.Client.new,
        artifacts = artifacts ?? ContainerImage.artifacts;

  static final instance = ContainerInstaller();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;
  final http.Client Function() _clientFactory;
  final List<ContainerArtifact> artifacts;

  ContainerInstallState _state = ContainerInstallState.unknown;
  ContainerInstallError? _error;
  int _received = 0;
  http.Client? _client;

  ContainerInstallState get state => _state;
  ContainerInstallError? get error => _error;
  bool get installed => _state == ContainerInstallState.installed;

  int get totalBytes => artifacts.fold(0, (sum, a) => sum + a.bytes);

  /// Between 0 and 1 while downloading.
  double get progress =>
      totalBytes == 0 ? 0 : (_received / totalBytes).clamp(0.0, 1.0);

  Future<Directory> directory() async {
    final base = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return Directory('${base.path}/code/container');
  }

  /// Checks what is on disk. Sizes only: the digest was checked when the file
  /// was written, and hashing 10 MB on every launch buys nothing.
  Future<void> refresh() async {
    if (_state == ContainerInstallState.downloading) return;
    if (artifacts.isEmpty) return _set(ContainerInstallState.missing);
    final dir = await directory();
    var complete = true;
    for (final artifact in artifacts) {
      final file = File('${dir.path}/${artifact.fileName}');
      if (!await file.exists() || await file.length() != artifact.bytes) {
        complete = false;
        break;
      }
    }
    _set(complete
        ? ContainerInstallState.installed
        : ContainerInstallState.missing);
  }

  /// Downloads whatever is missing. Safe to call twice; the second call waits
  /// for the first.
  Future<bool> install() async {
    if (_state == ContainerInstallState.downloading) {
      while (_state == ContainerInstallState.downloading) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return installed;
    }
    _error = null;
    _received = 0;
    _set(ContainerInstallState.downloading);
    final client = _client = _clientFactory();
    try {
      final dir = await directory();
      await dir.create(recursive: true);
      for (final artifact in artifacts) {
        final target = File('${dir.path}/${artifact.fileName}');
        if (await target.exists() && await target.length() == artifact.bytes) {
          _received += artifact.bytes;
          notifyListeners();
          continue;
        }
        await _download(client, artifact, target);
      }
      _set(ContainerInstallState.installed);
      return true;
    } on _VerificationFailed {
      _error = ContainerInstallError.verification;
    } on FileSystemException {
      _error = ContainerInstallError.storage;
    } catch (_) {
      // Socket, TLS, HTTP status, or a cancel: all "try again".
      _error = ContainerInstallError.network;
    } finally {
      _client = null;
      client.close();
    }
    _set(ContainerInstallState.failed);
    return false;
  }

  Future<void> _download(
    http.Client client,
    ContainerArtifact artifact,
    File target,
  ) async {
    final part = File('${target.path}.part');
    final response =
        await client.send(http.Request('GET', Uri.parse(artifact.url)));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final sink = part.openWrite();
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    var length = 0;
    try {
      await for (final chunk in response.stream) {
        length += chunk.length;
        if (length > artifact.bytes) throw const _VerificationFailed();
        hasher.add(chunk);
        sink.add(chunk);
        _received += chunk.length;
        notifyListeners();
      }
    } finally {
      await sink.close();
    }
    hasher.close();
    if (length != artifact.bytes ||
        digestSink.value.toString() != artifact.sha256) {
      await part.delete();
      throw const _VerificationFailed();
    }
    await part.rename(target.path);
  }

  /// Stops a download in progress.
  void cancel() => _client?.close();

  /// Removes the image. The emulator in the app bundle stays.
  Future<List<String>> deleteStorage() async {
    cancel();
    try {
      final dir = await directory();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (error) {
      return ['FinnAI Code container ($error)'];
    } finally {
      _set(ContainerInstallState.missing);
    }
    return const [];
  }

  void _set(ContainerInstallState state) {
    _state = state;
    notifyListeners();
  }
}

class _VerificationFailed implements Exception {
  const _VerificationFailed();
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
