import 'dart:typed_data';

import 'package:finn_ai/src/inference/bonsai_inference.dart';
import 'package:finn_ai/src/inference/prompt_intent.dart';
import 'package:finn_ai/src/widgets/safe_markdown_text.dart';
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

  test(
    'intent routing promotes structured work without promoting greetings',
    () {
      final inference = BonsaiInference.instance;
      expect(inference.fastRouteForTest('Ciao'), BonsaiTier.lite);
      expect(
        inference.fastRouteForTest('Come preparare una pizza margherita?'),
        BonsaiTier.plus,
      );
      expect(
        inference.fastRouteForTest(
          'Come preparare una pizza margherita?',
          highestTier: BonsaiTier.lite,
        ),
        BonsaiTier.lite,
      );
      expect(
        inference.fastRouteForTest('Compare the two implementations.'),
        BonsaiTier.plus,
      );
      expect(
        inference.fastRouteForTest(
          'Perform an advanced security audit with deep reasoning.',
          highestTier: BonsaiTier.pro,
        ),
        BonsaiTier.pro,
      );
    },
  );

  test('intent budgets use tier ceilings and unsupported-device guard', () {
    final inference = BonsaiInference.instance;
    expect(inference.outputBudgetForTest('Hello'), 96);
    expect(
      inference.outputBudgetForTest(
        'Come fare una torta di ricotta e fragole?',
      ),
      320,
    );
    expect(
      inference.outputBudgetForTest(
        'Write a careful comparison.',
        tier: BonsaiTier.plus,
      ),
      512,
    );
    expect(
      inference.outputBudgetForTest(
        'Analyze this complex program.',
        tier: BonsaiTier.pro,
      ),
      768,
    );
    expect(
      inference.outputBudgetForTest(
        'Come fare una torta di ricotta e fragole?',
        supported: false,
      ),
      160,
    );
  });

  test('recipe prompt contract is Italian, structured, and private-aware', () {
    final rendered = BonsaiInference.instance.renderPromptForTest(
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
      rendered.indexOf(BonsaiInference.finnSafetySystemPrompt.trim()),
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
        final rendered = BonsaiInference.instance.renderPromptForTest(
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

  test('samplers are factual, chat, and creative intent-sensitive', () {
    final recipe = PromptIntentPolicy.sampler(PromptIntent.recipe);
    final chat = PromptIntentPolicy.sampler(PromptIntent.quickQuestion);
    final creative = PromptIntentPolicy.sampler(PromptIntent.creative);

    expect(recipe.temperature, .30);
    expect(recipe.topK, 20);
    expect(recipe.topP, .85);
    expect(recipe.minP, .02);
    expect(recipe.repeatPenalty, 1.05);
    expect(chat.temperature, .50);
    expect(chat.topP, .90);
    expect(creative.temperature, .70);
    expect(creative.topK, 40);
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
}
