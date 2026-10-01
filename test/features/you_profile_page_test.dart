import 'dart:io';

import 'package:finn_ai/src/features/you/you_profile_page.dart';
import 'package:finn_ai/src/features/you/you_profile_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a storage failure is shown as a localized sentence', (
    tester,
  ) async {
    // A provider that fails makes the store report a read failure, whose raw
    // English text must never reach the UI.
    final store = YouProfileStore(
      directoryProvider: () async => throw const FileSystemException('nope'),
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: YouProfilePage(onBack: () {}, store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(store.storageError, isNotNull);
    expect(find.text('Could not save changes.'), findsOneWidget);
    expect(find.textContaining('Could not read personalization'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
