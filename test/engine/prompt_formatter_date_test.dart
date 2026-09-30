import 'package:finn_ai/src/engine/finn_engine_types.dart';
import 'package:finn_ai/src/engine/prompt/prompt_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-09-18 is a Friday.
  final fixed = DateTime(2026, 9, 18, 14, 32);
  const expectedBlock = '<|im_start|>system\n'
      'Current local date and time: 2026-09-18 14:32 (Friday). Use this when '
      'the user asks about today, tomorrow, yesterday, or the current time.\n'
      '<|im_end|>\n';
  const userTurnMarker = '<|im_start|>user\n';

  void expectSingleBlockBeforeFinalUserTurn(String rendered) {
    expect(rendered, contains(expectedBlock));
    expect(expectedBlock, endsWith('current time.\n<|im_end|>\n'));
    expect(expectedBlock, contains('(Friday).'));
    expect(rendered.split(expectedBlock).length - 1, 1);
    final blockStart = rendered.indexOf(expectedBlock);
    final finalUserTurn = rendered.lastIndexOf(userTurnMarker);
    expect(finalUserTurn, blockStart + expectedBlock.length);
  }

  group('currentDateTimeSystemBlock', () {
    test('renders the local date, zero-padded time and weekday', () {
      expect(PromptFormatter.currentDateTimeSystemBlock(fixed), expectedBlock);
      expect(
        PromptFormatter.currentDateTimeSystemBlock(DateTime(2026, 1, 5, 3, 7)),
        contains('2026-01-05 03:07 (Monday).'),
      );
    });
  });

  group('renderPromptText carries the date block', () {
    test('unprimed', () {
      final rendered = PromptFormatter.renderPromptText(
        primed: false,
        prompt: 'What is the date today?',
        history: const <LocalChatTurn>[],
        now: fixed,
      );
      expectSingleBlockBeforeFinalUserTurn(rendered);
    });

    test('primed', () {
      final rendered = PromptFormatter.renderPromptText(
        primed: true,
        prompt: 'What is the date today?',
        history: const <LocalChatTurn>[],
        now: fixed,
      );
      expectSingleBlockBeforeFinalUserTurn(rendered);
    });
  });
}
