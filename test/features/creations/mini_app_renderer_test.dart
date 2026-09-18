import 'package:finn_ai/src/features/creations/runtime/mini_app_renderer.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_state.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const spec = MiniAppSpec(
    title: 'Counter',
    accent: MiniAppAccent.mint,
    nodes: [
      FieldNode(key: 'count', hint: ''),
      TextNode(value: 'Count: {count}'),
      ButtonNode(label: 'Add', action: IncrementAction(key: 'count', by: 1)),
    ],
  );

  testWidgets('an action on a field-bound key refreshes the field text', (
    tester,
  ) async {
    final state = MiniAppState(spec);
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: Scaffold(body: MiniAppRenderer(state: state)),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '3');
    await tester.pump();
    expect(find.text('Count: 3'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pump();

    // The button changed the value the field edits; the field must show it
    // rather than the stale text the user last typed.
    expect(find.text('Count: 4'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '4');
    expect(tester.takeException(), isNull);
  });
}
