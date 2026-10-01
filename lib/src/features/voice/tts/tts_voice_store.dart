import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/voice/model_fetch.dart';
import 'package:finn_ai/src/features/voice/stt/speech_backend.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';

/// Where an installed voice's files are.
@immutable
class TtsVoicePaths {
  const TtsVoicePaths({
    required this.model,
    required this.tokens,
    required this.dataDir,
  });

  final String model;
  final String tokens;
  final String dataDir;
}

/// Downloads, unpacks and removes text-to-speech voices.
///
/// A voice is one `.tar.bz2`. It is fetched and verified like any other pinned
/// artifact, then unpacked on a background isolate into a temporary folder
/// that is renamed into place, so a half-unpacked voice is never mistaken for
/// an installed one. `espeak-ng-data` is identical across voices, so it is
/// unpacked once and shared.
class TtsVoiceStore {
  TtsVoiceStore({
    Directory? root,
    HttpClient Function()? clientFactory,
    Future<void> Function(String archive, String voiceDir, String sharedDir)?
        extractor,
    String Function(TtsVoice voice)? urlFor,
    bool pruneAfterInstall = true,
  })  : _rootOverride = root,
        _pruneAfterInstall = pruneAfterInstall,
        _urlFor = urlFor ?? ((voice) => voice.url),
        _fetcher = VerifiedFetcher(clientFactory: clientFactory),
        _extractor = extractor ?? extractTtsArchive;

  static final instance = TtsVoiceStore();

  final Directory? _rootOverride;
  final String Function(TtsVoice voice) _urlFor;
  final bool _pruneAfterInstall;
  final VerifiedFetcher _fetcher;
  final Future<void> Function(String archive, String voiceDir, String sharedDir)
      _extractor;
  final Map<String, Future<void>> _installs = {};

  /// Progress of the install in flight, for a download card.
  final ValueNotifier<SpeechModelStatus> status =
      ValueNotifier(SpeechModelStatus.missing);

  Future<Directory> _root() async {
    final override = _rootOverride;
    if (override != null) return override;
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/tts');
  }

  Future<Directory> _voiceDir(TtsVoice voice) async =>
      Directory('${(await _root()).path}/voices/${voice.id}');

  Future<Directory> _sharedData() async =>
      Directory('${(await _root()).path}/espeak-ng-data');

  Future<bool> isInstalled(TtsVoice voice) async => await paths(voice) != null;

  Future<List<TtsVoice>> installedVoices() async => [
        for (final voice in ttsVoices)
          if (await isInstalled(voice)) voice,
      ];

