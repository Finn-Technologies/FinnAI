import 'package:finn_ai/src/engine/finn_accelerator.dart';
import 'package:flutter_test/flutter_test.dart';

/// The output budget is the app's only bound on how long one turn may run.
///
/// It used to be `max(intentBudget, contextSize - 96)`, which meant the
/// context bound always won: on the 4096-token context this device profiles
/// into, *every* turn was allowed 4000 output tokens. The device eval found a
/// real runaway on that — one case emitted all 4000 and took 230 seconds,
/// nearly four times the rest of the suite combined, for a question whose whole
/// answer was one word.
///
/// The intent budget is now the ceiling and the context only caps it.
void main() {
  final accelerator = FinnAccelerator.instance;

  group('the budget follows the intent, not just the context', () {
    test('a one-word answer is capped far below the context', () {
      final budget = accelerator.outputBudgetForTest(
        'Reply with only the word blue.',
        deviceCeiling: 4096,
      );
      // quickQuestion wants 224; 3x leaves room for the model to explain
      // itself, and is nowhere near the 4000 the old formula allowed.
      expect(budget, lessThan(1000));
      expect(budget, greaterThan(0));
    });

    test('a long-form request gets a larger budget than a one-word answer', () {
      final quick = accelerator.outputBudgetForTest(
        'What is the capital of France?',
        deviceCeiling: 4096,
      );
      final coding = accelerator.outputBudgetForTest(
        'Write a Python function that parses a CSV and returns totals per column',
        deviceCeiling: 4096,
      );
      expect(coding, greaterThan(quick));
    });

    test('the context window still caps a large intent budget', () {
      // 768 * 3 = 2304, which fits a 4096 context. Ask for a tiny context and
      // the bound must come from the window instead, or a 2048-token device
      // would overrun its own KV cache.
      final budget = accelerator.outputBudgetForTest(
        'Write a Python function that parses a CSV and returns totals per column',
        deviceCeiling: 1200,
      );
      expect(budget, lessThanOrEqualTo(1200 - 96));
    });

    test('a 2048-context device gets a smaller budget than a 4096 one', () {
      const prompt = 'Write a Python function that parses a CSV';
      final small =
          accelerator.outputBudgetForTest(prompt, deviceCeiling: 2048);
      final large =
          accelerator.outputBudgetForTest(prompt, deviceCeiling: 4096);
      expect(small, lessThan(large));
    });

    test('every intent produces a positive budget on every context class', () {
      // A zero budget would mean an empty reply: the same class of bug as the
      // device-confirmed empty answer.
      const prompts = [
        'hello',
        'translate this to German: the train leaves at six',
        'how do I change a tyre?',
        'write a poem about the sea',
        'what is the capital of France?',
        'write code to sort a list',
        'compare the iPhone 14 and the Redmi Note 12',
        'should I take this medication?',
      ];
      for (final context in [2048, 4096]) {
        for (final prompt in prompts) {
          final budget =
              accelerator.outputBudgetForTest(prompt, deviceCeiling: context);
          expect(
            budget,
            greaterThan(0),
            reason: '"$prompt" at ctx=$context got a $budget token budget',
          );
        }
      }
    });
  });
}
