import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/voice/model_fetch.dart';
import 'package:finn_ai/src/features/voice/stt/speech_backend.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';

/// Where an installed voice's files are.
@immutable
class TtsVoicePaths {
  const TtsVoicePaths({required this.directory});

  /// The voice's folder; the models are in its `onnx/` folder, the styles in
  /// `voice_styles/`.
  final String directory;

  String get modelDirectory => '$directory/${TtsVoice.modelFolder}';
  String get config => '$modelDirectory/tts.json';
  String get indexer => '$modelDirectory/unicode_indexer.json';
  String style(String name) => '$directory/voice_styles/$name.json';
}

/// Downloads and removes text-to-speech voices.
///
/// A voice is a handful of files. Each is fetched and verified like any other
/// pinned artifact (resumable, size-checked, SHA-256), and a `.complete` marker
/// is written only after the last one, so a half-downloaded voice is never
/// mistaken for an installed one.
class TtsVoiceStore {
  TtsVoiceStore({
    Directory? root,
    HttpClient Function()? clientFactory,
    String Function(TtsVoice voice, TtsFile file)? urlFor,
    bool pruneAfterInstall = true,
  })  : _rootOverride = root,
        _pruneAfterInstall = pruneAfterInstall,
        _urlFor = urlFor ?? ((voice, file) => file.url(voice.repository)),
        _fetcher = VerifiedFetcher(clientFactory: clientFactory);

  static final instance = TtsVoiceStore();

  final Directory? _rootOverride;
  final String Function(TtsVoice voice, TtsFile file) _urlFor;
  final bool _pruneAfterInstall;
  final VerifiedFetcher _fetcher;
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

  Future<bool> isInstalled(TtsVoice voice) async => await paths(voice) != null;

  Future<List<TtsVoice>> installedVoices() async => [
        for (final voice in ttsVoices)
          if (await isInstalled(voice)) voice,
      ];

  Future<TtsVoicePaths?> paths(TtsVoice voice) async {
    final dir = await _voiceDir(voice);
    if (!await File('${dir.path}/.complete').exists()) return null;
    for (final file in voice.files) {
      final stored = File('${dir.path}/${file.path}');
      if (!await stored.exists() || await stored.length() != file.bytes) {
        return null;
      }
    }
    return TtsVoicePaths(directory: dir.path);
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
    final dir = await _voiceDir(voice);
    await dir.create(recursive: true);
    final marker = File('${dir.path}/.complete');
    if (await marker.exists()) await marker.delete();

    var done = 0;
    final watch = Stopwatch()..start();
    for (final file in voice.files) {
      final target = File('${dir.path}/${file.path}');
      await target.parent.create(recursive: true);
      if (await target.exists() && await target.length() == file.bytes) {
        done += file.bytes;
        onProgress?.call(done);
        continue;
      }
      final before = done;
      await _fetcher.fetch(
        name: file.path,
        url: _urlFor(voice, file),
        bytes: file.bytes,
        sha256Digest: file.sha256Digest,
        target: target,
        onProgress: (n) => onProgress?.call(before + n),
      );
      done += file.bytes;
    }
    await marker.writeAsString('1');
    debugPrint('FINN_TTS download_ms=${watch.elapsedMilliseconds} ${voice.id}');
    if (_pruneAfterInstall) await pruneRetired();
  }

  /// Deletes voices that are on disk but no longer in the catalog (one that was
  /// replaced, for a licence or a better one), so they do not sit there for
  /// ever. This is what removes the retired Piper voices from an upgraded
  /// phone.
  Future<void> pruneRetired({Set<String>? keep}) async {
    final known = keep ?? {for (final v in ttsVoices) v.id};
    final root = await _root();
    final voices = Directory('${root.path}/voices');
    if (await voices.exists()) {
      await for (final entity in voices.list()) {
        final name = entity.path.split('/').last;
        if (entity is Directory && !known.contains(name)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    }
    // The shared phoneme data and the archives the Piper voices used.
    for (final leftover in ['espeak-ng-data', 'archives']) {
      final dir = Directory('${root.path}/$leftover');
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
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
