import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/spec_limits.dart';
import 'package:finn_ai/src/features/creations/spec/spec_validator.dart';
import 'package:finn_ai/src/features/creations/spec/widget_spec.dart';

Map<String, Object?> _counterApp() => {
      'title': 'Tap Counter',
      'accent': 'mint',
      'nodes': [
        {'type': 'text', 'value': 'Taps: {count}', 'style': 'title'},
        {
          'type': 'button',
          'label': 'Tap',
          'action': {'kind': 'set', 'key': 'count', 'expr': 'count + 1'},
        },
        {
          'type': 'button',
          'label': 'Clear',
          'action': {'kind': 'reset'},
        },
      ],
    };

Map<String, Object?> _widget() => {
      'title': 'Hydration',
      'accent': 'sky',
      'rows': [
        {'label': 'Glasses', 'value': '3'},
        {'label': 'Goal', 'value': '8'},
      ],
      'footer': 'Tap to open',
    };

Map<String, Object?> _deck() => {
      'title': 'Quarterly Review',
      'slides': [
        {
          'title': 'Highlights',
          'bullets': ['Revenue up', 'Churn down'],
          'notes': 'Keep this brief',
        },
      ],
    };

void main() {
  group('validateMiniApp accepts well-formed specs', () {
    test('a counter app with a bound text and a setter', () {
      expect(SpecValidator.validateMiniApp(_counterApp()), isEmpty);
    });

    test('nested containers within the depth cap', () {
      final spec = {
        'title': 'Nested',
        'nodes': [
          {
            'type': 'column',
            'children': [
              {
                'type': 'row',
                'children': [
                  {'type': 'text', 'value': 'plain text'},
                ],
              },
            ],
          },
        ],
      };
      expect(SpecValidator.validateMiniApp(spec), isEmpty);
    });

    test('image nodes with an emoji or an https url', () {
      final spec = {
        'title': 'Images',
        'nodes': [
          {'type': 'image', 'emoji': '🌱'},
          {'type': 'image', 'url': 'https://example.com/a.png'},
        ],
      };
      expect(SpecValidator.validateMiniApp(spec), isEmpty);
    });
  });

  group('validateMiniApp rejects malformed specs', () {
    test('non-object root', () {
      final issues = SpecValidator.validateMiniApp('nope');
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('JSON object'));
    });

    test('missing or empty title', () {
      final issues = SpecValidator.validateMiniApp({
        'title': '   ',
        'nodes': [
          {'type': 'text', 'value': 'hi'},
        ],
      });
      expect(issues.map((issue) => issue.path), contains('title'));
    });

    test('unknown accent', () {
      final spec = _counterApp()..['accent'] = 'chartreuse';
      final issues = SpecValidator.validateMiniApp(spec);
      expect(issues.single.path, 'accent');
      expect(issues.single.message, contains('must be one of'));
    });

    test('unknown node type names the type in the message', () {
      final issues = SpecValidator.validateMiniApp({
        'title': 'Bad',
        'nodes': [
          {'type': 'webview', 'url': 'https://example.com'},
        ],
      });
      expect(issues.single.path, 'nodes[0]');
      expect(issues.single.message, contains('webview'));
    });

    test('node missing a type', () {
      final issues = SpecValidator.validateMiniApp({
        'title': 'Bad',
        'nodes': [
          {'label': 'orphan'},
        ],
      });
      expect(issues.single.message, contains('missing a "type"'));
    });

    test('too many nodes', () {
      final issues = SpecValidator.validateMiniApp({
        'title': 'Too many',
        'nodes': List.generate(
          SpecLimits.maxNodes + 1,
          (_) => {'type': 'spacer', 'size': 8},
        ),
      });
      expect(
        issues.any((issue) => issue.message.contains('at most')),
        isTrue,
        reason: 'expected a node-count issue, got $issues',
      );
    });

    test('nesting deeper than the cap', () {
      final issues = SpecValidator.validateMiniApp({
        'title': 'Deep',
        'nodes': [
          {
            'type': 'column',
            'children': <Object?>[
              {
                'type': 'column',
                'children': [
                  {
                    'type': 'column',
                    'children': [
                      {
                        'type': 'column',
                        'children': [
                          {'type': 'text', 'value': 'bottom'},
                        ],
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      });
      expect(issues.single.message, contains('nests deeper'));
    });

    test('unparseable action expression', () {
      final issues = SpecValidator.validateMiniApp({
        'title': 'Bad expr',
        'nodes': [
          {
            'type': 'button',
            'label': 'Go',
            'action': {'kind': 'set', 'key': 'count', 'expr': 'count +'},
          },
        ],
      });
      expect(issues.single.path, 'nodes[0].action.expr');
    });

    test('unknown action kind', () {
      final issues = SpecValidator.validateMiniApp({
        'title': 'Bad action',
        'nodes': [
          {
            'type': 'button',
            'label': 'Go',
            'action': {'kind': 'launchMissiles', 'key': 'count'},
          },
        ],
      });
      expect(issues.single.message, contains('launchMissiles'));
    });

    test('a displayed key that nothing ever changes', () {
      final issues = SpecValidator.validateMiniApp({
        'title': 'Dead binding',
        'nodes': [
          {'type': 'text', 'value': 'Taps: {count}'},
        ],
      });
      expect(issues.single.message, contains('never changed'));
    });

    test('invalid binding key syntax', () {
      final issues = SpecValidator.validateMiniApp({
        'title': 'Bad key',
        'nodes': [
          {'type': 'field', 'key': '2nd name', 'hint': 'Name'},
        ],
      });
      expect(issues.single.path, 'nodes[0].key');
    });

    test('non-https image url', () {
      final issues = SpecValidator.validateMiniApp({
        'title': 'Insecure',
        'nodes': [
          {'type': 'image', 'url': 'http://example.com/a.png'},
        ],
      });
      expect(issues.single.message, contains('https://'));
    });

    test('slider max not above min', () {
      final issues = SpecValidator.validateMiniApp({
        'title': 'Bad slider',
        'nodes': [
          {'type': 'slider', 'key': 'level', 'min': 10, 'max': 5},
        ],
      });
      expect(issues.single.message, contains('greater than'));
    });

    test('choice with too many options', () {
      final issues = SpecValidator.validateMiniApp({
        'title': 'Too many choices',
        'nodes': [
          {
            'type': 'choice',
            'key': 'size',
            'options': ['a', 'b', 'c', 'd', 'e'],
          },
        ],
      });
      expect(issues.single.message, contains('at most'));
    });

    test('empty container children', () {
      final issues = SpecValidator.validateMiniApp({
        'title': 'Empty row',
        'nodes': [
          {'type': 'row', 'children': <Object?>[]},
        ],
      });
      expect(issues.single.path, 'nodes[0].children');
    });

    test('missing nodes list', () {
      final issues = SpecValidator.validateMiniApp({'title': 'No nodes'});
      expect(issues.single.path, 'nodes');
    });
  });

  group('validateHomeWidget', () {
    test('accepts a well-formed widget', () {
      expect(SpecValidator.validateHomeWidget(_widget()), isEmpty);
    });

    test('rejects more rows than a launcher widget can show', () {
      final spec = _widget()
        ..['rows'] = List.generate(
          SpecLimits.maxWidgetRows + 1,
          (index) => {'label': 'Row $index', 'value': '$index'},
        );
      expect(
        SpecValidator.validateHomeWidget(spec).single.message,
        contains('at most'),
      );
    });

    test('rejects an over-long row value', () {
      final spec = _widget()
        ..['rows'] = [
          {
            'label': 'Long',
            'value': 'x' * (SpecLimits.maxWidgetValueChars + 1),
          },
        ];
      expect(
        SpecValidator.validateHomeWidget(spec).single.path,
        'rows[0].value',
      );
    });

    test('rejects a missing title', () {
      final issues = SpecValidator.validateHomeWidget({'rows': <Object?>[]});
      expect(issues.map((issue) => issue.path), contains('title'));
    });
  });

  group('validateDeck', () {
    test('accepts a well-formed deck', () {
      expect(SpecValidator.validateDeck(_deck()), isEmpty);
    });

    test('rejects too many slides', () {
      final spec = {
        'title': 'Long deck',
        'slides': List.generate(
          SpecLimits.maxSlides + 1,
          (index) => {
            'title': 'Slide $index',
            'bullets': ['One'],
          },
        ),
      };
      expect(
        SpecValidator.validateDeck(spec).single.message,
        contains('at most'),
      );
    });

    test('rejects an over-long bullet', () {
      final spec = {
        'title': 'Long deck',
        'slides': <Object?>[
          {
            'title': 'Slide',
            'bullets': ['x' * (SpecLimits.maxBulletChars + 1)],
          },
        ],
      };
      expect(
        SpecValidator.validateDeck(spec).single.path,
        'slides[0].bullets[0]',
      );
    });

    test('rejects a slide without a title', () {
      final issues = SpecValidator.validateDeck({
        'title': 'Deck',
        'slides': <Object?>[
          {
            'bullets': ['One']
          },
        ],
      });
      expect(issues.single.path, 'slides[0].title');
    });

    test('rejects an empty slides list', () {
      expect(
        SpecValidator.validateDeck({
          'title': 'Empty',
          'slides': <Object?>[],
        }).single.path,
        'slides',
      );
    });
  });

  group('describeIssues', () {
    test('renders one bullet per issue', () {
      final rendered = SpecValidator.describeIssues(
        const [
          SpecIssue('title', 'is required'),
          SpecIssue('nodes[0]', 'is bad'),
        ],
      );
      expect(rendered, '- title: is required\n- nodes[0]: is bad');
    });

    test('truncates a long list so the repair prompt stays small', () {
      final issues = List.generate(
        SpecValidator.maxRepairIssues + 3,
        (index) => SpecIssue('nodes[$index]', 'bad'),
      );
      final rendered = SpecValidator.describeIssues(issues);
      expect(
          rendered.split('\n'), hasLength(SpecValidator.maxRepairIssues + 1));
      expect(rendered, contains('and 3 more'));
    });

    test('omits the path separator for root-level issues', () {
      expect(
        SpecValidator.describeIssues(const [SpecIssue('', 'root problem')]),
        '- root problem',
      );
    });
  });

  group('spec round-trips', () {
    test('mini app survives toJson/fromJson unchanged', () {
      final spec = MiniAppSpec.fromJson(_counterApp());
      final restored = MiniAppSpec.fromJson(spec.toJson());
      expect(restored.toJson(), spec.toJson());
      expect(spec.referencedKeys, contains('count'));
      expect(spec.writtenKeys, contains('count'));
    });

    test('home widget survives toJson/fromJson unchanged', () {
      final spec = HomeWidgetSpec.fromJson(_widget());
      expect(
        HomeWidgetSpec.fromJson(spec.toJson()).toJson(),
        spec.toJson(),
      );
    });

    test('deck survives toJson/fromJson unchanged', () {
      final spec = DeckSpec.fromJson(_deck());
      expect(DeckSpec.fromJson(spec.toJson()).toJson(), spec.toJson());
    });
  });
}
