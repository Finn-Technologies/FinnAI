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

    test('a Latin reply is never read as Russian or Hindi', () {
      // Whisper guesses wrong on short or accented speech; the reply is
      // Latin script, so it must not be read as a Cyrillic or Devanagari one.
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
      expect(pickSpeechLanguage('Hello', heard: 'sw', device: 'zz'), 'en');
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
    test('the voice is pinned: every file has a size and a SHA-256', () {
      final paths = <String>{};
      for (final file in supertonicVoice.files) {
        expect(file.sha256Digest, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(file.bytes, greaterThan(0));
        expect(paths.add(file.path), isTrue, reason: file.path);
        expect(
          file.url(supertonicVoice.repository),
          startsWith('https://huggingface.co/'),
        );
        expect(file.url(supertonicVoice.repository), endsWith(file.path));
      }
      expect(supertonicVoice.bytes, inInclusiveRange(300e6, 500e6));
    });

    test('it carries the four models, the config, the indexer and the styles',
        () {
      final names = supertonicVoice.files.map((f) => f.path).toSet();
      expect(
          names,
          containsAll([
            'onnx/duration_predictor.onnx',
            'onnx/text_encoder.onnx',
            'onnx/vector_estimator.onnx',
            'onnx/vocoder.onnx',
            'onnx/tts.json',
            'onnx/unicode_indexer.json',
          ]));
      for (final style in ttsStyles) {
        expect(names, contains('voice_styles/$style.json'));
      }
      expect(ttsStyles, contains(defaultTtsStyle));
    });

    test('every language of the app, and Russian and Hindi, can be spoken', () {
      for (final code in ['en', 'de', 'es', 'fr', 'it', 'ru', 'hi']) {
        expect(ttsVoiceFor(code), isNotNull, reason: code);
      }
      expect(ttsVoiceFor('xx'), isNull);
      expect(ttsNonLatinLanguages, isEmpty);
    });

    test('it is not one of the voices whose licence does not allow shipping',
        () {
      // The Piper voices this replaced needed espeak-ng (GPL-3.0). The model
      // listed now reads characters and needs no phonemizer.
      expect(supertonicVoice.id, 'supertonic-3');
      expect(
        supertonicVoice.files.map((f) => f.path),
        everyElement(isNot(contains('espeak'))),
      );
    });

    test('language codes are normalised', () {
      expect(normalizeLanguage('<|en|>'), 'en');
      expect(normalizeLanguage('pt_BR'), 'pt');
      expect(normalizeLanguage('DE'), 'de');
      expect(normalizeLanguage(''), isNull);
      expect(normalizeLanguage(null), isNull);
      expect(ttsVoiceFor('<|ru|>'), isNotNull);
    });

    test('setup gets the one voice whatever the phone\'s language', () {
      for (final language in ['en', 'de', 'ja', null]) {
        expect(ttsVoicesForSetup(language), [supertonicVoice]);
      }
    });
  });
}
