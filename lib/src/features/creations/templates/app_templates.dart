import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/spec_limits.dart';
import 'package:finn_ai/src/features/creations/templates/creation_template.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';

const _titleSlot = TemplateSlot(
  'title',
  SlotKind.text,
  fallback: 'My app',
  example: 'Water tracker',
  description: 'a short name for the app',
  maxChars: 40,
);

const _accentSlot = TemplateSlot(
  'accent',
  SlotKind.choice,
  options: SpecLimits.accentList,
  fallback: 'mint',
  example: 'sky',
  description: 'one colour word: mint, blue, lime, amber, rose, violet or sky',
);

CreationArtifact _app(
        String title, String accent, List<Map<String, Object?>> nodes) =>
    MiniAppArtifact(
      MiniAppSpec.fromJson({'title': title, 'accent': accent, 'nodes': nodes}),
    );

/// A number that goes up and down towards a goal: water, steps, reps, pages.
class CounterTemplate extends CreationTemplate {
  const CounterTemplate();

  @override
  String get id => 'counter';
  @override
  CreationKind get kind => CreationKind.app;
  @override
  String get englishName => 'counter with a goal';
  @override
  String get purpose => 'a number the user taps up and down towards a goal';

  @override
  List<TemplateSlot> get slots => const [
        _titleSlot,
        TemplateSlot(
          'unit',
          SlotKind.text,
          fallback: 'Count',
          example: 'Glasses',
          description: 'what is being counted, one or two words',
          maxChars: 20,
        ),
        TemplateSlot(
          'goal',
          SlotKind.integer,
          fallback: 10,
          example: 8,
          description: 'the target, a whole number from 1 to 500',
          minValue: 1,
          maxValue: 500,
        ),
        TemplateSlot(
          'emoji',
          SlotKind.emoji,
          fallback: '✨',
          example: '💧',
          description: 'one emoji that suits it',
        ),
        _accentSlot,
      ];

  @override
  List<String> get keywords => const [
        'count',
        'counter',
        'tally',
        'track',
        'goal',
        'steps',
        'glasses',
        'water',
        'reps',
        'pages',
        'habit count',
        'conta',
        'contatore',
        'contador',
        'compteur',
        'zähler',
        'zahler',
        'obiettivo',
        'objetivo',
        'objectif',
        'ziel',
      ];

  @override
  CreationArtifact build(SlotValues v) => _app(
        titleFor(v),
        v.text('accent'),
        [
          {'type': 'image', 'emoji': v.text('emoji')},
          {
            'type': 'text',
            'value': '${v.text('unit')}: {count}',
            'style': 'title',
          },
          {'type': 'progress', 'bind': 'count', 'max': v.integer('goal')},
          {
            'type': 'row',
            'children': [
              {
                'type': 'button',
                'label': '+1',
                'action': {'kind': 'increment', 'key': 'count', 'by': 1},
              },
              {
                'type': 'button',
                'label': '-1',
                'action': {'kind': 'increment', 'key': 'count', 'by': -1},
              },
            ],
          },
          {
            'type': 'button',
            'label': 'Reset',
            'action': {'kind': 'reset'},
          },
        ],
      );

  @override
  String summaryFor(SlotValues values) =>
      '${values.text('unit')}, goal ${values.integer('goal')}';
}

/// A set of things to tick off: a habit list, packing list, morning routine.
class ChecklistTemplate extends CreationTemplate {
  const ChecklistTemplate();

  @override
  String get id => 'checklist';
  @override
  CreationKind get kind => CreationKind.app;
  @override
  String get englishName => 'checklist';
  @override
  String get purpose => 'a short list of things the user ticks off';

  @override
  List<TemplateSlot> get slots => const [
        _titleSlot,
        TemplateSlot(
          'items',
          SlotKind.list,
          fallback: <String>['First thing', 'Second thing', 'Third thing'],
          example: <String>['Wake up', 'Stretch', 'Read'],
          description: 'between 2 and 8 short things to tick off',
          maxChars: 40,
          maxItems: 8,
          minItems: 2,
        ),
        _accentSlot,
      ];

  @override
  List<String> get keywords => const [
        'checklist',
        'check list',
        'to-do',
        'todo',
        'to do',
        'routine',
        'habit',
        'packing',
        'steps',
        'tasks',
        'lista di controllo',
        'abitudini',
        'routine',
        'hábitos',
        'habitos',
        'rutina',
        'liste de contrôle',
        'habitudes',
        'checkliste',
        'gewohnheiten',
        'aufgaben',
      ];

