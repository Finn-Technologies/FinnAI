import 'package:finn_ai/src/engine/finn_engine_types.dart';
import 'package:finn_ai/src/engine/prompt/prompt_formatter.dart';
import 'package:finn_ai/src/engine/prompt/prompt_intent.dart';
import 'package:flutter_test/flutter_test.dart';

/// The search-decision pass decides whether a turn should go to the web.
///
/// Two things about it were wrong, both observed on the Xiaomi on 2026-09-29,
/// and both are about the same defect: the pass made its decision from the
/// question alone.
///
/// - `history` was threaded through three layers and never written into the
///   prompt, so "What did you reply above? Say it again." could not see that
///   the answer was already in the transcript, and the turn went to the web.
/// - `includeTaskInstruction` was accepted and then ignored, so the task
///   instruction was written on a primed session even when the caller had
///   already accounted for it.
void main() {
  final fixed = DateTime(2026, 9, 30, 9, 15);
  final analysis =
      const PromptIntentClassifier().classify('And what did I ask first?');
  const directive = '# TinyBrowser Tools\nSearch, or reply ANSWER.';

  String render({
    required bool primed,
    required bool includeTaskInstruction,
    List<LocalChatTurn> history = const [],
    String prompt = 'And what did I ask first?',
  }) =>
      PromptFormatter.renderDecisionPromptText(
        primed: primed,
        basePrefixReady: false,
        includeTaskInstruction: includeTaskInstruction,
        analysis: analysis,
        prompt: prompt,
        history: history,
        directive: directive,
        contextTokens: 2048,
        now: fixed,
      );

  group('the decision prompt carries the conversation', () {
    test('an unprimed pass renders the prior turns', () {
      final rendered = render(
        primed: false,
        includeTaskInstruction: true,
        history: const [
          LocalChatTurn(
              role: 'user', content: 'What is the capital of France?'),
          LocalChatTurn(role: 'assistant', content: 'Paris.'),
        ],
      );

      // This is the whole point: the decision can only be made against the
      // turn that precedes it.
      expect(rendered, contains('What is the capital of France?'));
      expect(rendered, contains('Paris.'));
      expect(rendered, contains('<|im_start|>user\nWhat is the capital of'));
      expect(rendered, contains('<|im_start|>assistant\nParis.'));
    });

    test('the prior turns come before the current question', () {
      final rendered = render(
        primed: false,
        includeTaskInstruction: true,
        history: const [
          LocalChatTurn(role: 'user', content: 'earlier question'),
          LocalChatTurn(role: 'assistant', content: 'earlier answer'),
        ],
      );
      expect(
        rendered.indexOf('earlier question'),
        lessThan(rendered.lastIndexOf('And what did I ask first?')),
        reason: 'the transcript must precede the question being decided on',
      );
    });

    test('a primed pass does not re-send what the KV cache already holds', () {
      // The primed session already contains the conversation; re-sending it
      // would be a slower way to say the same thing.
      final rendered = render(
        primed: true,
        includeTaskInstruction: false,
        history: const [
          LocalChatTurn(role: 'assistant', content: 'Paris.'),
        ],
      );
      expect(rendered, isNot(contains('Paris.')));
      expect(rendered, contains(directive));
    });

    test('an empty transcript renders no history', () {
      final rendered = render(primed: false, includeTaskInstruction: true);
      expect(rendered, contains('And what did I ask first?'));
      // Only the current question is a user turn.
      expect('<|im_start|>user\n'.allMatches(rendered).length, 1);
    });
  });

  group('includeTaskInstruction is honoured', () {
    test('the instruction is present when the caller asks for it', () {
      final rendered = render(primed: false, includeTaskInstruction: true);
      expect(
        rendered,
        contains(PromptIntentPolicy.taskInstruction(analysis)),
      );
    });

    test('the instruction is absent when the caller says it is already there',
        () {
      // The flag exists to stop the same block being written twice over a
      // primed session. Accepting it and then ignoring it meant it was written
      // on every decision pass regardless.
      final rendered = render(primed: false, includeTaskInstruction: false);
      expect(
        rendered,
        isNot(contains(PromptIntentPolicy.taskInstruction(analysis))),
      );
    });
  });

  group('the pass still routes correctly', () {
    test('the directive and the question are always present', () {
      for (final primed in [true, false]) {
        final rendered = render(
          primed: primed,
          includeTaskInstruction: true,
          history: const [LocalChatTurn(role: 'user', content: 'earlier')],
        );
        expect(rendered, contains(directive), reason: 'primed=$primed');
        expect(
          rendered,
          contains('And what did I ask first?'),
          reason: 'primed=$primed',
        );
        // The pass must end ready for the model's answer.
        expect(
          rendered,
          endsWith('<|im_start|>assistant\n'),
          reason: 'primed=$primed',
        );
      }
    });
  });
}
