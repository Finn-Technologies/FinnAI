import 'package:finn_ai/src/shared/layout/finn_layout.dart';
import 'package:finn_ai/src/shared/widgets/desktop_shortcuts.dart';
import 'package:finn_ai/src/shared/widgets/enter_to_send.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_sidebar_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinnLayout', () {
    test('a phone keeps the designed 322/420 slide-over panel', () {
      expect(FinnLayout.isDocked(420), isFalse);
      expect(FinnLayout.sidebarWidth(420), closeTo(322, .001));
      expect(FinnLayout.bodyWidth(420), 420);
    });

    test('a tablet in portrait slides the panel over at a fixed width', () {
      expect(FinnLayout.isDocked(768), isFalse);
      expect(FinnLayout.sidebarWidth(768), lessThanOrEqualTo(340));
      expect(FinnLayout.sidebarWidth(768), greaterThan(300));
    });

    test('a wide window docks the panel and gives the rest to the chat', () {
      expect(FinnLayout.isDocked(900), isTrue);
      expect(FinnLayout.sidebarWidth(1400), FinnLayout.dockWidth);
      expect(FinnLayout.bodyWidth(1400), 1400 - FinnLayout.dockWidth);
    });

    test('the panel never grows with the window', () {
      for (final width in [600.0, 700.0, 899.0, 900.0, 1600.0, 3000.0]) {
        expect(FinnLayout.sidebarWidth(width), lessThanOrEqualTo(340));
      }
    });
  });

  group('docked FinnSidebarSurface', () {
    testWidgets('shows the panel and the home screen side by side', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinnSidebarSurface(
              docked: true,
              home: const Text('home'),
              sidebar: const Text('panel'),
              sidebarWidth: FinnLayout.dockWidth,
              progress: 0,
              sidebarOpen: false,
              toggleLeft: 0,
              toggleTop: 0,
              onToggle: () {},
              onDragStart: (_) {},
              onDragUpdate: (_) {},
              onDragEnd: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('panel'), findsOneWidget);
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(FinnSidebarToggleButton), findsNothing);
      expect(
        tester.getTopLeft(find.text('home')).dx,
        greaterThan(FinnLayout.dockWidth - 1),
      );
    });
  });

  group('EnterToSend', () {
    Widget host({required VoidCallback onSend, bool canSend = true}) {
      final controller = TextEditingController();
      return MaterialApp(
        home: Scaffold(
          body: EnterToSend(
            enabled: true,
            canSend: canSend,
            onSend: onSend,
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
            ),
          ),
        ),
      );
    }

    testWidgets('Enter sends and does not add a line', (tester) async {
      var sent = 0;
      await tester.pumpWidget(host(onSend: () => sent++));
      await tester.enterText(find.byType(TextField), 'hi');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sent, 1);
    });

    testWidgets('Shift+Enter is left alone for a newline', (tester) async {
      var sent = 0;
      await tester.pumpWidget(host(onSend: () => sent++));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(sent, 0);
    });

    testWidgets('Enter with nothing to send does not call onSend', (
      tester,
    ) async {
      var sent = 0;
      await tester.pumpWidget(host(onSend: () => sent++, canSend: false));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sent, 0);
    });
  });

  group('DesktopShortcuts', () {
    testWidgets('Ctrl+N, Ctrl+B and Ctrl+, call their handlers', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: DesktopShortcuts(
            enabled: true,
            onNew: () => calls.add('new'),
            onToggleSidebar: () => calls.add('sidebar'),
            onSettings: () => calls.add('settings'),
            child: const Focus(autofocus: true, child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();
      for (final key in [
        LogicalKeyboardKey.keyN,
        LogicalKeyboardKey.keyB,
        LogicalKeyboardKey.comma,
      ]) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      }
      expect(calls, ['new', 'sidebar', 'settings']);
    });
  });

  group('Esc and Alt+Left close a page', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                FinnPageRoute<void>(child: const Scaffold(body: Text('page'))),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('page'), findsOneWidget);
    }

    testWidgets('Escape pops the page', (tester) async {
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('page'), findsNothing);
    });

    testWidgets('Alt+Left pops the page', (tester) async {
      await open(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(find.text('page'), findsNothing);
    });
  });
}
