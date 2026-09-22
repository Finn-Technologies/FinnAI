import 'dart:typed_data';

import 'package:finn_ai/src/inference/prompt_intent.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/shared/widgets/safe_markdown_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

void main() {
  const classifier = PromptIntentClassifier();

  group('multilingual prompt intent', () {
    const cases = <String, (PromptIntent, PromptLanguage)>{
      'Come fare una torta di ricotta e fragole?': (
        PromptIntent.recipe,
        PromptLanguage.italian,
      ),
      'Come preparare una pizza margherita?': (
        PromptIntent.recipe,
        PromptLanguage.italian,
      ),
      'Spiegami come cambiare una lampadina.': (
        PromptIntent.howTo,
        PromptLanguage.italian,
      ),
      'Scrivi un messaggio per prenotare una visita.': (
        PromptIntent.writing,
        PromptLanguage.italian,
      ),
      'Confronta iPhone 14 e Redmi Note 12.': (
        PromptIntent.comparison,
        PromptLanguage.italian,
      ),
      'Translate this sentence into Italian.': (
        PromptIntent.translation,
        PromptLanguage.english,
      ),
      'Hello': (PromptIntent.greeting, PromptLanguage.english),
      'Ciao': (PromptIntent.greeting, PromptLanguage.italian),
      'Ciao, come stai?': (PromptIntent.greeting, PromptLanguage.italian),
      '¿Cómo hacer una tortilla?': (PromptIntent.howTo, PromptLanguage.spanish),
      'Écris un message de confirmation.': (
        PromptIntent.writing,
        PromptLanguage.french,
      ),
      'Vergleiche diese zwei Telefone.': (
        PromptIntent.comparison,
        PromptLanguage.german,
      ),
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        final result = classifier.classify(entry.key);
        expect(result.intent, entry.value.$1);
        expect(result.language, entry.value.$2);
      });
    }
  });

  test('intent output budgets cover greetings through high-stakes work', () {
    expect(PromptIntentPolicy.desiredOutputTokens(PromptIntent.greeting), 160);
    expect(PromptIntentPolicy.desiredOutputTokens(PromptIntent.recipe), 320);
    expect(PromptIntentPolicy.desiredOutputTokens(PromptIntent.howTo), 320);
    expect(
      PromptIntentPolicy.desiredOutputTokens(PromptIntent.comparison),
      512,
    );
    expect(PromptIntentPolicy.desiredOutputTokens(PromptIntent.analysis), 768);
    expect(PromptIntentPolicy.desiredOutputTokens(PromptIntent.coding), 768);
  });

  test('search decision pass is skipped for self-contained intents', () {
    const classifier = PromptIntentClassifier();
    for (final prompt in [
      'Write a short story about a robot.',
      'Scrivi un messaggio per prenotare una visita.',
      'Translate this sentence into Italian.',
      'Write a python function to parse JSON.',
      'What are the symptoms of a migraine?',
      'Come posso aggiornare la RAM del portatile?',
      'Compare iPhone 14 and Redmi Note 12.',
      'Tell me something useful for today.',
    ]) {
      expect(
        PromptIntentPolicy.needsSearchDecision(classifier.classify(prompt)),
        isFalse,
        reason: prompt,
      );
    }
  });

  test('recipe prompt contract is Italian, structured, and private-aware', () {
    final rendered = FinnInference.instance.renderPromptForTest(
      prompt: 'Come fare una torta di ricotta e fragole?',
      systemContext: 'Dietary preference: vegetarian.',
    );

    expect(rendered, contains('Reply in italian'));
    expect(rendered, contains('sweet or savoury'));
    expect(rendered, contains('servings'));
    expect(rendered, contains('oven temperature'));
    expect(rendered, contains('Use metric measurements'));
    expect(rendered, contains('Dietary preference: vegetarian.'));
    expect(rendered, contains('Respect dietary restrictions'));
    expect(
      rendered.indexOf(FinnInference.finnSafetySystemPrompt.trim()),
      lessThan(rendered.indexOf('Provide a practical recipe')),
    );
  });

  test(
    'hardware guidance asks for exact model and avoids invented internals',
    () {
      const prompts = [
        'Can you tell me how to upgrade the RAM in my laptop?',
        'How do I replace my laptop SSD?',
        'How do I replace my phone battery?',
        'Come posso aggiornare la RAM del portatile?',
        'Come posso sostituire l’SSD del portatile?',
        'Come posso sostituire la batteria del telefono?',
      ];
      for (final prompt in prompts) {
        final analysis = classifier.classify(prompt);
        expect(analysis.intent, PromptIntent.howTo, reason: prompt);
        expect(analysis.hardwareGuidance, isTrue, reason: prompt);
        final rendered = FinnInference.instance.renderPromptForTest(
          prompt: prompt,
        );
        expect(rendered, contains('exact manufacturer and model'));
        expect(rendered, contains('service manual'));
        expect(rendered, contains('RAM may be soldered, socketed'));
        expect(rendered, contains('never assume two slots'));
        expect(rendered, contains('electrostatic precautions'));
        expect(rendered, contains('disconnecting external and internal power'));
      }
    },
  );

  test('repeat requests receive an explicit novelty constraint', () {
    final rendered = FinnInference.instance.renderPromptForTest(
      prompt: 'Make a new joke or pun.',
      primed: true,
    );
    expect(rendered, contains('Give a genuinely new response'));
    expect(rendered, contains('Do not repeat an example or answer'));
  });

  test('samplers are factual, chat, and creative intent-sensitive', () {
    final recipe = PromptIntentPolicy.sampler(PromptIntent.recipe);
    final chat = PromptIntentPolicy.sampler(PromptIntent.quickQuestion);
    final creative = PromptIntentPolicy.sampler(PromptIntent.creative);

    expect(recipe.temperature, .30);
    expect(recipe.topK, 30);
    expect(recipe.topP, .90);
    expect(recipe.minP, .05);
    expect(recipe.repeatPenalty, 1.05);
    expect(chat.temperature, .30);
    expect(chat.topP, .90);
    expect(creative.temperature, .85);
    expect(creative.topK, 60);
    expect(creative.topP, .95);
  });

  test('fake generation stream reports an exact token-limit finish', () async {
    final events = Stream<GenerationEvent>.fromIterable([
      TokenEvent(
        id: 1,
        bytes: Uint8List.fromList([65]),
        text: 'A',
        position: 0,
      ),
      const DoneEvent(
        reason: StopMaxTokens(),
        generatedCount: 1,
        committedPosition: 0,
      ),
    ]);

    expect(
      await finishReasonFromEvents(events),
      GenerationFinishReason.tokenLimit,
    );
    expect(
      finishReasonFromStopReason(const StopUserAbort()),
      GenerationFinishReason.userCancellation,
    );
  });

  test(
    'safe Markdown never leaks HTML, router markers, or hidden thinking',
    () {
      final sanitized = SafeMarkdownText.sanitize(
        '<think>private chain</think><FINN_PLUS>'
        '## Result\n[unsafe](javascript:alert(1)) <script>x</script>',
      );

      expect(sanitized, isNot(contains('private chain')));
      expect(sanitized, isNot(contains('FINN_PLUS')));
      expect(sanitized, isNot(contains('javascript:')));
      expect(sanitized, isNot(contains('<script>')));
      expect(sanitized, contains('## Result'));
      expect(sanitized, contains('unsafe'));
    },
  );

  test('safe Markdown keeps HTTPS sources and strips unsafe links', () {
    final sanitized = SafeMarkdownText.sanitize(
      '[Trusted](https://example.com/story) '
      '[Unsafe](javascript:alert(1))',
    );

    expect(sanitized, contains('[Trusted](https://example.com/story)'));
    expect(sanitized, contains('Unsafe'));
    expect(sanitized, isNot(contains('javascript:')));
  });

  test('safe Markdown drops a tag the model never finished', () {
    // Small models echo prompt markup and then stop mid-tag, which used to
    // survive as visible "</Head" text under an otherwise clean answer.
    expect(
      SafeMarkdownText.sanitize('2026 FIFA World Cup</Head'),
      '2026 FIFA World Cup',
    );
    expect(SafeMarkdownText.sanitize('Titles</h1'), 'Titles');
    expect(SafeMarkdownText.sanitize('Done</p>'), 'Done');
  });

  test('safe Markdown leaves ordinary angle brackets alone', () {
    // Only a tag-shaped trailing fragment is markup; prose comparisons are not.
    expect(SafeMarkdownText.sanitize('5 < 7 apples'), '5 < 7 apples');
    expect(SafeMarkdownText.sanitize('a < b and c'), 'a < b and c');
    expect(SafeMarkdownText.sanitize('Titles</'), 'Titles</');
  });

  group('search decision turn is grammar-constrained', () {
    // The decision turn used to rely on the model formatting JSON correctly and
    // only naming tools that exist; malformed output was a normal event that had
    // to be filtered afterwards. A GBNF grammar makes it unrepresentable.
    test('the grammar only allows answering or one known tool call', () {
      final grammar = PromptIntentPolicy.searchDecisionGrammar(
        requireToolCall: false,
      );

      expect(grammar, contains(r'root ::= answer | call'));
      expect(grammar, contains('"ANSWER."'));
      for (final tool in ['browser_search', 'browser_open', 'browser_find']) {
        expect(grammar, contains('\\"$tool\\"'));
      }
    });

    test('a required tool call has no way to decline', () {
      final grammar = PromptIntentPolicy.searchDecisionGrammar(
        requireToolCall: true,
      );

      expect(grammar, contains(r'root ::= call'));
      expect(grammar, isNot(contains('ANSWER')));
      expect(grammar, isNot(contains('answer')));
    });

    test('every rule the grammar references is defined', () {
      // A rule name nothing defines makes llama.cpp fail to compile the
      // grammar, which now degrades to unconstrained sampling — but the turn
      // still loses its constraint, so the reference stays pinned.
      for (final requireToolCall in [true, false]) {
        final grammar = PromptIntentPolicy.searchDecisionGrammar(
          requireToolCall: requireToolCall,
        );
        final defined = RegExp(r'^([a-z][a-z0-9-]*)\s*::=', multiLine: true)
            .allMatches(grammar)
            .map((m) => m.group(1)!)
            .toSet();
        final referenced = RegExp(r'[a-z][a-z0-9-]*')
            .allMatches(
              grammar
                  // Character classes first, then quoted literals (which may
                  // contain escaped quotes), then rule headers: what is left is
                  // the non-terminal names.
                  .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
                  .replaceAll(RegExp(r'"(?:\\.|[^"\\])*"'), ' ')
                  .replaceAll(
                    RegExp(r'^[a-z][a-z0-9-]*\s*::=', multiLine: true),
                    ' ',
                  ),
            )
            .map((m) => m.group(0)!)
            .toSet();

        expect(defined, isNotEmpty);
        expect(
          referenced.difference(defined),
          isEmpty,
          reason: 'undefined rule(s) in the decision grammar',
        );
      }
    });

    test('the grammar and the directive name the same tools', () {
      final directive = PromptIntentPolicy.searchDecisionDirectiveFor(
        PromptLanguage.english,
      );
      final grammar = PromptIntentPolicy.searchDecisionGrammar(
        requireToolCall: false,
      );

      for (final tool in ['browser_search', 'browser_open', 'browser_find']) {
        expect(directive, contains(tool));
        expect(grammar, contains(tool));
      }
    });

    test('the decision sampler follows the grammar flag, and it is off', () {
      // The pinned llama.cpp rejects this grammar (see
      // docs/architecture/CHAT_GENERATION_ARCHITECTURE.md): the runtime guard
      // keeps a rejected grammar from killing the process, and this flag keeps
      // the grammar out of the default build until it is proven.
      expect(PromptIntentPolicy.decisionGrammarEnabled, isFalse);
      for (final requireToolCall in [true, false]) {
        expect(
          PromptIntentPolicy.searchDecisionSampler(
            requireToolCall: requireToolCall,
          ).params.grammar.enabled,
          isFalse,
        );
      }
    });

    test('ordinary turns are left unconstrained', () {
      // Grammar is opt-in per turn: chat, creative and JSON-free paths must
      // sample exactly as they did before.
      for (final intent in PromptIntent.values) {
        expect(
          PromptIntentPolicy.sampler(intent).params.grammar.enabled,
          isFalse,
          reason: '$intent must not be grammar-constrained',
        );
      }
    });
  });
}
