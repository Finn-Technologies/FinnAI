import 'package:finn_ai/src/features/voice/reply_chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReplyChunker', () {
    test('waits for a sentence to end', () {
      final chunker = ReplyChunker();
      expect(chunker.next('Hello there'), isNull);
      expect(chunker.next('Hello there. How can'), 'Hello there.');
    });

    test('hands out each piece once', () {
      final chunker = ReplyChunker();
      expect(chunker.next('One. Two. Thr'), 'One. Two.');
      expect(chunker.next('One. Two. Thr'), isNull);
      expect(chunker.next('One. Two. Three. Fo'), 'Three.');
    });

    test('a decimal point is not a sentence end', () {
      final chunker = ReplyChunker();
      expect(chunker.next('It costs 3.50 dollars'), isNull);
    });

    group('the first piece starts early', () {
      test('at a comma once it is long enough', () {
        final chunker = ReplyChunker();
        const lead = 'The sky looks blue to us because of scattering, and';
        expect(lead.indexOf(','), greaterThanOrEqualTo(40));
        expect(chunker.next(lead),
            'The sky looks blue to us because of scattering,');
      });

      test('not at a comma that comes too soon', () {
        final chunker = ReplyChunker();
        expect(chunker.next('Well, the answer is'), isNull);
      });

      test('at a word when a long sentence has no comma at all', () {
        final chunker = ReplyChunker();
        const text = 'The sky appears blue because molecules in the air '
            'scatter short wavelengths of sunlight much more strongly than lo';
        final piece = chunker.next(text)!;
        expect(
            piece.length, greaterThanOrEqualTo(ReplyChunker.earlyWordCutChars));
        // Never cut inside a word: the streamed tail may be half written.
        expect(text.startsWith(piece), isTrue);
        expect(text.startsWith(piece), isTrue);
        expect(text.substring(piece.length)[0], ' ',
            reason: 'ends on a word boundary: "$piece"');
        expect(piece, isNot(endsWith('lo')));
      });

      test('only the first piece is cut early', () {
        final chunker = ReplyChunker();
        chunker
            .next('First sentence done. Then a long second sentence that has '
                'no commas and just keeps going for quite a while more');
        // The rest waits for a real boundary.
        expect(
          chunker.next('First sentence done. Then a long second sentence that '
              'has no commas and just keeps going for quite a while more and '
              'more'),
          isNull,
        );
      });

      test('a short reply is not cut at all', () {
        final chunker = ReplyChunker();
        expect(chunker.next('Paris is the capital of France'), isNull);
      });
    });

    test('markup alone is dropped, not spoken', () {
      final chunker = ReplyChunker();
      // A line that is only bold markers must not become a spoken piece.
      expect(chunker.next('**\nReal sentence here.'), isNot('**'));
    });

    test('remainder is what is left once the reply has finished', () {
      final chunker = ReplyChunker();
      chunker.next('First sentence. Second');
      expect(chunker.remainder('First sentence. Second part here.'),
          'Second part here.');
    });

    test('reset starts a new reply', () {
      final chunker = ReplyChunker();
      chunker.next('One. Two');
      expect(chunker.spokenAnything, isTrue);
      chunker.reset();
      expect(chunker.spokenAnything, isFalse);
      expect(chunker.next('Fresh. Start'), 'Fresh.');
    });
  });

  group('sentenceCount', () {
    test('counts finished sentences only', () {
      expect(ReplyChunker.sentenceCount(''), 0);
      expect(ReplyChunker.sentenceCount('Not yet'), 0);
      expect(ReplyChunker.sentenceCount('One. Two'), 1);
      expect(ReplyChunker.sentenceCount('One. Two. Three!'), 3);
      expect(ReplyChunker.sentenceCount('Really? Yes. Sure.'), 3);
    });

    test('a decimal is not a sentence, and a run of marks is one', () {
      expect(ReplyChunker.sentenceCount('It costs 3.50 dollars'), 0);
      expect(ReplyChunker.sentenceCount('What?! No way.'), 2);
      expect(ReplyChunker.sentenceCount('Hmm... maybe. Or not.'), 3);
    });

    test('a sentence ending a line counts', () {
      expect(ReplyChunker.sentenceCount('One.\nTwo.\nThree.'), 3);
    });

    test('the cap is three', () {
      expect(ReplyChunker.spokenReplyMaxSentences, 3);
    });
  });
}
