import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/creation_prompts.dart';
import 'package:finn_ai/src/features/creations/spec/deck_theme.dart';
import 'package:finn_ai/src/features/creations/spec/spec_limits.dart';
import 'package:finn_ai/src/features/creations/templates/slot_prompt.dart';
import 'package:finn_ai/src/features/creations/templates/template_catalog.dart';
import 'package:finn_ai/src/features/creations/templates/template_slots.dart';

/// A rule the model was never told is a rule it can only fail by accident, so
/// every limit the sanitiser or validator enforces has to be in the prompt.
void main() {
  group('slot prompts', () {
    for (final template in CreationTemplates.all) {
      test('${template.id}: names every key and every limit', () {
        final prompt = SlotPrompt.build(template: template, brief: 'a brief');
        for (final slot in template.slots) {
          expect(prompt, contains('- ${slot.key}:'), reason: slot.key);
          switch (slot.kind) {
            case SlotKind.text:
              expect(prompt, contains('at most ${slot.maxChars} characters'));
            case SlotKind.integer:
              expect(prompt,
                  contains('from ${slot.minValue} to ${slot.maxValue}'));
            case SlotKind.list:
              expect(prompt,
                  contains('${slot.minItems} to ${slot.maxItems} items'));
            default:
              break;
          }
        }
      });

      test('${template.id}: the brief closes the prompt, after the shape', () {
        final prompt = SlotPrompt.build(template: template, brief: 'a brief');
        expect(
          prompt.indexOf('Brief: "a brief"'),
          greaterThan(prompt.indexOf('{"')),
        );
        expect(prompt.trimRight().endsWith('nothing else.'), isTrue);
        expect(prompt, contains('only show the shape'));
      });
    }

    test('the accent slot lists the colour words, not a pipe-joined value', () {
      final prompt = SlotPrompt.build(
        template: CreationTemplates.byId('counter')!,
        brief: 'x',
      );
      for (final accent in SpecLimits.accentNames.split(', ')) {
        expect(prompt, contains(accent), reason: accent);
      }
      expect(prompt, isNot(contains('mint|blue')));
    });

    test('a repair note is quoted before the brief', () {
      final prompt = SlotPrompt.build(
        template: CreationTemplates.byId('list')!,
        brief: 'a list',
        repairNote: 'it was not a JSON object',
      );
      expect(prompt, contains('it was not a JSON object'));
      expect(
        prompt.indexOf('it was not a JSON object'),
        lessThan(prompt.indexOf('Brief: "a list"')),
      );
    });
  });

  group('deck prompt', () {
    final prompt = CreationPrompts.build(brief: 'a brief');

    test('states the deck limits and the closed theme and layout lists', () {
      expect(prompt, contains('${SpecLimits.maxSlides}'));
      expect(prompt, contains('${SpecLimits.maxBulletsPerSlide}'));
      expect(prompt, contains('${SpecLimits.maxBulletChars}'));
      expect(prompt, contains(DeckTheme.names));
      expect(prompt, contains(DeckLayout.names));
    });

    test('the brief closes the prompt, after the worked example', () {
      expect(
        prompt.indexOf('Brief: "a brief"'),
        greaterThan(prompt.lastIndexOf('{"title"')),
      );
      expect(prompt, contains('Do not reuse anything from the Example'));
      expect(prompt.trimRight().endsWith('nothing else.'), isTrue);
    });

    test('a repair round quotes the issues before the brief', () {
      final repair = CreationPrompts.build(
        brief: 'a deck',
        repairIssues: '"slides" must be a non-empty list',
      );
      expect(
        repair.indexOf('"slides" must be a non-empty list'),
        lessThan(repair.indexOf('Brief: "a deck"')),
      );
    });
  });
}
