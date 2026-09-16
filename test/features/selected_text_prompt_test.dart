import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/chat/home_shell.dart';

void main() {
  group('Ask Finn AI selected-text prompt shaping', () {
    test('wraps a bare topic as a question', () {
      expect(selectedTextPrompt('quantum entanglement'),
          'What is quantum entanglement?');
      expect(selectedTextPrompt('  gravity  '), 'What is gravity?');
    });

    test('sends an already-formed question verbatim', () {
      expect(
        selectedTextPrompt('What causes ocean tides?'),
        'What causes ocean tides?',
      );
    });

    test('sends an instruction verbatim instead of mangling it', () {
      expect(
        selectedTextPrompt('Explain gravity in one sentence'),
        'Explain gravity in one sentence',
      );
      expect(
        selectedTextPrompt('Summarize this article'),
        'Summarize this article',
      );
      expect(
        selectedTextPrompt('Translate this sentence into Italian'),
        'Translate this sentence into Italian',
      );
    });

    test('keeps multi-line selections verbatim', () {
      expect(selectedTextPrompt('line one\nline two'), 'line one\nline two');
    });

    test('ignores an empty selection', () {
      expect(selectedTextPrompt('   '), '');
    });
  });
}
