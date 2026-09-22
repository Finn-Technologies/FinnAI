import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finn_ai/src/features/settings/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsPage', () {
    // "Purge AI Memory", "Clear All Chat History" and "Delete All Local Data"
    // sat together as three bare red labels, so the reversible RAM flush looked
    // as dangerous as wiping the device and the only way to tell them apart was
    // to open each confirmation. Each row now says what it does.
    testWidgets('the storage rows state what they will do', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: SettingsPage(onBack: () {})));
      await tester.pump();

      for (final line in [
        'Frees RAM. The model reloads on your next message.',
        'Deletes every saved chat. Cannot be undone.',
        'Chats, models, creations and preferences — back to a first run.',
      ]) {
        final target = find.text(line);
        await tester.scrollUntilVisible(
          target,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(target, findsOneWidget, reason: line);
      }
      expect(tester.takeException(), isNull);
    });

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

    testWidgets('entrance lifts only the body and keeps title anchored', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: SettingsPage(onBack: () {})));
      await tester.pump();
      final titleTop = tester.getTopLeft(find.text('Settings')).dy;

      await tester.pump(const Duration(milliseconds: 280));
      expect(tester.getTopLeft(find.text('Settings')).dy, titleTop);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every section lays out without a horizontal overflow', (
      WidgetTester tester,
    ) async {
      // A tall viewport builds every section, including About, whose long
      // values must not squeeze their labels and overflow the row.
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: SettingsPage(onBack: () {})));
      await tester.pump();
      // Let the entrance animation settle so the body is at its resting place.
      await tester.pump(const Duration(milliseconds: 700));

      // Proves the About rows were actually built and laid out.
      expect(find.text('LFM2.5-VL 1.6B (Liquid)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
