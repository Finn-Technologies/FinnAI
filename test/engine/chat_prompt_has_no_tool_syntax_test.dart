import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/inference/finn_inference.dart';

/// ADR 0001: the model never decides to search, so it must never be shown how.
///
/// The base system prompt used to advertise `browser_search` / `browser_open` /
/// `browser_find` on *every* turn. Only turns the app classified "advanced"
/// had a loop to run those calls; on every other turn the model emitted a call
/// into its answer and the output filters swallowed it, which is how a search
/// question produced a blank reply or a run of tool calls. Removing the
/// advertisement is the fix; this test keeps it removed.
void main() {
  const banned = [
    'tool_call',
    'tool_response',
    'browser_search',
    'browser_open',
    'browser_find',
    'TinyBrowser',
  ];

  void expectClean(String text, String where) {
    for (final word in banned) {
      expect(text, isNot(contains(word)), reason: '$where mentions "$word"');
    }
  }

  test('the base system prompt names no tools', () {
    expectClean(PromptFormatter.finnSafetySystemPrompt, 'system prompt');
    expectClean(PromptFormatter.baseSystemPrefix, 'system prefix');
  });

  test('a rendered turn names no tools, plain or grounded', () {
    for (final grounded in [
      '',
      '${PromptFormatter.groundedContextMarker}:\n[1] x'
    ]) {
      for (final prompt in [
        'What is the current price of gold per gram today?',
        'Search the web for the latest Flutter release.',
        'Hello!',
      ]) {
        final rendered = FinnInference.instance.renderPromptForTest(
          prompt: prompt,
          groundedContext: grounded,
        );
        expectClean(rendered, 'prompt for "$prompt"');
      }
    }
  });
}
