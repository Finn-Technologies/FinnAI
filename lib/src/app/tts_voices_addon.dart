import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/onboarding/model_install.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_store.dart';

/// The on-device voices that read replies aloud, offered with the language
/// model: English, and the voice for the phone's language.
class TtsVoicesAddon implements InstallAddon {
  TtsVoicesAddon({String? deviceLanguage, TtsVoiceStore? store})
      : _store = store ?? TtsVoiceStore.instance,
        _voices = ttsVoicesForSetup(deviceLanguage);

  final TtsVoiceStore _store;
  final List<TtsVoice> _voices;
  final ValueNotifier<double> _progress = ValueNotifier(0);

  @override
  int get totalBytes => _voices.fold(0, (sum, v) => sum + v.bytes);

  @override
  ValueListenable<double> get progress => _progress;

  Future<List<TtsVoice>> _missing() async => [
        for (final voice in _voices)
          if (!await _store.isInstalled(voice)) voice,
      ];

  @override
  Future<bool> isInstalled() async {
    final done = (await _missing()).isEmpty;
    if (done) _progress.value = 1;
    return done;
  }

  @override
  Future<bool> shouldOfferOnUpgrade() async =>
      (await _missing()).isNotEmpty && !await _store.installFailedBefore();

  @override
  Future<void> install() async {
    final total = totalBytes;
    var done = 0;
    for (final voice in _voices) {
      if (await _store.isInstalled(voice)) {
        done += voice.bytes;
        _progress.value = done / total;
        continue;
      }
      await _store.install(
        voice,
        onProgress: (n) => _progress.value = ((done + n) / total).clamp(0, 1),
      );
      done += voice.bytes;
      _progress.value = done / total;
    }
    await _store.clearInstallFailed();
  }

  @override
  Future<void> markFailed() => _store.markInstallFailed();
}
