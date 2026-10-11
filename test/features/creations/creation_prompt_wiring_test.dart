import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_prompts.dart';
import 'package:finn_ai/src/features/creations/spec/deck_theme.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/spec_limits.dart';

/// A rule the model was never told is a rule it can only fail by accident, so
/// every limit the validator enforces has to be in the prompt too.
void main() {
  for (final kind in CreationKind.values) {
    final prompt = CreationPrompts.build(kind: kind, brief: 'a brief');

    test('${kind.name}: states the title cap and closes on the brief', () {
      expect(prompt, contains('${SpecLimits.maxTitleChars}'));
      expect(prompt.trimRight().endsWith('nothing else.'), isTrue);
    });

    test('${kind.name}: the brief closes the prompt, after the format', () {
      expect(
        prompt.indexOf('Brief: "a brief"'),
        greaterThan(prompt.indexOf('{"')),
      );
    });
  }

  test('the mini-app prompt documents every node type', () {
    final prompt = CreationPrompts.build(kind: CreationKind.app, brief: 'x');
    for (final type in MiniAppNodeType.values) {
      expect(prompt, contains(type.name), reason: type.name);
    }
  });

  test('the mini-app prompt documents every action', () {
    final prompt = CreationPrompts.build(kind: CreationKind.app, brief: 'x');
    for (final action in ['set', 'toggle', 'increment', 'append', 'reset']) {
      expect(prompt, contains('"kind":"$action"'), reason: action);
    }
  });

  test('the mini-app prompt states the node and depth caps and the accents',
      () {
    final prompt = CreationPrompts.build(kind: CreationKind.app, brief: 'x');
    expect(prompt, contains('${SpecLimits.maxNodes} nodes'));
    expect(prompt, contains('${SpecLimits.maxNodeDepth} levels'));
    expect(prompt, contains(SpecLimits.accentNames));
  });

  test('the widget prompt states its row cap', () {
    final prompt = CreationPrompts.build(kind: CreationKind.widget, brief: 'x');
    expect(prompt, contains('${SpecLimits.maxWidgetRows} rows'));
    expect(prompt, contains(SpecLimits.accentNames));
    for (final kind in ['display', 'counter', 'checklist', 'tracker']) {
      expect(prompt, contains(kind), reason: kind);
    }
  });

  test('the deck prompt lists the closed themes and layouts', () {
    final prompt = CreationPrompts.build(
      kind: CreationKind.presentation,
      brief: 'x',
    );
    expect(prompt, contains(DeckTheme.names));
    expect(prompt, contains(DeckLayout.names));
    expect(prompt, contains('${SpecLimits.maxSlides} slides'));
  });

  test('a repair round quotes the issues before the brief', () {
    final repair = CreationPrompts.build(
      kind: CreationKind.app,
      brief: 'a list',
      repairIssues: 'nodes[2] must be an object with a "type"',
    );
    expect(repair, contains('rejected for these reasons'));
    expect(
      repair.indexOf('nodes[2] must be an object'),
      lessThan(repair.indexOf('Brief: "a list"')),
    );
  });
}
