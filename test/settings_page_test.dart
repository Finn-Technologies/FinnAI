import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finn_ai/src/settings/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsPage', () {
    testWidgets('renders title and visible content', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: SettingsPage(onBack: () {})));
      // One pump so the first frame is laid out; don't pumpAndSettle because
      // inspectModels() performs async file I/O that never resolves in tests.
      await tester.pump();

      // Title is always visible regardless of async state.
      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('back callback fires on back control tap', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(home: SettingsPage(onBack: () => tapped = true)),
      );
      await tester.pump();

      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
