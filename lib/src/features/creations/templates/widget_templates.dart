import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/spec/widget_spec.dart';
import 'package:finn_ai/src/features/creations/spec/spec_limits.dart';
import 'package:finn_ai/src/features/creations/templates/creation_template.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';

const _accent = TemplateSlot(
  'accent',
  SlotKind.choice,
  options: SpecLimits.accentList,
  fallback: 'sky',
  example: 'mint',
  description: 'one colour word: mint, blue, lime, amber, rose, violet or sky',
);

const _footer = TemplateSlot(
  'footer',
  SlotKind.text,
  fallback: 'Tap to open',
  example: 'Updated today',
  description: 'a few words at the bottom',
  maxChars: 30,
);

CreationArtifact _widget(
  String title,
  String accent,
  List<Map<String, Object?>> rows,
  String footer, {
  HomeWidgetKind kind = HomeWidgetKind.display,
  int step = 1,
  int goal = 0,
}) =>
    WidgetArtifact(
      HomeWidgetSpec.fromJson({
        'title': title,
        'accent': accent,
        'rows': rows,
        'footer': footer,
        'kind': kind.name,
        'step': step,
        'goal': goal,
      }),
    );

const _widgetTitle = TemplateSlot(
  'title',
  SlotKind.text,
  fallback: 'My widget',
  example: 'Water',
  description: 'a short name',
  maxChars: 30,
);

const _step = TemplateSlot(
  'step',
  SlotKind.integer,
  fallback: 1,
  example: 1,
  description: 'how much one tap adds, usually 1',
  minValue: 1,
  maxValue: 100,
);

/// A number you change from the home screen: minus and plus buttons, and an
/// optional goal with a progress bar.
class CounterWidgetTemplate extends CreationTemplate {
  const CounterWidgetTemplate();

  @override
  String get id => 'counter_widget';
  @override
  CreationKind get kind => CreationKind.widget;
  @override
  String get englishName => 'counter widget';
  @override
  String get purpose =>
      'a number with plus and minus buttons, like cups of water or reps';

  @override
  List<TemplateSlot> get slots => const [
        _widgetTitle,
        TemplateSlot(
          'label',
          SlotKind.text,
          fallback: 'Today',
          example: 'Cups today',
          description: 'what is being counted, a few words',
          maxChars: 24,
        ),
        TemplateSlot(
          'value',
          SlotKind.integer,
          fallback: 0,
          example: 0,
          description: 'the starting number, usually 0',
          minValue: 0,
          maxValue: 99999,
        ),
        _step,
        TemplateSlot(
          'goal',
          SlotKind.integer,
          fallback: 0,
          example: 8,
          description: 'the target number, or 0 for no target',
          minValue: 0,
          maxValue: 99999,
        ),
        _footer,
        _accent,
      ];

  @override
  List<String> get keywords => const [
        'counter',
        'count',
        'tally',
        'clicker',
        'streak',
        'water',
        'glasses',
        'cups',
        'reps',
        'laps',
        'pushups',
        'push-ups',
        'steps',
        'contatore',
        'conteggio',
        'contador',
        'compteur',
        'zähler',
        'racha',
        'serie',
      ];

  @override
  CreationArtifact build(SlotValues v) => _widget(
        titleFor(v),
        v.text('accent'),
        [
          {'label': v.text('label'), 'value': '${v.integer('value')}'},
        ],
        v.text('footer'),
        kind: HomeWidgetKind.counter,
        step: v.integer('step'),
        goal: v.integer('goal'),
      );
}

/// Up to four things to tick off, straight from the home screen.
class ChecklistWidgetTemplate extends CreationTemplate {
  const ChecklistWidgetTemplate();

  @override
  String get id => 'checklist_widget';
  @override
  CreationKind get kind => CreationKind.widget;
  @override
  String get englishName => 'checklist widget';
  @override
  String get purpose => 'up to four things to tick off, like a morning routine';

  @override
  List<TemplateSlot> get slots => const [
        TemplateSlot(
          'title',
          SlotKind.text,
          fallback: 'My checklist',
          example: 'Morning routine',
          description: 'a short name',
          maxChars: 30,
        ),
        TemplateSlot(
          'items',
          SlotKind.list,
          fallback: <String>['First thing', 'Second thing'],
          example: <String>['Stretch', 'Take vitamins', 'Plan the day'],
          description: 'between 1 and 4 things to tick off, a few words each',
          maxChars: 28,
          maxItems: 4,
          minItems: 1,
        ),
        _footer,
        _accent,
      ];

  @override
  List<String> get keywords => const [
        'checklist',
        'todo',
        'to-do',
        'task',
        'tasks',
        'chores',
        'routine',
        'groceries',
        'shopping',
        'packing',
        'lista',
        'compiti',
        'spesa',
        'tareas',
        'compras',
        'courses',
        'einkauf',
        'aufgaben',
      ];

  @override
  CreationArtifact build(SlotValues v) => _widget(
        titleFor(v),
        v.text('accent'),
        [
          for (final item in v.list('items')) {'label': item, 'value': ''},
        ],
        v.text('footer'),
        kind: HomeWidgetKind.checklist,
      );
}

