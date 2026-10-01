import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/settings/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, {VoidCallback? onBack}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(onBack: onBack ?? () {})),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('SettingsPage', () {
    testWidgets('lists the six destinations', (tester) async {
      await pump(tester);

      expect(find.text('Settings'), findsOneWidget);
      for (final label in [
        'FinnAI Foundation',
        'Voice and language',
        'Device access',
        'You',
        'Privacy and data',
        'About',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('back callback fires on back control tap', (tester) async {
      var tapped = false;
      await pump(tester, onBack: () => tapped = true);

      await tester.tap(find.byKey(const ValueKey('page-back-button')));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('a destination opens its own page', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Privacy and data'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Stored on this device'), findsOneWidget);
      expect(find.text('Export everything'), findsOneWidget);
      expect(find.text('Erase everything'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
