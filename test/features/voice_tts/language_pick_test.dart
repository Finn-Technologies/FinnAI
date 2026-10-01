import 'package:finn_ai/src/features/voice/tts/language_pick.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pickSpeechLanguage', () {
    test('Cyrillic text is Russian whatever was heard', () {
      expect(pickSpeechLanguage('Столица Франции — Париж.', heard: 'en'), 'ru');
    });

    test('Devanagari text is Hindi', () {
      expect(
          pickSpeechLanguage('फ्रांस की राजधानी पेरिस है।', heard: 'en'), 'hi');
    });

    test('a Latin reply is never read with a Russian or Hindi voice', () {
      // Whisper guesses wrong on short or accented speech; the reply is
      // English, so the English voice must read it.
      expect(pickSpeechLanguage('Paris is the capital.', heard: 'ru'), 'en');
      expect(pickSpeechLanguage('Paris is the capital.', heard: 'hi'), 'en');
    });

    test('Latin replies follow the language that was heard', () {
      expect(
          pickSpeechLanguage('Paris ist die Hauptstadt.', heard: 'de'), 'de');
      expect(pickSpeechLanguage('París es la capital.', heard: '<|es|>'), 'es');
    });

    test('with nothing heard it follows the phone', () {
      expect(pickSpeechLanguage('Parigi è la capitale.', device: 'it'), 'it');
    });

    test('a language with no voice falls back to English', () {
      expect(pickSpeechLanguage('Hello', heard: 'sw', device: 'ja'), 'en');
    });

    test('mixed text goes with the script that dominates', () {
      expect(pickSpeechLanguage('Привет, это Finn AI и это тест', heard: 'en'),
          'ru');
      expect(
          pickSpeechLanguage('The word привет means hello', heard: 'en'), 'en');
    });

    test('empty text is English', () {
      expect(pickSpeechLanguage(''), 'en');
    });
  });

  group('voice catalog', () {
    test('every voice is pinned and addressable', () {
      final languages = <String>{};
      for (final voice in ttsVoices) {
        expect(voice.sha256Digest, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(
            voice.bytes, inInclusiveRange(10 * 1000 * 1000, 60 * 1000 * 1000));
        expect(voice.url, startsWith('https://github.com/k2-fsa/sherpa-onnx/'));
        expect(voice.url, endsWith('${voice.id}.tar.bz2'));
        expect(voice.id, endsWith('-int8'));
        expect(languages.add(voice.language), isTrue,
            reason: 'one voice per language: ${voice.language}');
      }
    });

    test('English is the default and every app language has a voice', () {
      expect(defaultTtsVoice.language, 'en');
      for (final code in ['en', 'de', 'es', 'fr', 'it', 'ru']) {
        expect(ttsVoiceFor(code), isNotNull, reason: code);
      }
    });

    test('there is no Hindi voice: none has a licence that allows shipping it',
        () {
      expect(ttsVoiceFor('hi'), isNull);
      expect(ttsNonLatinLanguages, containsAll(['ru', 'hi']));
    });

    test('only voices with a redistributable licence are listed', () {
      // The voices that were considered and rejected, by archive name. If one
      // of these appears, check its dataset licence before keeping it.
      const rejected = [
        'lessac', // Blizzard 2013: a signed research licence
        'ryan', // CC BY-NC-SA
        'irina', // licence unknown
        'ruslan', // CC BY-NC-SA
        'pratham', // CC BY-NC-SA
        'priyamvada', // CC BY-NC-SA
        'rohan', // IITM research licence
        'tom', // AGPL
      ];
      for (final voice in ttsVoices) {
        for (final name in rejected) {
          expect(voice.id, isNot(contains('-$name-')), reason: voice.id);
        }
      }
    });

    test('language codes are normalised', () {
      expect(normalizeLanguage('<|en|>'), 'en');
      expect(normalizeLanguage('pt_BR'), 'pt');
      expect(normalizeLanguage('DE'), 'de');
      expect(normalizeLanguage(''), isNull);
      expect(normalizeLanguage(null), isNull);
      expect(ttsVoiceFor('<|ru|>')?.language, 'ru');
      expect(ttsVoiceFor('xx'), isNull);
    });

    test('setup gets English plus the phone\'s own language', () {
      expect(ttsVoicesForSetup('en').map((v) => v.language), ['en']);
      expect(ttsVoicesForSetup('de').map((v) => v.language), ['en', 'de']);
      expect(ttsVoicesForSetup('ja').map((v) => v.language), ['en']);
      expect(ttsVoicesForSetup(null).map((v) => v.language), ['en']);
    });
  });
}
