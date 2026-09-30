import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_state.dart';
import 'package:finn_ai/src/features/creations/spec/deck_theme.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/spec_validator.dart';
import 'package:finn_ai/src/features/creations/templates/template_catalog.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';

Map<String, Object?> _fuzz(Random random, List<TemplateSlot> slots) {
  Object? junk() => switch (random.nextInt(9)) {
        0 => null,
        1 => '',
        2 => '   ',
        3 => 'x' * random.nextInt(300),
        4 => '{count}{{a}} \u0007\n\t ${random.nextInt(1000)}',
        5 => random.nextInt(2000000) - 1000000,
        6 => random.nextDouble() * 1e9,
        7 => [
            for (var i = 0; i < random.nextInt(20); i++)
              'item ${random.nextInt(5)}'
          ],
        _ => '💧🔥✨ ${random.nextInt(50)}',
      };
  return {
    for (final slot in slots)
      if (random.nextInt(5) != 0) slot.key: junk(),
  };
}

List<SpecIssue> _validate(CreationArtifact artifact) => switch (artifact) {
      MiniAppArtifact(:final spec) =>
        SpecValidator.validateMiniApp(spec.toJson()),
      WidgetArtifact(:final spec) =>
        SpecValidator.validateHomeWidget(spec.toJson()),
      _ => const [],
    };

