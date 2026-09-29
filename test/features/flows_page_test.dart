import 'dart:io';

import 'package:finn_ai/src/features/flows/flows_page.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The store reads and writes real files, which never settle under the
  // default test binding's fake clock.
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_skills_page_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  testWidgets('the four-flow cap shows the localized limit sentence', (
    tester,
  ) async {
    final store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();
    for (final flow in finnBuiltInFlows) {
      expect(await store.setEnabled(flow.id, true), isTrue);
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: FlowsPage(onBack: () {}, store: store),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('add-flow-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-flow-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(const Key('flow-name-field')),
      'Fifth flow',
    );
    await tester.enterText(
      find.byKey(const Key('flow-instructions-field')),
      'Do the thing.',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('save-flow-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.failure, FlowsFailure.limit);
    // Shown both in the snackbar and in the inline notice.
    expect(
      find.text('Flow limit reached (4). Delete one to add another.'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
