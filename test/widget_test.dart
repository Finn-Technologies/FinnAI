import 'package:finn_ai/src/conversations/conversation_store.dart';
import 'package:finn_ai/src/creations/creations_page.dart';
import 'package:finn_ai/src/flux_app.dart';
import 'package:finn_ai/src/home/home_shell.dart';
import 'package:finn_ai/src/settings/settings_page.dart';
import 'package:finn_ai/src/skills/skills_page.dart';
import 'package:finn_ai/src/theme/flux_theme.dart';
import 'package:finn_ai/src/you/you_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Finn AI opens on the welcome experience', (tester) async {
    await tester.pumpWidget(const FluxApp(enableModelDownload: false));
    await tester.pump();

    expect(find.text('Welcome to Finn AI!'), findsOneWidget);
    expect(find.text('Swipe to start'), findsOneWidget);
  });

  testWidgets('onboarding is usable at the Figma viewport size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FluxApp(enableModelDownload: false));

    await tester.drag(find.byType(PageView), const Offset(-390, 0));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Welcome to Finn AI!'), findsOneWidget);

    Future<void> moveForward({bool welcome = false}) async {
      if (welcome) {
        await tester.drag(find.text('Swipe to start'), const Offset(0, -100));
      } else {
        await tester.tap(find.text('Next'));
      }
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump(const Duration(milliseconds: 800));
      final exception = tester.takeException();
      if (exception case final FlutterError error) {
        debugPrint(error.toStringDeep());
      }
      expect(exception, isNull);
    }

    await moveForward(welcome: true);
    expect(find.text('Finn AI is Privacy-First'), findsOneWidget);
    expect(find.textContaining('proprietary software'), findsOneWidget);
    await moveForward();
    expect(find.text('Installing the best model'), findsOneWidget);
    expect(
      find.text('Finding the best model for this device…'),
      findsOneWidget,
    );

    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(3);
    await tester.pump();
    expect(find.text('Before starting, read precautions'), findsOneWidget);
    await moveForward();
    expect(find.text('Finn AI is ready!'), findsOneWidget);
    await tester.drag(
      find.text("You're all set. Finn AI is ready."),
      const Offset(0, -100),
    );
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Finn AI'), findsWidgets);
  });

  testWidgets('home and sidebar stay overflow-free', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: FluxTheme.light, home: const HomeShell()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Finn AI'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Chat History'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('composer always shows the original send button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: FluxTheme.light, home: const HomeShell()),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.bySemanticsLabel('Send message'), findsOneWidget);
    expect(find.bySemanticsLabel('Start on-device voice input'), findsNothing);
  });

  testWidgets('Creations composer exposes the home-style send action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: FluxTheme.light, home: const CreationsPage()),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.bySemanticsLabel('Create'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).last,
      'A focused water tracker',
    );
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.textInputAction, TextInputAction.send);
    expect(field.onSubmitted, isNotNull);
    expect(find.bySemanticsLabel('Create'), findsOneWidget);
  });

  testWidgets('system back closes the sidebar instead of leaving home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: FluxTheme.light, home: const HomeShell()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Chat History'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byTooltip('Open menu'), findsOneWidget);
  });

  testWidgets('sidebar exposes and navigates to Creations, You, and Skills', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: FluxTheme.light, home: const HomeShell()),
    );
    await tester.pump(const Duration(milliseconds: 120));

    Future<void> openSidebar() async {
      await tester.tap(find.byTooltip('Open menu'));
      // Start the ticker before advancing through the transition duration.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Creations'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Skills'), findsOneWidget);
    }

    Future<void> returnHome() async {
      await tester.tap(find.text('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Open menu'), findsOneWidget);
    }

    await openSidebar();
    await tester.tap(find.text('Creations'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.byType(CreationsPage), findsOneWidget);
    expect(
      find.text('Turn an idea into a structured plan, entirely on device.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await returnHome();

    await openSidebar();
    await tester.tap(find.text('You'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.byType(YouPage), findsOneWidget);
    expect(find.text('You'), findsWidgets);
    expect(tester.takeException(), isNull);
    await returnHome();

    await openSidebar();
    await tester.tap(find.text('Skills'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.byType(SkillsPage), findsOneWidget);
    expect(find.text('Skills'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('feature page headers share the Settings visual anchors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<(double, double)> measure(Widget page, String title) async {
      await tester.pumpWidget(MaterialApp(theme: FluxTheme.light, home: page));
      await tester.pump();
      expect(tester.takeException(), isNull);
      return (
        tester.getTopLeft(find.text('Back')).dy,
        tester.getTopLeft(find.text(title)).dy,
      );
    }

    final settings = await measure(SettingsPage(onBack: () {}), 'Settings');
    final creations = await measure(const CreationsPage(), 'Creations');
    final you = await measure(YouPage(onBack: () {}), 'You');
    final skills = await measure(SkillsPage(onBack: () {}), 'Skills');

    for (final header in [creations, you, skills]) {
      expect(header.$1, closeTo(settings.$1, .01));
      expect(header.$2, closeTo(settings.$2, .01));
    }
  });

  testWidgets('precautions adapt to a narrow Android viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FluxApp(enableModelDownload: false));
    await tester.drag(find.text('Swipe to start'), const Offset(0, -100));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(3);
    await tester.pump();

    expect(find.text('Before starting, read precautions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entire sidebar scrolls when dragged', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (int i = 0; i < 15; i++) {
      ConversationStore.instance.startNew();
    }

    await tester.pumpWidget(
      MaterialApp(theme: FluxTheme.light, home: const HomeShell()),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Open menu'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));

    final initialTitleTop = tester.getTopLeft(find.text('Chat History')).dy;

    final scrollableState = tester.state<ScrollableState>(
      find.byType(Scrollable).last,
    );
    scrollableState.position.jumpTo(120);
    await tester.pump();

    final scrolledTitleTop = tester.getTopLeft(find.text('Chat History')).dy;
    expect(scrolledTitleTop, lessThan(initialTitleTop));
  });

  testWidgets(
    'chat history title lifts all the way up to header position replacing top content',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (int i = 0; i < 15; i++) {
        ConversationStore.instance.startNew();
      }

      await tester.pumpWidget(
        MaterialApp(theme: FluxTheme.light, home: const HomeShell()),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byTooltip('Open menu'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));

      final initialHeaderY = tester.getTopLeft(find.text('Finn AI').last).dy;
      final initialTitleY = tester.getTopLeft(find.text('Chat History')).dy;

      final scrollableState = tester.state<ScrollableState>(
        find.byType(Scrollable).last,
      );
      scrollableState.position.jumpTo(250);
      await tester.pump();

      final scrolledTitleY = tester.getTopLeft(find.text('Chat History')).dy;

      expect(scrolledTitleY, closeTo(initialHeaderY, 5.0));
      expect(scrolledTitleY, lessThan(initialTitleY));
    },
  );

  testWidgets(
    'fast scrolling up through large chat history is virtualized and smooth',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (int i = 0; i < 20; i++) {
        ConversationStore.instance.startNew();
      }

      await tester.pumpWidget(
        MaterialApp(theme: FluxTheme.light, home: const HomeShell()),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byTooltip('Open menu'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.flingFrom(
        const Offset(195, 422),
        const Offset(0, -600),
        2000,
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.flingFrom(
        const Offset(195, 422),
        const Offset(0, 600),
        2000,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('app automatically adapts to device Dark Mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const FluxApp());
    await tester.pump(const Duration(milliseconds: 100));

    final BuildContext context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, equals(Brightness.dark));
    expect(FluxColors.isDark(context), isTrue);
    expect(FluxColors.canvasOf(context), equals(FluxColors.darkCanvas));
    expect(FluxColors.inkOf(context), equals(FluxColors.darkInk));
  });
}
