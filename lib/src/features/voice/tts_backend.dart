import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:finn_ai/src/features/voice/voice_settings_store.dart';

/// Speech out. The controller depends on this, never on a TTS package.
abstract class TtsBackend {
  Future<void> initialize({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onCancel,
    void Function(dynamic message)? onError,
  });
  Future<void> setSpeechRate(double rate);
  Future<void> setQueueAdd();
  Future<void> speak(String text);
  Future<void> stop();

  /// Language of what is about to be spoken (ISO 639-1), or null for the
  /// device's own.
  Future<void> setLanguage(String? language);

  /// Loudness of the speech as it plays, 0..1, for the voice animation.
  /// A backend that cannot measure it stays at 0.
  ValueListenable<double> get level;

  /// Gets ready to speak, so the first sentence of a turn does not wait for a
  /// voice to load. Optional; speaking without it works.
  Future<void> prepare();

  /// Frees whatever the backend holds while idle. Safe to call at any time;
  /// the next [speak] sets it up again.
  Future<void> release();
}

class FlutterTtsBackend implements TtsBackend {
  FlutterTtsBackend({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  final ValueNotifier<double> level = ValueNotifier(0);

  @override
  Future<void> release() async {}

  @override
  Future<void> prepare() async {}

  @override
  Future<void> setLanguage(String? language) async {
    final tag = language ?? PlatformDispatcher.instance.locale.toLanguageTag();
    try {
      if (await _tts.isLanguageAvailable(tag) == true) {
        await _tts.setLanguage(tag);
      }
    } catch (_) {}
  }

  @override
  Future<void> initialize({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onCancel,
    void Function(dynamic message)? onError,
  }) async {
    _tts.setStartHandler(onStart ?? () {});
    _tts.setCompletionHandler(onComplete ?? () {});
    _tts.setCancelHandler(onCancel ?? () {});
    if (onError != null) _tts.setErrorHandler(onError);
    await _tts.awaitSpeakCompletion(false);
    await _tts.setVolume(1.0);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final engines = await _tts.getEngines;
        if (engines is List && engines.contains('com.google.android.tts')) {
          await _tts.setEngine('com.google.android.tts');
        }
      } catch (_) {}
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      } catch (_) {}
    }
    try {
      final tag = PlatformDispatcher.instance.locale.toLanguageTag();
      if (await _tts.isLanguageAvailable(tag) == true) {
        await _tts.setLanguage(tag);
      }
    } catch (_) {}
    await setQueueAdd();
    await setSpeechRate(VoiceSettingsStore.instance.speed.rate);
  }

  @override
  Future<void> setSpeechRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<void> setQueueAdd() => _tts.setQueueMode(1);

  @override
  Future<void> speak(String text) => _tts.speak(text, focus: true);

  @override
  Future<void> stop() => _tts.stop();
}
