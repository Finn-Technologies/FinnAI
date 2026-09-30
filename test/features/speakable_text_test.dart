import 'package:finn_ai/src/features/voice/speakable_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// A spoken answer is not a written one.
///
/// The controller used to hand the model's raw Markdown to the TTS engine, so
/// a fenced code block was read aloud as "backtick d-a-r-t backtick" and a
/// bullet list as "dash one, dash two". On a phone, at 0.45 rate, in public,
/// that is the difference between a feature someone uses and one they turn
/// off.
///
/// These tests are the specification for that. "Does this read well aloud" is
/// exactly the judgement a test should pin down rather than leave to whoever
/// happens to try it on a train.
void main() {
  group('code', () {
    test('a fenced block is announced, not recited', () {
      final spoken = SpeakableText.flatten('''
Here is the snippet:

```dart
final x = 1;
```

That is all.
''');
      expect(spoken, contains('Here is the snippet'));
      expect(spoken, contains('That is all'));
      // The marker, and none of the code.
      expect(spoken, contains(codeBlockMarker));
      expect(spoken, isNot(contains('final x')));
      expect(spoken, isNot(contains('dart')));
      expect(spoken, isNot(contains('```')));
    });

    test('a tilde fence is treated the same', () {
      final spoken = SpeakableText.flatten('~~~\nplain text block\n~~~\nDone.');
      expect(spoken, contains(codeBlockMarker));
      expect(spoken, isNot(contains('plain text block')));
      expect(spoken, contains('Done.'));
    });

    test('an unterminated fence still closes and is still skipped', () {
      // A reply cut off mid-block is exactly when "code block skipped"
      // matters: the alternative is reading the half-block.
      final spoken = SpeakableText.flatten('Start.\n```dart\nfinal x = 1;');
      expect(spoken, contains('Start.'));
      expect(spoken, contains(codeBlockMarker));
      expect(spoken, isNot(contains('final x')));
    });

    test('an empty code block is silent rather than announced', () {
      final spoken = SpeakableText.flatten('Before.\n```\n```\nAfter.');
      expect(spoken, isNot(contains(codeBlockMarker)));
      expect(spoken, contains('Before.'));
      expect(spoken, contains('After.'));
    });

    test('inline code keeps its words and loses its backticks', () {
      expect(
        SpeakableText.flatten(r'Call `printHello()` first.'),
        'Call printHello() first.',
      );
    });
  });

  group('lists and headings', () {
    test('bullet markers are dropped but the words stay', () {
      final spoken = SpeakableText.flatten('''
- first item
- second item
* third item
+ fourth item
''');
      expect(spoken, contains('first item'));
      expect(spoken, contains('fourth item'));
      expect(spoken, isNot(contains('-')));
      expect(spoken, isNot(contains('*')));
      expect(spoken, isNot(contains('+')));
    });

    test('numbered list markers are dropped but the numbering reads right', () {
      // The digits are kept so "first, second" still has an order; only the
      // delimiter is removed.
      final spoken = SpeakableText.flatten('1. alpha\n2. beta');
      expect(spoken, contains('1. alpha'));
      expect(spoken, contains('2. beta'));
    });

    test('a heading loses its hashes', () {
      expect(SpeakableText.flatten('## How it works'), 'How it works');
      expect(SpeakableText.flatten('### Deep'), 'Deep');
    });

    test('a list inside a code fence is not treated as a list', () {
      final spoken = SpeakableText.flatten('```\n- not a list\n```');
      expect(spoken, isNot(contains('not a list')));
    });
  });

  group('emphasis, links and tables', () {
    test('bold and italic lose their markers', () {
      expect(SpeakableText.flatten('This is **important** here.'),
          'This is important here.');
      expect(SpeakableText.flatten('This is *important* here.'),
          'This is important here.');
    });

    test('a link speaks its label, not its URL', () {
      final spoken = SpeakableText.flatten(
        'See [the docs](https://example.com/a/very/long/path).',
      );
      expect(spoken, contains('the docs'));
      expect(spoken, isNot(contains('example.com')));
    });

    test('a bare URL is dropped rather than spelled out', () {
      final spoken = SpeakableText.flatten('Details at https://example.com/x.');
      expect(spoken, isNot(contains('example.com')));
    });

    test('an image is dropped entirely', () {
      final spoken =
          SpeakableText.flatten('![a chart](https://x.com/a.png) Done.');
      expect(spoken, isNot(contains('chart')));
      expect(spoken, isNot(contains('a.png')));
      expect(spoken, contains('Done.'));
    });

    test('a table is announced once, not cell by cell', () {
      final spoken = SpeakableText.flatten('''
| Name | Age |
| --- | --- |
| Ada | 36 |
| Bob | 41 |
''');
      expect(spoken, contains(tableMarker));
      // The failure mode being prevented is "pipe Name pipe pipe Age pipe".
      expect(spoken, isNot(contains('|')));
      expect(spoken, isNot(contains('Ada')));
    });

    test('HTML tags are dropped', () {
      expect(
        SpeakableText.flatten('Hello <b>there</b> friend'),
        'Hello there friend',
      );
    });
  });

  group('trailing fragments', () {
    test('a dangling template tag is cut, keeping the sentence before it', () {
      // A reply cut off mid-token can end in the model's plumbing. Speaking
      // "less-than, pipe, i, m, underscore" is worse than silence — but the
      // sentence before it is still the answer, so it is kept.
      expect(
        SpeakableText.stripTrailingFragment('All done. <|im_'),
        'All done.',
      );
      expect(
          SpeakableText.stripTrailingFragment('All done. <div'), 'All done.');
      expect(
        SpeakableText.stripTrailingFragment('All done. <|im_end'),
        'All done.',
      );
    });

    test('a tail that is only a fragment is dropped entirely', () {
      expect(SpeakableText.stripTrailingFragment('<|im_'), isNull);
    });

    test('a complete sentence is kept', () {
      expect(SpeakableText.stripTrailingFragment('All done.'), 'All done.');
    });

    test('an empty tail is dropped', () {
      expect(SpeakableText.stripTrailingFragment('   '), isNull);
    });
  });

  group('robustness', () {
    test('an empty answer speaks as nothing', () {
      expect(SpeakableText.flatten(''), isEmpty);
      expect(SpeakableText.flatten('   \n\n  '), isEmpty);
    });

    test('markup-only input speaks as nothing', () {
      expect(SpeakableText.flatten('```\n```'), isEmpty);
      expect(SpeakableText.flatten('<br><br>'), isEmpty);
    });

    test('a very long answer does not blow up', () {
      final long = List.filled(2000, 'word').join(' ');
      expect(SpeakableText.flatten(long).split(' ').length, 2000);
    });

    test('a realistic answer keeps every word that matters', () {
      const answer = '''
Sure — here is what to do.

## Steps

1. Open **Settings**
2. Tap `Wi-Fi`
3. Choose your network

> Note: this only works on the saved networks.

That's it. Let me know if the list is missing something.
''';
      final spoken = SpeakableText.flatten(answer);
      for (final expected in [
        'Sure',
        'Steps',
        'Settings',
        'Wi-Fi',
        'Choose your network',
        'Note',
        // Lower-case, exactly as the source has it: the blockquote's marker is
        // dropped and a sentence end added, but no word is changed, and the
        // case is part of the wording.
        'this only works on the saved networks',
        "That's it",
        'missing something',
      ]) {
        expect(spoken, contains(expected), reason: 'lost "$expected"');
      }
    });
  });
}
