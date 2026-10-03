import 'package:finn_ai/src/features/chat/home_shell.dart';
import 'package:finn_ai/src/features/settings/settings_page.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'choosing a sidebar destination opens it at once, without the chat '
    'sliding back into view first',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(theme: FluxTheme.light, home: const HomeShell()),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final menu = find.byKey(const ValueKey('home-menu-button'));
      final closedX = tester.getTopLeft(menu).dx;

      await tester.tap(find.byTooltip('Open menu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final openX = tester.getTopLeft(menu).dx;
      expect(openX, greaterThan(closedX + 200));

      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      // The page is already on its way and the chat has not moved: the panel
      // does not close first.
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(tester.getTopLeft(menu).dx, openX);

      await tester.pumpAndSettle();

      // Once the page covers it, the panel is closed behind it, so going back
      // lands on the chat rather than on an open panel.
      final hiddenMenu = find.byKey(
        const ValueKey('home-menu-button'),
        skipOffstage: false,
      );
      expect(tester.getTopLeft(hiddenMenu).dx, closedX);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a page is never see-through to the screen it covers', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  FinnPageRoute<void>(
                    child: const Scaffold(body: Text('second')),
                  ),
                ),
                child: const Text('first'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('first'));
    await tester.pump();
    // A third of the way through, the backdrop is solid.
    await tester.pump(FluxMotion.pageDuration * .4);

    final backdrop = tester
        .widgetList<FadeTransition>(find.byType(FadeTransition))
        .where((f) => f.child is ColoredBox)
        .single;
    expect(backdrop.opacity.value, 1);
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('reduced motion pushes without any transition', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              FinnPageRoute<void>(child: const Scaffold(body: Text('second'))),
            ),
            child: const Text('first'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('first'));
    await tester.pump();
    expect(find.byType(FadeTransition), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
  });
}
