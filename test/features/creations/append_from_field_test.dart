import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/runtime/mini_app_state.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/spec_validator.dart';

/// A notes or shopping list needs a button that adds what was typed. Append
/// used to add a literal, so a list could only ever collect one fixed word.
Map<String, Object?> _listApp() => {
      'title': 'Shopping',
      'accent': 'mint',
      'nodes': [
        {'type': 'field', 'key': 'draft', 'hint': 'Add an item'},
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
        {'type': 'list', 'bind': 'items', 'empty': 'Nothing yet'},
      ],
    };

void main() {
  test('the list app validates with no issues', () {
    expect(SpecValidator.validateMiniApp(_listApp()), isEmpty);
  });

  test('append adds what was typed and empties the field', () {
    final state = MiniAppState(MiniAppSpec.fromJson(_listApp()));
    state.setValue('draft', 'milk');
    final add =
        (MiniAppSpec.fromJson(_listApp()).nodes[1] as ButtonNode).action;
    state.dispatch(add);
    expect(state.valueOf('items'), ['milk']);
    expect(state.valueOf('draft'), '');
    state
      ..setValue('draft', 'eggs')
      ..dispatch(add);
    expect(state.valueOf('items'), ['milk', 'eggs']);
  });

  test('an empty draft adds nothing', () {
    final state = MiniAppState(MiniAppSpec.fromJson(_listApp()));
    final add =
        (MiniAppSpec.fromJson(_listApp()).nodes[1] as ButtonNode).action;
    state
      ..setValue('draft', '   ')
      ..dispatch(add);
    expect(state.valueOf('items'), isEmpty);
  });

  test('a literal append still works and round-trips through JSON', () {
    const action = AppendAction(key: 'items', value: 'one');
    final restored = MiniAppAction.fromJson(action.toJson()) as AppendAction;
    expect(restored.value, 'one');
    expect(restored.clearKey, isNull);
    final withClear = MiniAppAction.fromJson(
      const AppendAction(key: 'a', value: '{b}', clearKey: 'b').toJson(),
    ) as AppendAction;
    expect(withClear.clearKey, 'b');
  });

  test('a placeholder nothing writes is still rejected', () {
    final app = _listApp();
    (app['nodes']! as List)[0] = {'type': 'spacer', 'size': 4};
    // With no field and no `clear`, nothing ever writes {draft}.
    (((app['nodes']! as List)[1] as Map)['action'] as Map).remove('clear');
    expect(SpecValidator.validateMiniApp(app), isNotEmpty);
  });
}
