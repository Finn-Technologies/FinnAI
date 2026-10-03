import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/voice/tts/local_tts_backend.dart';
import 'package:finn_ai/src/features/voice/tts_backend.dart';

/// The app's voice: the on-device Supertonic voice when one is installed, and the
/// platform's text-to-speech engine otherwise (a user who skipped the
/// download, or an engine on a phone that has one).
class FallbackTtsBackend implements TtsBackend {
  FallbackTtsBackend({LocalTtsBackend? onDevice, TtsBackend? platform})
      : _onDevice = onDevice ?? LocalTtsBackend(),
        _platform = platform ?? FlutterTtsBackend();

  final LocalTtsBackend _onDevice;
  final TtsBackend _platform;
  String? _language;

  @override
  ValueListenable<double> get level => _onDevice.level;

  @override
  Future<void> initialize({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onCancel,
    void Function(dynamic message)? onError,
  }) async {
    await _onDevice.initialize(
      onStart: onStart,
      onComplete: onComplete,
      onCancel: onCancel,
      onError: onError,
    );
    // The platform engine is optional: a phone without one must not stop the
    // on-device voice from working.
    try {
      await _platform.initialize(
        onStart: onStart,
        onComplete: onComplete,
        onCancel: onCancel,
        onError: onError,
      );
    } catch (error) {
      debugPrint('FINN_TTS platform engine unavailable: $error');
    }
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _onDevice.setSpeechRate(rate);
    try {
      await _platform.setSpeechRate(rate);
    } catch (_) {}
  }

  @override
  Future<void> setQueueAdd() async {
    try {
      await _platform.setQueueAdd();
    } catch (_) {}
  }

  @override
  Future<void> setLanguage(String? language) async {
    _language = language;
    await _onDevice.setLanguage(language);
    try {
      await _platform.setLanguage(language);
    } catch (_) {}
  }

  @override
  Future<void> prepare() => _onDevice.prepare();

  @override
  Future<void> speak(String text) async {
    if (await _onDevice.canSpeak(_language)) return _onDevice.speak(text);
    return _platform.speak(text);
  }

  @override
  Future<void> stop() async {
    await _onDevice.stop();
    try {
      await _platform.stop();
    } catch (_) {}
  }

  @override
  Future<void> release() async {
    await _onDevice.release();
    await _platform.release();
  }
}
