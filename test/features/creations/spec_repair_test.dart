import 'package:finn_ai/src/features/creations/spec/spec_repair.dart';
import 'package:finn_ai/src/features/creations/spec/spec_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// The habit-tracker brief that failed twice on device produced a `list` bound
/// to a key nothing wrote. Prompting alone did not fix it, so the pipeline now
/// prunes the unwired nodes and re-validates. These tests pin both halves: what
/// the pruner removes, and that what it leaves behind actually validates.
void main() {
  group('pruneUnwiredNodes', () {
    test('drops a list bound to a key nothing writes', () {
      final spec = <String, Object?>{
        'title': 'Streaks',
        'nodes': <Object?>[
          {'type': 'text', 'value': 'Your habits:'},
          {'type': 'list', 'bind': 'items', 'empty': 'Nothing yet'},
        ],
      };

      final pruned = pruneUnwiredNodes(spec);

      expect(pruned, isNotNull);
      expect(SpecValidator.validateMiniApp(pruned), isEmpty);
      expect(
        (pruned!['nodes']! as List).length,
        1,
        reason: 'only the unwired list should be gone',
      );
      expect(spec['nodes'], hasLength(2), reason: 'input must not be mutated');
    });

    test('keeps the writer and drops every display of the key', () {
      final spec = <String, Object?>{
        'title': 'Counter',
        'nodes': <Object?>[
          {'type': 'text', 'value': 'Taps: {count}'},
          {'type': 'field', 'key': 'count', 'hint': 'label'},
          {'type': 'text', 'value': 'Notes: {notes}'},
        ],
      };

      final pruned = pruneUnwiredNodes(spec);

      expect(pruned, isNotNull);
      expect(SpecValidator.validateMiniApp(pruned), isEmpty);
      final types = (pruned!['nodes']! as List)
          .cast<Map<String, Object?>>()
          .map((node) => node['type'])
          .toList();
      expect(types, ['text', 'field'], reason: 'the {notes} text is unwired');
    });

    test('removes a container whose children were all pruned', () {
      final spec = <String, Object?>{
        'title': 'Tracker',
        'nodes': <Object?>[
          {
            'type': 'row',
            'children': <Object?>[
              {'type': 'list', 'bind': 'items'},
              {'type': 'progress', 'bind': 'items', 'max': 5},
            ],
          },
          {
            'type': 'button',
            'label': 'Reset',
            'action': {'kind': 'reset'}
          },
        ],
      };

      final pruned = pruneUnwiredNodes(spec);

      expect(pruned, isNotNull);
      expect(SpecValidator.validateMiniApp(pruned), isEmpty);
      final nodes = (pruned!['nodes']! as List).cast<Map<String, Object?>>();
      expect(nodes.single['type'], 'button');
    });

    test('returns null when every displayed key is written', () {
      final spec = <String, Object?>{
        'title': 'Counter',
        'nodes': <Object?>[
          {'type': 'text', 'value': 'Taps: {count}'},
          {'type': 'field', 'key': 'count', 'hint': 'label'},
        ],
      };

      expect(SpecValidator.validateMiniApp(spec), isEmpty);
      expect(pruneUnwiredNodes(spec), isNull);
    });

    test('returns null rather than an empty app', () {
      final spec = <String, Object?>{
        'title': 'Streaks',
        'nodes': <Object?>[
          {'type': 'list', 'bind': 'items'},
        ],
      };

      expect(pruneUnwiredNodes(spec), isNull);
    });

    test('leaves a spec that is already valid untouched', () {
      final spec = <String, Object?>{
        'title': 'Tap Counter',
        'nodes': <Object?>[
          {'type': 'text', 'value': 'Taps: {count}'},
          {
            'type': 'button',
            'label': 'Tap',
            'action': {'kind': 'set', 'key': 'count', 'expr': 'count + 1'},
          },
        ],
      };

      expect(SpecValidator.validateMiniApp(spec), isEmpty);
      expect(pruneUnwiredNodes(spec), isNull);
    });
  });
}
