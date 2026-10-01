import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';

/// Which language to speak [text] in.
///
/// The text is the authority on its script: Cyrillic is Russian and
/// Devanagari is Hindi whatever the speech recogniser guessed, and a
/// Latin-script reply is never read with a Cyrillic or Devanagari voice.
/// Among Latin languages there is no cheap way to tell them apart from text, so
/// [heard] (what Whisper detected in the user's speech, and the reply follows
/// the user's language) comes first, then the phone's [device] language.
String pickSpeechLanguage(String text, {String? heard, String? device}) {
  var cyrillic = 0;
  var devanagari = 0;
  var latin = 0;
  for (final rune in text.runes) {
    if (rune >= 0x0400 && rune <= 0x04FF) {
      cyrillic++;
    } else if (rune >= 0x0900 && rune <= 0x097F) {
      devanagari++;
    } else if ((rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        (rune >= 0xC0 && rune <= 0x24F)) {
      latin++;
    }
  }
  if (cyrillic > latin && cyrillic >= devanagari) return 'ru';
  if (devanagari > latin) return 'hi';
  const nonLatin = {'ru', 'hi'};
  for (final candidate in [
    normalizeLanguage(heard),
    normalizeLanguage(device)
  ]) {
    if (candidate != null &&
        !nonLatin.contains(candidate) &&
        ttsVoiceFor(candidate) != null) {
      return candidate;
    }
  }
  return 'en';
}