void main() {
  group('every template is valid by construction', () {
    for (final template in CreationTemplates.all) {
      test('${template.id}: fallback values', () {
        final values = SlotSanitizer.sanitize(template.slots, const {});
        expect(_validate(template.build(values)), isEmpty);
      });

      test('${template.id}: the prompt examples', () {
        final values = SlotSanitizer.sanitize(template.slots, {
          for (final slot in template.slots) slot.key: slot.example,
        });
        expect(_validate(template.build(values)), isEmpty);
      });

      test('${template.id}: 300 rounds of hostile input', () {
        final random = Random(template.id.hashCode);
        for (var round = 0; round < 300; round++) {
          final raw = _fuzz(random, template.slots);
          final values = SlotSanitizer.sanitize(template.slots, raw);
          final artifact = template.build(values);
          final issues = _validate(artifact);
          expect(issues, isEmpty, reason: 'round $round input $raw');
          expect(template.titleFor(values).trim(), isNotEmpty);
        }
      });
    }
  });

  group('built apps actually run', () {
    for (final template in CreationTemplates.forKind(CreationKind.app)) {
      test('${template.id}: every button can be pressed', () {
        final values = SlotSanitizer.sanitize(template.slots, const {});
        final spec = (template.build(values) as MiniAppArtifact).spec;
        final state = MiniAppState(spec);
        void press(MiniAppNode node) {
          if (node is ButtonNode) state.dispatch(node.action);
          if (node is ContainerNode) node.children.forEach(press);
        }

        spec.nodes.forEach(press);
        spec.nodes.forEach(press);
        expect(state.values, isNotNull);
      });
    }

    test('the counter counts and the list collects', () {
      final counter = CreationTemplates.byId('counter')!;
      final spec = (counter.build(
        SlotSanitizer.sanitize(counter.slots, const {}),
      ) as MiniAppArtifact)
          .spec;
      final state = MiniAppState(spec);
      final plus =
          ((spec.nodes[3] as ContainerNode).children[0] as ButtonNode).action;
      state
        ..dispatch(plus)
        ..dispatch(plus);
      expect(state.valueOf('count'), 2);

      final list = CreationTemplates.byId('list')!;
      final listSpec = (list.build(
        SlotSanitizer.sanitize(list.slots, const {}),
      ) as MiniAppArtifact)
          .spec;
      final listState = MiniAppState(listSpec)..setValue('draft', 'bread');
      listState.dispatch((listSpec.nodes[1] as ButtonNode).action);
      expect(listState.valueOf('items'), ['bread']);
    });
  });

  group('the app picks the template from the brief', () {
    final cases = <String, String>{
      'a shopping list for the week': 'list',
      'lista della spesa': 'list',
      'una lista de compras': 'list',
      'Einkaufsliste': 'list',
      'keep score in our board game night': 'scoreboard',
      'punteggio della partita': 'scoreboard',
      'count how many glasses of water I drink': 'counter',
      'track my daily steps goal': 'counter',
      'a morning routine checklist': 'checklist',
      'abitudini da spuntare': 'checklist',
      'something I cannot describe': 'counter',
    };
    cases.forEach((brief, expected) {
      test('"$brief" → $expected', () {
        expect(
          CreationTemplates.pick(CreationKind.app, brief).id,
          expected,
        );
      });
    });

    test('keywords match whole words only', () {
      // "specialist" contains "list" but is not a list.
      expect(
        CreationTemplates.pick(CreationKind.app, 'a specialist timer').id,
        'counter',
      );
    });

    test('widgets pick among widget templates only', () {
      for (final brief in ['a streak', 'today plan', 'anything']) {
        expect(
          CreationTemplates.pick(CreationKind.widget, brief).kind,
          CreationKind.widget,
        );
      }
    });
  });

  group('slot sanitiser', () {
    const slots = [
      TemplateSlot('t', SlotKind.text,
          fallback: 'F', example: 'e', maxChars: 5),
      TemplateSlot(
        'n',
        SlotKind.integer,
        fallback: 3,
        example: 4,
        minValue: 1,
        maxValue: 9,
      ),
      TemplateSlot(
        'l',
        SlotKind.list,
        fallback: <String>['a', 'b'],
        example: <String>['c', 'd'],
        maxItems: 3,
        minItems: 2,
      ),
      TemplateSlot(
        'c',
        SlotKind.choice,
        fallback: 'one',
        example: 'two',
        options: ['one', 'two'],
      ),
    ];

    test('clamps, dedupes and falls back', () {
      final values = SlotSanitizer.sanitize(slots, {
        't': '  hello   world ',
        'n': '99',
        'l': ['x', 'X', 'y', 'z', 'w'],
        'c': 'TWO',
      });
      expect(values.text('t'), 'hello');
      expect(values.integer('n'), 9);
      expect(values.list('l'), ['x', 'y', 'z']);
      expect(values.text('c'), 'two');
    });

    test('a list below its minimum takes the fallback list', () {
      final values = SlotSanitizer.sanitize(slots, {
        'l': ['only one']
      });
      expect(values.list('l'), ['a', 'b']);
    });

    test('a newline-separated string is accepted as a list', () {
      final values = SlotSanitizer.sanitize(slots, {'l': 'a\nb\nc'});
      expect(values.list('l'), ['a', 'b', 'c']);
    });

    test('usable counts only slots the model actually filled', () {
      expect(SlotSanitizer.usable(slots, const {}), 0);
      expect(SlotSanitizer.usable(slots, {'t': 'hi'}), 1);
    });
  });

  group('creation records', () {
    test('a template reference survives a JSON round trip', () {
      final template = CreationTemplates.byId('counter')!;
      final values = SlotSanitizer.sanitize(template.slots, {'goal': 7});
      final creation = FinnCreation(
        id: '1',
        prompt: 'p',
        title: 'T',
        summary: '',
        artifact: template.build(values),
        createdAt: DateTime.utc(2026, 1, 1),
        template: TemplateRef(id: template.id, slots: values.toJson()),
      );
      final restored = FinnCreation.fromJson(creation.toJson());
      expect(restored.template?.id, 'counter');
      expect(restored.template?.slots['goal'], 7);
    });

    test('an old record with no template still loads', () {
      final json = FinnCreation(
        id: '1',
        prompt: 'p',
        title: 'T',
        summary: '',
        artifact: CreationTemplates.byId('counter')!.build(
          SlotSanitizer.sanitize(
            CreationTemplates.byId('counter')!.slots,
            const {},
          ),
        ),
        createdAt: DateTime.utc(2026, 1, 1),
      ).toJson();
      expect(json.containsKey('template'), isFalse);
      expect(FinnCreation.fromJson(json).template, isNull);
    });
  });

  group('deck themes are legible', () {
    for (final theme in DeckTheme.values) {
      test('${theme.name}: text and muted text on the background', () {
        expect(DeckTheme.contrast(theme.text, theme.background),
            greaterThanOrEqualTo(7));
        expect(DeckTheme.contrast(theme.muted, theme.background),
            greaterThanOrEqualTo(4.5));
        // The accent colours bars, bullets and section titles.
        expect(DeckTheme.contrast(theme.accent, theme.background),
            greaterThanOrEqualTo(3));
      });
    }

    test('an unknown theme is the default, not an error', () {
      expect(DeckTheme.parse('plaid'), DeckTheme.paper);
      expect(DeckTheme.parse(null), DeckTheme.paper);
    });
  });
}
