import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/spec/spec_validator.dart';
import 'package:finn_ai/src/features/creations/spec/widget_spec.dart';
import 'package:finn_ai/src/features/creations/templates/template_catalog.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';

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
      expect(
        SpecValidator.validateHomeWidget(_spec(kind: 'counter')),
        isEmpty,
      );
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

  group('widget templates', () {
    HomeWidgetSpec built(String id, [Map<String, Object?> raw = const {}]) {
      final template = CreationTemplates.byId(id)!;
      final values = SlotSanitizer.sanitize(template.slots, raw);
      return (template.build(values) as WidgetArtifact).spec;
    }

    test('the interactive ones build the kind they promise', () {
      expect(built('counter_widget').kind, HomeWidgetKind.counter);
      expect(built('checklist_widget').kind, HomeWidgetKind.checklist);
      expect(built('tracker_widget').kind, HomeWidgetKind.tracker);
      expect(built('stat').kind, HomeWidgetKind.display);
    });

    test('a counter carries its goal and step', () {
      final spec = built('counter_widget', {'goal': 8, 'step': 2, 'value': 1});
      expect(spec.goal, 8);
      expect(spec.step, 2);
      expect(spec.rows.single.number, 1);
    });

    test('a checklist has the items as rows', () {
      final spec = built('checklist_widget', {
        'items': ['Stretch', 'Vitamins', 'Plan'],
      });
      expect(spec.rows.map((r) => r.label), ['Stretch', 'Vitamins', 'Plan']);
    });

    test('a tracker starts every row at zero', () {
      final spec = built('tracker_widget', {
        'items': ['Run', 'Read'],
      });
      expect(spec.rows.map((r) => r.number), [0, 0]);
    });

    test('a vague brief gets something you can touch', () {
      expect(
        CreationTemplates.pick(CreationKind.widget, 'a widget for my home').id,
        'counter_widget',
      );
    });

    test('the brief picks the right interactive widget', () {
      String pick(String brief) =>
          CreationTemplates.pick(CreationKind.widget, brief).id;
      expect(pick('count my glasses of water'), 'counter_widget');
      expect(pick('a morning routine checklist'), 'checklist_widget');
      expect(pick('habit tracker'), 'tracker_widget');
      expect(pick('countdown to my birthday'), 'stat');
    });
  });
}
