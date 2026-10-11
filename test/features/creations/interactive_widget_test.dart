import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/spec/spec_validator.dart';
import 'package:finn_ai/src/features/creations/spec/widget_spec.dart';

Map<String, Object?> _spec({
  String? kind,
  List<Map<String, Object?>>? rows,
  int? step,
  int? goal,
}) =>
    {
      'title': 'Water',
      'accent': 'sky',
      'rows': rows ??
          [
            {'label': 'Cups', 'value': '2'},
          ],
      'footer': 'Today',
      if (kind != null) 'kind': kind,
      if (step != null) 'step': step,
      if (goal != null) 'goal': goal,
    };

void main() {
  group('widget kinds', () {
    test('a widget saved before kinds existed is a display widget', () {
      final spec = HomeWidgetSpec.fromJson(_spec());
      expect(spec.kind, HomeWidgetKind.display);
      expect(spec.kind.interactive, isFalse);
      // And it keeps writing the old shape, so nothing about it changes.
      expect(spec.toJson().containsKey('kind'), isFalse);
    });

    test('kind, step and goal survive a round trip', () {
      final spec = HomeWidgetSpec.fromJson(
        _spec(kind: 'counter', step: 5, goal: 40),
      );
      expect(spec.kind, HomeWidgetKind.counter);
      expect(spec.step, 5);
      expect(spec.goal, 40);
      final again = HomeWidgetSpec.fromJson(spec.toJson());
      expect(again.toJson(), spec.toJson());
    });

    test('a step is never below one and a goal never negative', () {
      final spec = HomeWidgetSpec.fromJson(
        _spec(kind: 'counter', step: -3, goal: -9),
      );
      expect(spec.step, 1);
      expect(spec.goal, 0);
    });

    test('an unknown kind is refused by the validator, not guessed', () {
      expect(
        SpecValidator.validateHomeWidget(_spec(kind: 'slider')),
        isNotEmpty,
      );
    });

    test('a counter has exactly one numeric row', () {
      expect(SpecValidator.validateHomeWidget(_spec(kind: 'counter')), isEmpty);
      expect(
        SpecValidator.validateHomeWidget(
          _spec(
            kind: 'counter',
            rows: [
              {'label': 'Cups', 'value': 'lots'},
            ],
          ),
        ),
        isNotEmpty,
      );
      expect(
        SpecValidator.validateHomeWidget(
          _spec(
            kind: 'counter',
            rows: [
              {'label': 'A', 'value': '1'},
              {'label': 'B', 'value': '2'},
            ],
          ),
        ),
        isNotEmpty,
      );
    });

    test('a tracker needs a number on every row', () {
      expect(
        SpecValidator.validateHomeWidget(
          _spec(
            kind: 'tracker',
            rows: [
              {'label': 'A', 'value': '0'},
              {'label': 'B', 'value': 'x'},
            ],
          ),
        ),
        isNotEmpty,
      );
    });
  });

  group('model-written widget specs', () {
    HomeWidgetSpec built(Map<String, Object?> raw) =>
        HomeWidgetSpec.fromJson(raw);

    test('a display widget is just its rows', () {
      final spec = built(_spec());
      expect(spec.kind, HomeWidgetKind.display);
      expect(spec.rows.single.label, 'Cups');
    });

    test('a counter carries its goal and step', () {
      final spec = built(_spec(kind: 'counter', goal: 8, step: 2));
      expect(spec.kind, HomeWidgetKind.counter);
      expect(spec.goal, 8);
      expect(spec.step, 2);
      expect(spec.rows.single.number, 2);
    });

    test('a checklist puts the model items on its rows', () {
      final spec = built(
        _spec(
          kind: 'checklist',
          rows: [
            {'label': 'Stretch', 'value': ''},
            {'label': 'Vitamins', 'value': ''},
            {'label': 'Plan', 'value': ''},
          ],
        ),
      );
      expect(spec.kind, HomeWidgetKind.checklist);
      expect(spec.rows.map((r) => r.label), ['Stretch', 'Vitamins', 'Plan']);
      expect(SpecValidator.validateHomeWidget(spec.toJson()), isEmpty);
    });

    test('a tracker with a number on every row validates', () {
      final spec = built(
        _spec(
          kind: 'tracker',
          rows: [
            {'label': 'Run', 'value': '0'},
            {'label': 'Read', 'value': '0'},
          ],
        ),
      );
      expect(spec.kind, HomeWidgetKind.tracker);
      expect(spec.rows.map((r) => r.number), [0, 0]);
      expect(SpecValidator.validateHomeWidget(spec.toJson()), isEmpty);
    });

    test('every kind the model may write validates from its own spec', () {
      for (final kind in HomeWidgetKind.values) {
        final raw = kind == HomeWidgetKind.counter
            ? _spec(kind: kind.name, goal: 8)
            : _spec(kind: kind.name);
        expect(
          SpecValidator.validateHomeWidget(raw),
          isEmpty,
          reason: kind.name,
        );
      }
    });
  });
}