  Future<TtsVoicePaths?> paths(TtsVoice voice) async {
    final dir = await _voiceDir(voice);
    final shared = await _sharedData();
    if (!await dir.exists() || !await shared.exists()) return null;
    final tokens = File('${dir.path}/tokens.txt');
    if (!await tokens.exists()) return null;
    File? model;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.onnx')) model = entity;
    }
    if (model == null) return null;
    return TtsVoicePaths(
      model: model.path,
      tokens: tokens.path,
      dataDir: shared.path,
    );
  }

  /// Installs [voice]. Joins an install already in flight for it.
  Future<void> install(
    TtsVoice voice, {
    void Function(int received)? onProgress,
  }) =>
      _installs[voice.id] ??= _install(voice, onProgress).whenComplete(() {
        _installs.remove(voice.id);
      });

  Future<void> _install(
    TtsVoice voice,
    void Function(int received)? onProgress,
  ) async {
    if (await isInstalled(voice)) return;
    _fetcher.reset();
    final root = await _root();
    await Directory('${root.path}/archives').create(recursive: true);
    final archive = File('${root.path}/archives/${voice.id}.tar.bz2');
    await _fetcher.fetch(
      name: voice.id,
      url: _urlFor(voice),
      bytes: voice.bytes,
      sha256Digest: voice.sha256Digest,
      target: archive,
      onProgress: onProgress,
    );
    final dir = await _voiceDir(voice);
    final shared = await _sharedData();
    final watch = Stopwatch()..start();
    await _extractor(archive.path, dir.path, shared.path);
    debugPrint('FINN_TTS unpack_ms=${watch.elapsedMilliseconds} ${voice.id}');
    // The archive has done its job; keeping it would double the disk cost.
    if (await archive.exists()) await archive.delete();
    if (await paths(voice) == null) {
      throw StateError('${voice.id} unpacked without a model');
    }
    if (_pruneAfterInstall) await pruneRetired();
  }

  /// Deletes voices that are on disk but no longer in the catalog (one that was
  /// replaced, for a licence or a better one), so they do not sit there for
  /// ever.
  Future<void> pruneRetired({
    Set<String>? keep,
  }) async {
    final known = keep ?? {for (final v in ttsVoices) v.id};
    final voices = Directory('${(await _root()).path}/voices');
    if (!await voices.exists()) return;
    await for (final entity in voices.list()) {
      final name = entity.path.split('/').last;
      if (entity is Directory && !known.contains(name)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  void cancelDownload() => _fetcher.cancel();

  Future<File> _failedMarker() async => File('${(await _root()).path}.failed');

  /// Whether an install was tried and did not finish; see the speech model's
  /// equivalent for why an upgrading user is not asked again every launch.
  Future<bool> installFailedBefore() async => (await _failedMarker()).exists();

  Future<void> markInstallFailed() async {
    try {
      final marker = await _failedMarker();
      await marker.parent.create(recursive: true);
      await marker.writeAsString('1');
    } catch (_) {}
  }

  Future<void> clearInstallFailed() async {
    final marker = await _failedMarker();
    if (await marker.exists()) await marker.delete();
  }

  Future<void> deleteAll() async {
    cancelDownload();
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
    await clearInstallFailed();
  }
}

/// Unpacks a voice archive into [voiceDir], and its `espeak-ng-data` into
/// [sharedDir] unless that already exists. Runs on its own isolate.
Future<void> extractTtsArchive(
  String archivePath,
  String voiceDir,
  String sharedDir,
) =>
    Isolate.run(() => _extractSync(archivePath, voiceDir, sharedDir));

void _extractSync(String archivePath, String voiceDir, String sharedDir) {
  final bytes = File(archivePath).readAsBytesSync();
  final tar = TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes));
  final tmpVoice = Directory('$voiceDir.tmp');
  final tmpShared = Directory('$sharedDir.tmp');
  for (final d in [tmpVoice, tmpShared]) {
    if (d.existsSync()) d.deleteSync(recursive: true);
  }
  final needShared = !Directory(sharedDir).existsSync();
  for (final entry in tar) {
    if (!entry.isFile) continue;
    // `<archive-name>/<rest>`: drop the first component.
    final parts = entry.name.split('/')..removeWhere((p) => p.isEmpty);
    if (parts.length < 2) continue;
    final rest = parts.sublist(1);
    final inData = rest.first == 'espeak-ng-data';
    if (inData && !needShared) continue;
    final base = inData ? tmpShared.path : tmpVoice.path;
    final relative = inData ? rest.sublist(1) : rest;
    // Only the model, its tokens and the shared data are used.
    if (!inData &&
        !(relative.length == 1 &&
            (relative.first.endsWith('.onnx') ||
                relative.first == 'tokens.txt'))) {
      continue;
    }
    final out = File('$base/${relative.join('/')}')
      ..parent.createSync(recursive: true);
    out.writeAsBytesSync(entry.content as List<int>);
  }
  if (needShared && tmpShared.existsSync()) {
    tmpShared.renameSync(sharedDir);
  }
  final target = Directory(voiceDir);
  if (target.existsSync()) target.deleteSync(recursive: true);
  target.parent.createSync(recursive: true);
  tmpVoice.renameSync(voiceDir);
}
