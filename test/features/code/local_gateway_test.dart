import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/providers/gateways.dart';

void main() {
  const completion = CodeCompletion(
    system: 'SYSTEM',
    turns: [
      CodeTurn.user('first'),
      CodeTurn.user('the answer me'),
    ],
    conversationId: 'code-s1',
    maxTokens: 1024,
  );

  group('LocalCodeGateway', () {
    final gateway = LocalCodeGateway();

    test('is local, labelled FinnAI, on the on-device budget', () {
      expect(gateway.isLocal, isTrue);
      expect(gateway.label, 'FinnAI');
      expect(gateway.budget.examples, isTrue);
      expect(gateway.budget.maxSteps, 8);
    });

    test('builds an agent-prompt completion with the coding sampler', () {
      final args = gateway.argsFor(completion);
      expect(args.agentPrompt, isTrue);
      // Grammar stays off until the on-device A/B decides it helps.
      expect(args.sampler.grammar, isNull);
      expect(args.conversationId, 'code-s1');
      expect(args.system, 'SYSTEM');
      expect(args.maxTokens, 1024);
      // The last turn is what the model answers; earlier ones are history.
      expect(args.prompt, 'the answer me');
      expect(args.history.single.content, 'first');
    });
  });
}
