import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/engine/prompt/prompt_formatter.dart';
import 'package:finn_ai/src/engine/prompt/prompt_intent.dart';

/// The multi-round browser loop lives inside `_generateForModel`, which needs a
/// native session and so cannot be driven from a unit test. What *is* testable
/// — and what the loop's correctness actually rests on — is the prompt
/// contract: the tool directive, the forced-browse escalation, and the replay
/// of earlier findings that stops a small model repeating itself.
void main() {
  final analysis = const PromptIntentClassifier().classify(
    'What is the latest stable Flutter version?',
  );

  String decisionPrompt(
          {String priorToolContext = '', bool requireToolCall = false}) =>
      PromptFormatter.renderDecisionPromptText(
        primed: false,
        basePrefixReady: false,
        includeTaskInstruction: true,
        analysis: analysis,
        prompt: 'What is the latest stable Flutter version?',
        history: const [],
        directive: PromptIntentPolicy.searchDecisionDirectiveFor(
          PromptLanguage.english,
          requireToolCall: requireToolCall,
        ),
        priorToolContext: priorToolContext,
      );

  group('tool directive', () {
    test('advertises all three browser tools', () {
      final directive =
          PromptIntentPolicy.searchDecisionDirectiveFor(PromptLanguage.english);

      expect(directive, contains('browser_search'));
      expect(directive, contains('browser_open'));
      expect(directive, contains('browser_find'));
      expect(directive, contains('TinyBrowser Tools'));
    });

    test('lets the model decline when browsing is optional', () {
      final directive =
          PromptIntentPolicy.searchDecisionDirectiveFor(PromptLanguage.english);

      expect(directive, contains('reply exactly: ANSWER'));
      expect(directive, isNot(contains('must output one tool call')));
    });

    test('requires a tool call when the user asked to browse', () {
      final directive = PromptIntentPolicy.searchDecisionDirectiveFor(
        PromptLanguage.english,
        requireToolCall: true,
      );

      expect(directive, contains('must output one tool call now'));
      expect(directive, isNot(contains('reply exactly: ANSWER')));
    });
  });

  group('prior findings replay', () {
    test('is omitted on the first round', () {
      final prompt = decisionPrompt();

      expect(
        prompt,
        isNot(contains('You already called your browser tools')),
      );
      // The ordinary contract is still present.
      expect(prompt, contains('TinyBrowser Tools'));
      expect(prompt, contains('What is the latest stable Flutter version?'));
    });

    test('replays what the browser returned so the next round differs', () {
      final prompt = decisionPrompt(
        priorToolContext: 'TinyBrowser Search Results for "flutter version":\n'
            '[1] Flutter releases\nURL: https://example.com/releases',
      );

      expect(prompt, contains('You already called your browser tools'));
      expect(prompt, contains('TinyBrowser Search Results'));
      expect(prompt, contains('https://example.com/releases'));
      // It must not invite another blind call.
      expect(prompt, contains('Call another tool only if something'));
      expect(prompt, contains('reply exactly: ANSWER'));
    });

    test('keeps the user prompt last so the model answers the real question',
        () {
      final prompt = decisionPrompt(
        priorToolContext: 'earlier findings',
      );
      final userIndex = prompt.lastIndexOf('<|im_start|>user');
      final contextIndex = prompt.indexOf('You already called');

      expect(contextIndex, lessThan(userIndex));
      expect(prompt.trimRight(), endsWith('<|im_start|>assistant'));
    });

    test('whitespace-only context adds nothing', () {
      final prompt = decisionPrompt(priorToolContext: '   \n  ');

      expect(prompt, isNot(contains('You already called')));
    });

    test('multiple rounds accumulate in order', () {
      final prompt = decisionPrompt(
        priorToolContext:
            'round one findings\n\nround two findings\n\nround three findings',
      );

      expect(
        prompt.indexOf('round one findings'),
        lessThan(prompt.indexOf('round two findings')),
      );
      expect(
        prompt.indexOf('round two findings'),
        lessThan(prompt.indexOf('round three findings')),
      );
    });
  });
}
