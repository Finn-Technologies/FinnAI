import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:finn_ai/src/features/voice/linux_speech.dart';
import 'package:finn_ai/src/features/voice/speakable_text.dart';
import 'package:finn_ai/src/features/voice/voice_settings_store.dart';
import 'package:finn_ai/src/platform/platform_target.dart';

/// Reads one reply aloud from the message menu, outside a voice chat.
class ReadAloud {
  ReadAloud._();

  static final instance = ReadAloud._();

  FlutterTts? _tts;

  Future<void> speak(String text) async {
    if (finnPlatform == FinnPlatform.linux) {
      final spoken = SpeakableText.segment(text).map((s) => s.text).join(' ');
      final spoke = await LinuxSpeech.instance.speak(
        spoken.isEmpty ? text : spoken,
        rate: VoiceSettingsStore.instance.speed.rate,
        languageCode: PlatformDispatcher.instance.locale.languageCode,
      );
      if (!spoke) debugPrint('FINN_READ_ALOUD no speech synthesiser installed');
      return;
    }
    try {
      final tts = _tts ??= FlutterTts();
      await tts.stop();
      await tts.setSpeechRate(VoiceSettingsStore.instance.speed.rate);
      final tag = PlatformDispatcher.instance.locale.toLanguageTag();
      if (await tts.isLanguageAvailable(tag) == true) {
        await tts.setLanguage(tag);
      }
      final spoken = SpeakableText.segment(text).map((s) => s.text).join(' ');
      await tts.speak(spoken.isEmpty ? text : spoken);
    } catch (error) {
      debugPrint('FINN_READ_ALOUD failed: $error');
    }
  }

  Future<void> stop() async {
    if (finnPlatform == FinnPlatform.linux) return LinuxSpeech.instance.stop();
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
