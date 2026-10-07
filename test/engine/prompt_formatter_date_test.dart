import 'package:finn_ai/src/engine/finn_engine_types.dart';
import 'package:finn_ai/src/engine/prompt/prompt_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-09-18 is a Friday.
  final fixed = DateTime(2026, 9, 18, 14, 32);
  const dateOnlyBlock =
      '<|im_start|>system\nToday: 2026-09-18 (Friday).<|im_end|>\n';
  const withTimeBlock =
      '<|im_start|>system\nNow: 2026-09-18 14:32 (Friday).<|im_end|>\n';
  const userTurnMarker = '<|im_start|>user\n';

  void expectSingleBlockBeforeFinalUserTurn(
    String rendered, {
    String expectedBlock = dateOnlyBlock,
  }) {
    expect(rendered, contains(expectedBlock));
    expect(expectedBlock, endsWith('<|im_end|>\n'));
    // The rule for using the date is in the cached base prompt.
    expect(
      PromptFormatter.finnSafetySystemPrompt,
      contains('never mention it otherwise'),
    );
    expect(expectedBlock, contains('(Friday).'));
    expect(rendered.split(expectedBlock).length - 1, 1);
    final blockStart = rendered.indexOf(expectedBlock);
    final finalUserTurn = rendered.lastIndexOf(userTurnMarker);
    expect(finalUserTurn, blockStart + expectedBlock.length);
  }

  group('currentDateTimeSystemBlock', () {
    test('a date question gets the date, with zero-padded time on request', () {
      expect(
        PromptFormatter.currentDateTimeSystemBlock(fixed),
        dateOnlyBlock,
      );
      expect(
        PromptFormatter.currentDateTimeSystemBlock(
          fixed,
          includeTime: true,
        ),
        withTimeBlock,
      );
      expect(
        PromptFormatter.currentDateTimeSystemBlock(DateTime(2026, 1, 5, 3, 7)),
        contains('Today: 2026-01-05 (Monday).'),
      );
    });
  });

  group('renderPromptText carries the date block', () {
    test('a time question gets the date and the time', () {
      final rendered = PromptFormatter.renderPromptText(
        primed: false,
        prompt: 'What time is it in Rome right now?',
        history: const <LocalChatTurn>[],
        now: fixed,
      );
      expectSingleBlockBeforeFinalUserTurn(
        rendered,
        expectedBlock: withTimeBlock,
      );
      expect(PromptFormatter.asksAboutTime('What time is it?'), isTrue);
    });

    test('a date question gets the date only, primed or not', () {
      for (final primed in [false, true]) {
        final rendered = PromptFormatter.renderPromptText(
          primed: primed,
          prompt: 'What is the date today?',
          history: const <LocalChatTurn>[],
          now: fixed,
        );
        expectSingleBlockBeforeFinalUserTurn(rendered);
        expect(rendered, isNot(contains('14:32')));
      }
    });

    test('a creative prompt carries no clock time', () {
      final rendered = PromptFormatter.renderPromptText(
        primed: false,
        prompt: 'Write a short story about a lighthouse.',
        history: const <LocalChatTurn>[],
        now: fixed,
      );
      expectSingleBlockBeforeFinalUserTurn(rendered);
      expect(PromptFormatter.asksAboutTime('Tell me a story about a cat'),
          isFalse);
      expect(PromptFormatter.asksAboutTime('How many times did they try?'),
          isFalse);
    });
  });
}