/// Up to four named numbers; tapping a line adds one.
class TrackerWidgetTemplate extends CreationTemplate {
  const TrackerWidgetTemplate();

  @override
  String get id => 'tracker_widget';
  @override
  CreationKind get kind => CreationKind.widget;
  @override
  String get englishName => 'tracker widget';
  @override
  String get purpose =>
      'up to four named numbers you add to by tapping, like a habit log';

  @override
  List<TemplateSlot> get slots => const [
        TemplateSlot(
          'title',
          SlotKind.text,
          fallback: 'My tracker',
          example: 'Habits this week',
          description: 'a short name',
          maxChars: 30,
        ),
        TemplateSlot(
          'items',
          SlotKind.list,
          fallback: <String>['Workout', 'Reading'],
          example: <String>['Workout', 'Reading', 'Meditate'],
          description: 'between 1 and 4 things to count, a few words each',
          maxChars: 22,
          maxItems: 4,
          minItems: 1,
        ),
        _step,
        _footer,
        _accent,
      ];

  @override
  List<String> get keywords => const [
        'tracker',
        'track',
        'log',
        'habit',
        'habits',
        'score',
        'scores',
        'scoreboard',
        'tracciare',
        'abitudini',
        'seguimiento',
        'hábitos',
        'habitos',
        'suivi',
        'habitudes',
        'gewohnheiten',
      ];

  @override
  CreationArtifact build(SlotValues v) => _widget(
        titleFor(v),
        v.text('accent'),
        [
          for (final item in v.list('items')) {'label': item, 'value': '0'},
        ],
        v.text('footer'),
        kind: HomeWidgetKind.tracker,
        step: v.integer('step'),
      );
}

/// One big number with a label: a countdown, a streak, a balance.
class StatWidgetTemplate extends CreationTemplate {
  const StatWidgetTemplate();

  @override
  String get id => 'stat';
  @override
  CreationKind get kind => CreationKind.widget;
  @override
  String get englishName => 'single number display widget';
  @override
  String get purpose =>
      'one big number to look at, like a countdown or a balance';

  @override
  List<TemplateSlot> get slots => const [
        TemplateSlot(
          'title',
          SlotKind.text,
          fallback: 'My widget',
          example: 'Reading streak',
          description: 'a short name',
          maxChars: 30,
        ),
        TemplateSlot(
          'label',
          SlotKind.text,
          fallback: 'Today',
          example: 'Days in a row',
          description: 'what the number means, a few words',
          maxChars: 24,
        ),
        TemplateSlot(
          'value',
          SlotKind.text,
          fallback: '0',
          example: '12',
          description: 'the number or a very short value',
          maxChars: 18,
        ),
        _footer,
        _accent,
      ];

  @override
  List<String> get keywords => const [
        'countdown',
        'days',
        'number',
        'stat',
        'balance',
        'giorni',
        'conto alla rovescia',
        'días',
        'dias',
        'jours',
        'tage',
      ];

  @override
  CreationArtifact build(SlotValues v) => _widget(
        titleFor(v),
        v.text('accent'),
        [
          {'label': v.text('label'), 'value': v.text('value')},
        ],
        v.text('footer'),
      );
}

/// Up to four label/value lines: a day plan, a scoreboard, a few stats.
class RowsWidgetTemplate extends CreationTemplate {
  const RowsWidgetTemplate();

  @override
  String get id => 'rows';
  @override
  CreationKind get kind => CreationKind.widget;
  @override
  String get englishName => 'list widget';
  @override
  String get purpose => 'up to four short label: value lines';

  @override
  List<TemplateSlot> get slots => const [
        TemplateSlot(
          'title',
          SlotKind.text,
          fallback: 'My widget',
          example: 'Today',
          description: 'a short name',
          maxChars: 30,
        ),
        TemplateSlot(
          'rows',
          SlotKind.list,
          fallback: <String>['Today: 0', 'Goal: 1'],
          example: <String>['Water: 3', 'Steps: 4000'],
          description: 'between 1 and 4 lines, each written "Label: value"',
          maxChars: 40,
          maxItems: 4,
          minItems: 1,
        ),
        _footer,
        _accent,
      ];

  @override
  List<String> get keywords => const [
        'plan',
        'schedule',
        'today',
        'stats',
        'list',
        'agenda',
        'oggi',
        'programma',
        'hoy',
        'agenda',
        "aujourd'hui",
        'heute',
      ];

  @override
  CreationArtifact build(SlotValues v) {
    final rows = <Map<String, Object?>>[];
    for (final line in v.list('rows')) {
      final split = line.indexOf(':');
      final label = split < 0 ? line : line.substring(0, split).trim();
      final value = split < 0 ? '' : line.substring(split + 1).trim();
      rows.add({
        'label': label.isEmpty ? line : label,
        'value': value.length > 18 ? value.substring(0, 18).trimRight() : value,
      });
    }
    return _widget(titleFor(v), v.text('accent'), rows, v.text('footer'));
  }
}
