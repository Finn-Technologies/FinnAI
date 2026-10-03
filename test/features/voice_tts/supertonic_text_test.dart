import 'package:finn_ai/src/features/voice/tts/supertonic_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('preprocess', () {
    String clean(String text, [String lang = 'en']) =>
        SupertonicText.preprocess(text, lang);

    test('wraps the text in its language tag and ends it with a full stop', () {
      expect(clean('Hello there'), '<en>Hello there.</en>');
      expect(clean('Is it?'), '<en>Is it?</en>');
      expect(clean('Ciao', 'it'), '<it>Ciao.</it>');
    });

    test('an unknown language reads as language-agnostic', () {
      expect(clean('Hi', 'xx'), '<na>Hi.</na>');
    });

    test('emoji and stray symbols are dropped, odd quotes made plain', () {
      expect(clean('Great 😀 job ♥'), '<en>Great job.</en>');
      expect(clean('He said “hi”'), '<en>He said "hi"</en>');
      expect(clean('it’s fine'), "<en>it's fine.</en>");
    });

    test('dashes, brackets and slashes become words apart', () {
      expect(clean('a—b'), '<en>a-b.</en>');
      expect(clean('a/b [c]'), '<en>a b c.</en>');
    });

    test('space before punctuation is removed, whitespace collapsed', () {
      expect(clean('Wait , what ?  Really'), '<en>Wait, what? Really.</en>');
    });

    test('an at-sign is spoken', () {
      expect(clean('me@site'), '<en>me at site.</en>');
    });

    test('accented letters decompose so the model can read them', () {
      // é -> e + U+0301, which the model's table has.
      expect(clean('café', 'fr'), '<fr>café.</fr>');
      expect(SupertonicText.decompose('ü'), 'ü');
      expect(SupertonicText.decompose('ß'), 'ß', reason: 'it has its own id');
    });

    test('Hangul syllables decompose into their parts', () {
      // 한 = ㅎ + ㅏ + ㄴ
      expect(
        SupertonicText.decompose('한').runes.toList(),
        [0x1112, 0x1161, 0x11AB],
      );
    });

    test('empty text stays empty rather than becoming a lone full stop', () {
      expect(clean('   '), '<en></en>');
    });
  });

  group('ids', () {
    final indexer = List<int>.filled(0x2000, -1)
      ..[0x61] = 10 // a
      ..[0x62] = 11 // b
      ..[0x3c] = 1; // <

    test('maps characters through the table and skips the unknown', () {
      expect(SupertonicText.ids('a<b?', indexer), [10, 1, 11]);
    });

    test('a character beyond the table is skipped, not an error', () {
      expect(SupertonicText.ids('a\u{1F600}b', indexer), [10, 11]);
    });
  });

  group('chunk', () {
    test('short text is one piece', () {
      expect(SupertonicText.chunk('One. Two.'), ['One. Two.']);
    });

    test('long text splits at sentence ends, within the limit', () {
      final sentence = '${'word ' * 20}end.';
      final text = List.filled(8, sentence).join(' ');
      final pieces = SupertonicText.chunk(text, maxLength: 300);
      expect(pieces.length, greaterThan(1));
      for (final piece in pieces) {
        expect(piece.length, lessThanOrEqualTo(300));
        expect(piece, endsWith('end.'));
      }
    });

    test('abbreviations do not end a sentence', () {
      final text = 'Dr. Smith met Mr. Jones. ${'x ' * 150}end.';
      final pieces = SupertonicText.chunk(text, maxLength: 60);
      expect(pieces.first, startsWith('Dr. Smith met Mr. Jones.'));
    });

    test('paragraphs are never joined', () {
      expect(
        SupertonicText.chunk('First.\n\nSecond.'),
        ['First.', 'Second.'],
      );
    });

    test('Korean and Japanese use a shorter piece', () {
      expect(SupertonicText.maxChunk('ko'), 120);
      expect(SupertonicText.maxChunk('ja'), 120);
      expect(SupertonicText.maxChunk('en'), 300);
    });
  });

  test('the model\'s languages include everything the app is translated into',
      () {
    for (final code in ['en', 'it', 'es', 'fr', 'de']) {
      expect(SupertonicText.languages, contains(code));
    }
  });
}
