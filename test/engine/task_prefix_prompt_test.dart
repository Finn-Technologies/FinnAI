import 'package:finn_ai/src/engine/finn_engine_types.dart';
import 'package:finn_ai/src/engine/prompt/prompt_formatter.dart';
import 'package:finn_ai/src/engine/prompt/prompt_intent.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fresh chat restores the base prefix together with its intent's task
/// instruction from disk (session_prep.dart). The prompt then must not write
/// the instruction a second time, and must still write it whenever the state
/// does not hold it.
void main() {
  const question = 'What is the largest planet?';
  final instruction = PromptIntentPolicy.taskInstruction(
    const PromptIntentClassifier().classify(question),
  );

  int count(String haystack, String needle) =>
      needle.allMatches(haystack).length;

  test('a restored task state is not written again', () {
    final prompt = PromptFormatter.renderPromptText(
      primed: false,
      basePrefixReady: true,
      taskPrefixReady: true,
      prompt: question,
      history: const [],
    );
    expect(count(prompt, instruction), 0);
    expect(prompt, contains(question));
    expect(prompt, isNot(contains(PromptFormatter.baseSystemPrefix)));
  });

  test('without a task state the instruction is written once', () {
    final prompt = PromptFormatter.renderPromptText(
      primed: false,
      basePrefixReady: true,
      prompt: question,
      history: const [],
    );
    expect(count(prompt, instruction), 1);
  });

  test('a task state without the base prefix is ignored', () {
    final prompt = PromptFormatter.renderPromptText(
      primed: false,
      taskPrefixReady: true,
      prompt: question,
      history: const [],
    );
    expect(count(prompt, instruction), 1);
    expect(prompt, startsWith(PromptFormatter.baseSystemPrefix));
  });

  test('history follows the cached instruction', () {
    final prompt = PromptFormatter.renderPromptText(
      primed: false,
      basePrefixReady: true,
      taskPrefixReady: true,
      prompt: question,
      history: const [
        LocalChatTurn(role: 'user', content: 'an earlier question'),
        LocalChatTurn(role: 'assistant', content: 'an earlier answer'),
      ],
    );
    expect(prompt, startsWith('<|im_start|>user\nan earlier question'));
  });
}
