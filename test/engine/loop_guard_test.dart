import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/engine/generate/loop_guard.dart';

/// Feeds [text] the way a stream does, a few characters at a time.
bool _feed(LoopGuard guard, String text) {
  for (var i = 0; i < text.length; i += 3) {
    final end = i + 3 > text.length ? text.length : i + 3;
    if (guard.add(text.substring(i, end))) return true;
  }
  return false;
}

void main() {
  test('a verse repeated three times trips it', () {
    const verse = 'Rain taps the window,\n';
    expect(_feed(LoopGuard(), 'Autumn rain:\n${verse * 3}'), isTrue);
  });

  test('a long sentence repeated twice trips it', () {
    const sentence =
        'The shop opens at nine in the morning every day of the week. ';
    final guard = LoopGuard();
    expect(_feed(guard, 'Магазин открывается. $sentence$sentence'), isTrue);
    expect(guard.period, sentence.length);
  });

  test('ordinary answers never trip it', () {
    const answers = [
      'Jupiter is the largest planet in our solar system.',
      '1. Remove the wheel.\n2. Take out the tube.\n3. Find the hole.\n'
          '4. Patch it.\n5. Put the tube back.\n6. Inflate the tire.\n',
      'Sea of endless blue,\nWhispers secrets to the shore.\n'
          'Waves crash, wind sighs,\nNature\'s eternal lore.',
      '| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |\n| 5 | 6 |\n',
      'ha ha ha ha',
      'for i in range(3):\n    print(i)\nfor j in range(3):\n    print(j)\n',
    ];
    for (final answer in answers) {
      expect(_feed(LoopGuard(), answer), isFalse, reason: answer);
    }
  });

  test('a short refrain twice is fine; a third time is a loop', () {
    const refrain = 'Row, row, row your boat, ';
    expect(_feed(LoopGuard(), refrain * 2), isFalse);
    expect(_feed(LoopGuard(), refrain * 4), isTrue);
  });

  test('stays tripped', () {
    final guard = LoopGuard();
    _feed(guard, 'abcdefghijklmnopqrstuvwx' * 4);
    expect(guard.add('anything'), isTrue);
  });
}
