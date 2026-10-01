import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/voice/model_fetch.dart';
import 'package:finn_ai/src/features/voice/stt/speech_backend.dart';

@immutable
class SttModelFile {
  const SttModelFile({
    required this.name,
    required this.url,
    required this.bytes,
    required this.sha256Digest,
  });

  final String name;
  final String url;
  final int bytes;
  final String sha256Digest;
}

/// The speech model: Whisper base (multilingual, int8) plus the Silero voice
/// activity detector. Whisper is pinned to a Hugging Face revision and every
/// file to its SHA-256, as the language model is.
///
/// Sizes and digests come from the Hugging Face LFS metadata
/// (`/api/models/csukuangfj/sherpa-onnx-whisper-base/tree/<revision>`); the
/// tokens file is not LFS, so its digest was computed from the download. The
/// VAD is a GitHub release asset, pinned by digest alone.
const _whisperBase =
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/'
    'bb53ee204431c90d314c1cc08d28d23e5b7927cc';

const sttModelFiles = <SttModelFile>[
  SttModelFile(
    name: 'base-encoder.int8.onnx',
    url: '$_whisperBase/base-encoder.int8.onnx',
    bytes: 29120534,
    sha256Digest:
        '0b8fb1304b6109976038efff5ace81720e00386f3ff6b54ee8c75291ca0a1e11',
  ),
  SttModelFile(
    name: 'base-decoder.int8.onnx',
    url: '$_whisperBase/base-decoder.int8.onnx',
    bytes: 130672026,
    sha256Digest:
        '9759d217388a01b3a4c7c15533201067b48ae819c4daafc8624e64b9409dc02d',
  ),
  SttModelFile(
    name: 'base-tokens.txt',
    url: '$_whisperBase/base-tokens.txt',
    bytes: 816730,
    sha256Digest:
        'b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126',
  ),
  SttModelFile(
    name: 'silero_vad.onnx',
    url:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx',
    bytes: 643854,
    sha256Digest:
        '9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6',
  ),
];

/// "161 MB" — what the download card tells the user to expect.
String get sttModelSizeLabel {
  final bytes = sttModelFiles.fold<int>(0, (sum, file) => sum + file.bytes);
  return '${(bytes / 1000 / 1000).round()} MB';
}

/// Where the installed files are, ready to hand to the recogniser.
@immutable
class SttModelPaths {
  const SttModelPaths({
    required this.encoder,
    required this.decoder,
    required this.tokens,
    required this.vad,
  });

  final String encoder;
  final String decoder;
  final String tokens;
  final String vad;
}

/// Downloads, verifies and removes the speech model.
///
/// Self-contained on purpose: the language model's pipeline lives inside the
/// engine and is about one artifact; this is a second, optional, small one.
/// A file only appears under its final name after its size and SHA-256 match,
/// so "the file exists with the right size" is enough to call it installed.
class SttModelStore {
  SttModelStore({
    Directory? root,
    List<SttModelFile> files = sttModelFiles,
    HttpClient Function()? clientFactory,
  })  : _rootOverride = root,
        _files = files,
        _fetcher = VerifiedFetcher(clientFactory: clientFactory);

  static final instance = SttModelStore();

  final Directory? _rootOverride;
  final List<SttModelFile> _files;
  final VerifiedFetcher _fetcher;

  final ValueNotifier<SpeechModelStatus> status =
      ValueNotifier(SpeechModelStatus.missing);

  Future<void>? _download;

  int get totalBytes => _files.fold(0, (sum, file) => sum + file.bytes);

  Future<Directory> _root() async {
    final override = _rootOverride;
    if (override != null) return override;
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/stt/whisper-base-int8');
  }

  Future<bool> isInstalled() async {
    final root = await _root();
    for (final file in _files) {
      final f = File('${root.path}/${file.name}');
      if (!await f.exists() || await f.length() != file.bytes) return false;
    }
    return true;
  }

  /// Syncs [status] with what is on disk. Call before showing it.
  Future<void> refresh() async {
    if (_download != null) return;
    status.value = await isInstalled()
        ? SpeechModelStatus.ready
        : SpeechModelStatus.missing;
  }

  Future<SttModelPaths?> paths() async {
    if (!await isInstalled()) return null;
    final root = (await _root()).path;
    String at(String name) => '$root/$name';
    return SttModelPaths(
      encoder: at('base-encoder.int8.onnx'),
      decoder: at('base-decoder.int8.onnx'),
      tokens: at('base-tokens.txt'),
      vad: at('silero_vad.onnx'),
    );
  }

  /// Downloads whatever is missing. Joins a download already in flight.
  Future<void> download() => _download ??= _run().whenComplete(() {
        _download = null;
      });

  void cancelDownload() => _fetcher.cancel();

  Future<void> _run() async {
    _fetcher.reset();
    final root = await _root();
    await root.create(recursive: true);
    final total = totalBytes;
    var done = 0;
    void publish(int received) {
      status.value = SpeechModelStatus(
        SpeechModelPhase.downloading,
        progress: (received / total).clamp(0.0, 1.0),
        totalBytes: total,
      );
    }

    publish(0);
    try {
      for (final file in _files) {
        final target = File('${root.path}/${file.name}');
        if (await target.exists() && await target.length() == file.bytes) {
          done += file.bytes;
          publish(done);
          continue;
        }
        await _fetcher.fetch(
          name: file.name,
          url: file.url,
          bytes: file.bytes,
          sha256Digest: file.sha256Digest,
          target: target,
          onProgress: (n) => publish(done + n),
        );
        done += file.bytes;
        publish(done);
      }
      status.value = SpeechModelStatus.ready;
      final marker = await _failedMarker();
      if (await marker.exists()) await marker.delete();
    } catch (_) {
      status.value = const SpeechModelStatus(SpeechModelPhase.failed);
      rethrow;
    }
  }

  Future<File> _failedMarker() async => File('${(await _root()).path}.failed');

  /// Whether an install was tried and did not finish. Lets an upgrading user
  /// skip the install screen on later launches instead of waiting out a
  /// network timeout every time they open the app offline.
  Future<bool> installFailedBefore() async => (await _failedMarker()).exists();

  Future<void> markInstallFailed() async {
    try {
      final marker = await _failedMarker();
      await marker.parent.create(recursive: true);
      await marker.writeAsString('1');
    } catch (_) {}
  }

  /// Removes the speech model and any half-finished download.
  Future<void> delete() async {
    cancelDownload();
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
    final marker = await _failedMarker();
    if (await marker.exists()) await marker.delete();
    status.value = SpeechModelStatus.missing;
  }
}
