import 'package:finn_ai/src/engine/finn_engine_types.dart';
import 'package:finn_ai/src/engine/prompt/prompt_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

/// An attached document has to sit immediately before the user's question.
/// Written into the system block at the top of the prompt it ended up on the
/// far side of the whole history, and the model answered from the history
/// instead of from the file it had just been handed.
void main() {
  const document = 'Attached document (notes.txt):\n```\nBLOCKED-BY-PLUM\n```';

  test('the document is placed after the history and before the question', () {
    final prompt = PromptFormatter.renderPromptText(
      primed: false,
      prompt: 'What is blocking the rollout?',
      history: const [
        LocalChatTurn(role: 'user', content: 'an earlier question'),
        LocalChatTurn(role: 'assistant', content: 'an earlier answer'),
      ],
      attachedDocContext: document,
    );

    final doc = prompt.indexOf('BLOCKED-BY-PLUM');
    expect(doc, isNot(-1));
    expect(
      doc,
      greaterThan(prompt.indexOf('an earlier answer')),
      reason: 'the document must come after the history it has to override',
    );
    expect(
      doc,
      lessThan(prompt.indexOf('What is blocking the rollout?')),
      reason: 'the document must come before the question about it',
    );
    expect(
      prompt.indexOf('BLOCKED-BY-PLUM', doc + 1),
      -1,
      reason: 'the document is injected once',
    );
  });

  test('the document still precedes the question on a primed turn', () {
    final prompt = PromptFormatter.renderPromptText(
      primed: true,
      basePrefixReady: true,
      prompt: 'What is blocking the rollout?',
      history: const [
        LocalChatTurn(role: 'user', content: 'an earlier question'),
      ],
      attachedDocContext: document,
    );

    final doc = prompt.indexOf('BLOCKED-BY-PLUM');
    expect(doc, isNot(-1));
    expect(doc, lessThan(prompt.indexOf('What is blocking the rollout?')));
  });

  test('no document means no document block', () {
    final prompt = PromptFormatter.renderPromptText(
      primed: false,
      prompt: 'hello',
      history: const <LocalChatTurn>[],
    );
    expect(prompt.contains('Attached document'), isFalse);
  });
}
