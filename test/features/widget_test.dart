import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/creations/creations_page.dart';
import 'package:finn_ai/src/app/bootstrap.dart';
import 'package:finn_ai/src/features/chat/home_shell.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';
import 'package:finn_ai/src/features/settings/settings_page.dart';
import 'package:finn_ai/src/features/skills/skills_page.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/features/you/you_page.dart';
import 'package:finn_ai/src/shared/widgets/safe_markdown_text.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
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
    expect(find.text('Installing LFM2.5-VL 1.6B'), findsOneWidget);
    expect(
        find.text('Preparing LFM2.5-VL 1.6B for this device…'), findsOneWidget);

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
    expect(find.text('FinnAI'), findsWidgets);
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
    expect(find.text('FinnAI'), findsWidgets);
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
    expect(find.bySemanticsLabel('Add attachment'), findsOneWidget);
    expect(find.bySemanticsLabel('Start on-device voice input'), findsNothing);
  });

  testWidgets(
    'user message with image attachment renders thumbnail and bubble',
    (tester) async {
      final conversations = ConversationStore();
      conversations.startNew();
      conversations.add(
        ConversationRole.user,
        'Look at this chart',
        imagePath: '/mock/chart_sample.jpg',
      );
      addTearDown(conversations.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: FluxTheme.light,
          home: HomeShell(
            conversationStore: conversations,
            initializeServices: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Look at this chart'), findsOneWidget);
      expect(find.text('chart_sample.jpg'), findsOneWidget);
    },
  );

  testWidgets('chat fades at both edges and stays readable on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final conversations = ConversationStore();
    conversations.startNew();
    conversations
      ..add(ConversationRole.user, 'How does this layout adapt?')
      ..add(
        ConversationRole.assistant,
        'The chat remains centered and readable on a wide display.',
        modelTier: 'Qwen 3.5 2B',
      );
    addTearDown(conversations.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: HomeShell(
          conversationStore: conversations,
          initializeServices: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('chat-edge-fade')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-scroll-view')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('chat-scroll-view'))).width,
      lessThanOrEqualTo(760),
    );

    // The two fades must be anchored to opposite edges: the bottom fade hugs
    // the composer at the bottom rather than stacking at the top.
    final topFade = tester.getRect(find.byKey(const ValueKey('chat-fade-top')));
    final bottomFade = tester.getRect(
      find.byKey(const ValueKey('chat-fade-bottom')),
    );
    expect(bottomFade.center.dy, greaterThan(topFade.center.dy));
    final chatRect = tester.getRect(
      find.byKey(const ValueKey('chat-scroll-view')),
    );
    expect(topFade.top, closeTo(chatRect.top, 2));
    expect(bottomFade.bottom, closeTo(chatRect.bottom, 2));

    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('expanding sources anchors the answer and slides actions below', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final conversations = ConversationStore();
    addTearDown(conversations.dispose);
    // Build a conversation taller than the viewport so the reverse list has
    // scroll range for the anchored expansion to work against.
    var assistant = conversations.beginExchange('first question?');
    conversations.updateMessageInConversation(
      conversations.active!.id,
      assistant.id,
      'A longer first answer that spans several lines so the conversation '
      'comfortably exceeds the viewport height and leaves scroll range for '
      'the anchored sources expansion.',
    );
    for (var i = 0; i < 3; i++) {
      assistant = conversations.beginExchange('question ${i + 2}?');
      conversations.updateMessageInConversation(
        conversations.active!.id,
        assistant.id,
        'Another multi-line answer repeated here to keep the conversation '
        'taller than the screen so the list can scroll while the sources '
        'list expands and collapses.',
      );
    }
    conversations.updateMessageInConversation(
      conversations.active!.id,
      assistant.id,
      'Here is a grounded answer with sources.',
      sources: [
        WebSource(
          title: 'First Site',
          url: Uri.parse('https://one.example.com'),
          snippet: 'First excerpt.',
        ),
        WebSource(
          title: 'Second Site',
          url: Uri.parse('https://two.example.com'),
          snippet: 'Second excerpt.',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: HomeShell(
          conversationStore: conversations,
          initializeServices: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final answer = find.textContaining('Here is a grounded answer');
    // The newest message is index zero in the reversed list, so its actions
    // are the first "Copy" tooltip in the tree.
    final copy = find.byTooltip('Copy').first;
    final answerTopBefore = tester.getRect(answer).top;
    final copyTopBefore = tester.getRect(copy).top;
    final positionBefore = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const ValueKey('chat-scroll-view')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;

    await tester.tap(find.text('one.example.com'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 100));

    // The list reveals the source titles without a card background.
    expect(find.text('First Site'), findsOneWidget);
    expect(find.text('Second Site'), findsOneWidget);

    // The answer above the sources list stays anchored on screen…
    expect(tester.getRect(answer).top, closeTo(answerTopBefore, 1));
    // …the actions below it slide down…
    expect(tester.getRect(copy).top, greaterThan(copyTopBefore));
    // …and the reverse list compensates its scroll offset by the growth.
    final positionAfter = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const ValueKey('chat-scroll-view')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    expect(positionAfter, greaterThan(positionBefore));
    expect(tester.takeException(), isNull);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'send control has distinct, contrasting states in ${brightness.name} mode',
      (tester) async {
        final theme =
            brightness == Brightness.dark ? FluxTheme.dark : FluxTheme.light;
        final controller = TextEditingController();
        final focusNode = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focusNode.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: ChatComposer(
                controller: controller,
                focusNode: focusNode,
                blocked: false,
                onSend: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        final surfaceFinder = find.byKey(const ValueKey('send-button-surface'));
        final iconFinder = find.byKey(const ValueKey('send-button-icon'));
        final disabledIcon = tester.widget<FigmaSvg>(iconFinder);
        expect(tester.getSize(surfaceFinder), const Size(36, 36));
        // The composer-wide shrink transform animates the whole pill down to
        // 90% while scrolled away; at rest it must be full size, and the send
        // button itself is never individually scaled.
        final composerShrink = tester.widget<TweenAnimationBuilder<double>>(
          find.ancestor(
            of: surfaceFinder,
            matching: find.byType(TweenAnimationBuilder<double>),
          ),
        );
        expect(composerShrink.tween.end, 0.0);
        expect(find.bySemanticsLabel('Send message'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Ready');
        await tester.pump();
        final activeIcon = tester.widget<FigmaSvg>(iconFinder);

        expect(activeIcon.asset, FigmaAssets.activeSend);
        expect(disabledIcon.asset, FigmaAssets.send);
      },
    );
  }

  testWidgets('partial safe Markdown hides raw markers without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SafeMarkdownText(
            text: '**unfinished bold\n1. partial step\n<div>safe text',
          ),
        ),
      ),
    );

    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('<div>'), findsNothing);
    expect(find.textContaining('unfinished bold'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Creations composer exposes the home-style send action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: FluxTheme.light, home: const CreationsPage()),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Creations reuses the chat composer verbatim, so the action carries the
    // same label and behaviour as the one on the home screen.
    expect(find.bySemanticsLabel('Send message'), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).last,
      'A focused water tracker',
    );
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.textInputAction, TextInputAction.send);
    expect(field.onSubmitted, isNotNull);
    expect(find.bySemanticsLabel('Send message'), findsOneWidget);
  });

  testWidgets('system back closes the sidebar instead of leaving home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: FluxTheme.light, home: const HomeShell()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Chat History'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

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
    // The gallery leads with its filters rather than a sentence, so assert on
    // the page's own chrome instead of prose that depends on the store state.
    expect(find.text('Creations'), findsWidgets);
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

      final initialHeaderY = tester.getTopLeft(find.text('FinnAI').last).dy;
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

  testWidgets('onboarding detail pages use dark theme surfaces and copy', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const FluxApp(enableModelDownload: false));
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(1);
    await tester.pump();

    final panel = tester.widget<ColoredBox>(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == FluxColors.darkCard,
      ),
    );
    expect(panel.color, FluxColors.darkCard);

    final privacyCopy = tester.widget<Text>(
      find.textContaining('Finn AI is designed to respect your privacy.'),
    );
    expect(privacyCopy.style?.color, FluxColors.darkInk.withValues(alpha: .7));
  });
}
