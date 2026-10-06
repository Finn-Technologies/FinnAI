import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/engine/finn_engine_types.dart';
import 'package:finn_ai/src/engine/prompt/agent_prompt.dart';

void main() {
  const system = 'You are FinnAI Code.';
  const history = [
    LocalChatTurn(role: 'user', content: 'Create a.txt'),
    LocalChatTurn(role: 'assistant', content: '```file a.txt\nhi\n```'),
  ];

  test('an agent prompt carries only its own system prompt', () {
    final text = AgentPrompt.render(
      system: system,
      history: history,
      prompt: 'Wrote a.txt',
    );
    expect(text, startsWith('<|im_start|>system\nYou are FinnAI Code.'));
    // No chat persona, no date block, no private-configuration wrapper.
    expect(text, isNot(contains('Finn AI, a warm')));
    expect(text, isNot(contains('Current local date')));
    expect(text, isNot(contains('private user configuration')));
    expect(text, contains('<|im_start|>assistant\n```file a.txt\nhi\n```'));
    expect(text, endsWith('<|im_start|>assistant\n<think>\n\n</think>\n\n'));
  });

  test('a continuation closes the last reply and adds one user turn', () {
    expect(
      AgentPrompt.continuation('next'),
      '<|im_end|>\n<|im_start|>user\nnext<|im_end|>\n'
      '<|im_start|>assistant\n<think>\n\n</think>\n\n',
    );
  });

  test('a session continues only when every held turn matches', () {
    final held = AgentPrompt.key(history, 'Wrote a.txt');
    final next = [
      ...history,
      const LocalChatTurn(role: 'user', content: 'Wrote a.txt'),
      const LocalChatTurn(role: 'assistant', content: 'Done.'),
    ];
    expect(AgentPrompt.continues(held, next), isTrue);
    // The reply itself is free to be reformatted by the caller.
    expect(
      AgentPrompt.continues(held, [
        ...next.take(3),
        const LocalChatTurn(role: 'assistant', content: 'Done!'),
      ]),
      isTrue,
    );
    // A trimmed or compacted history is a different conversation.
    expect(AgentPrompt.continues(held, next.sublist(1)), isFalse);
    expect(
      AgentPrompt.continues(held, [
        history.first,
        const LocalChatTurn(role: 'assistant', content: '(… 1 lines …)'),
        ...next.skip(2),
      ]),
      isFalse,
    );
    expect(AgentPrompt.continues(null, next), isFalse);
  });
}