  @override
  CreationArtifact build(SlotValues v) {
    final items = v.list('items');
    return _app(
      titleFor(v),
      v.text('accent'),
      [
        for (var i = 0; i < items.length; i++)
          {'type': 'toggle', 'key': 'item${i + 1}', 'label': items[i]},
        {
          'type': 'button',
          'label': 'Clear all',
          'action': {'kind': 'reset'},
        },
      ],
    );
  }

  @override
  String summaryFor(SlotValues values) =>
      '${values.list('items').length} items';
}

/// Things typed in and collected: shopping, notes, ideas.
class ListTemplate extends CreationTemplate {
  const ListTemplate();

  @override
  String get id => 'list';
  @override
  CreationKind get kind => CreationKind.app;
  @override
  String get englishName => 'list the user adds to';
  @override
  String get purpose =>
      'a list the user types items into, like shopping or notes';

  @override
  List<TemplateSlot> get slots => const [
        _titleSlot,
        TemplateSlot(
          'hint',
          SlotKind.text,
          fallback: 'Add an item',
          example: 'Type an idea',
          description: 'the grey prompt inside the input box',
          maxChars: 40,
        ),
        TemplateSlot(
          'empty',
          SlotKind.text,
          fallback: 'Nothing yet',
          example: 'No ideas yet',
          description: 'what to show while the list is empty',
          maxChars: 40,
        ),
        _accentSlot,
      ];

  @override
  List<String> get keywords => const [
        'list',
        'shopping',
        'notes',
        'note',
        'journal',
        'diary',
        'log',
        'gratitude',
        'ideas',
        'groceries',
        'wishlist',
        'lista',
        'spesa',
        'appunti',
        'note',
        'compras',
        'notas',
        'liste',
        'courses',
        'einkauf',
        'einkaufsliste',
        'notizen',
      ];

  @override
  CreationArtifact build(SlotValues v) => _app(
        titleFor(v),
        v.text('accent'),
        [
          {'type': 'field', 'key': 'draft', 'hint': v.text('hint')},
          {
            'type': 'button',
            'label': 'Add',
            'action': {
              'kind': 'append',
              'key': 'items',
              'value': '{draft}',
              'clear': 'draft',
            },
          },
          {'type': 'list', 'bind': 'items', 'empty': v.text('empty')},
          {
            'type': 'button',
            'label': 'Clear list',
            'action': {'kind': 'reset'},
          },
        ],
      );
}

/// Two counters side by side: a game, a match, a rivalry.
class ScoreboardTemplate extends CreationTemplate {
  const ScoreboardTemplate();

  @override
  String get id => 'scoreboard';
  @override
  CreationKind get kind => CreationKind.app;
  @override
  String get englishName => 'scoreboard';
  @override
  String get purpose => 'two scores the user taps up during a game';

  @override
  List<TemplateSlot> get slots => const [
        _titleSlot,
        TemplateSlot(
          'nameA',
          SlotKind.text,
          fallback: 'Team A',
          example: 'Home',
          description: 'the first side, one or two words',
          maxChars: 20,
        ),
        TemplateSlot(
          'nameB',
          SlotKind.text,
          fallback: 'Team B',
          example: 'Away',
          description: 'the second side, one or two words',
          maxChars: 20,
        ),
        _accentSlot,
      ];

  @override
  List<String> get keywords => const [
        'score',
        'scoreboard',
        'points',
        'game',
        'match',
        'versus',
        'vs',
        'punteggio',
        'partita',
        'punti',
        'marcador',
        'partido',
        'puntos',
        'partie',
        'spiel',
        'punkte',
        'spielstand',
      ];

  @override
  CreationArtifact build(SlotValues v) => _app(
        titleFor(v),
        v.text('accent'),
        [
          {
            'type': 'row',
            'children': [
              {
                'type': 'column',
                'children': [
                  {'type': 'text', 'value': '${v.text('nameA')}: {a}'},
                  {
                    'type': 'button',
                    'label': '+1',
                    'action': {'kind': 'increment', 'key': 'a', 'by': 1},
                  },
                ],
              },
              {
                'type': 'column',
                'children': [
                  {'type': 'text', 'value': '${v.text('nameB')}: {b}'},
                  {
                    'type': 'button',
                    'label': '+1',
                    'action': {'kind': 'increment', 'key': 'b', 'by': 1},
                  },
                ],
              },
            ],
          },
          {
            'type': 'button',
            'label': 'New game',
            'action': {'kind': 'reset'},
          },
        ],
      );
}
