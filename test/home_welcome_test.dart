import 'package:finn_ai/src/conversations/conversation_store.dart';
import 'package:finn_ai/src/home/home_shell.dart';
import 'package:finn_ai/src/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [
    Size(390, 844),
    Size(360, 640),
    Size(320, 700),
    Size(430, 932),
  ]) {
    testWidgets(
      'welcome slate fits ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final conversations = ConversationStore();
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
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text("Hi, I'm Finn."), findsOneWidget);
        expect(find.text('Try asking'), findsOneWidget);
        // The clean slate has no feature pills and no brand mark: just the
        // intro, the suggestion chips, and the composer.
        expect(find.text('On-device'), findsNothing);
        expect(find.text('Offline'), findsNothing);
        expect(find.text('Private'), findsNothing);
        expect(find.byType(ActionChip), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('suggestions rotate on every fresh home screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<Set<String>> chipsOnFreshHome(int key) async {
      final conversations = ConversationStore();
      addTearDown(conversations.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: FluxTheme.light,
          home: HomeShell(
            key: ValueKey('fresh-home-$key'),
            conversationStore: conversations,
            initializeServices: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      return tester
          .widgetList<ActionChip>(find.byType(ActionChip))
          .map((chip) => (chip.label as Text).data!)
          .toSet();
    }

    final first = await chipsOnFreshHome(0);
    final second = await chipsOnFreshHome(1);
    expect(first, hasLength(4));
    expect(second, hasLength(4));
    expect(first.difference(second).length, greaterThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome has no gradient and hides with a message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final conversations = ConversationStore();
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
    await tester.pump(const Duration(milliseconds: 300));

    // The gradient layer is gone permanently.
    expect(find.byKey(const ValueKey('welcome-gradient-fade')), findsNothing);
    expect(find.text("Hi, I'm Finn."), findsOneWidget);

    conversations
      ..startNew()
      ..add(ConversationRole.user, 'Hello');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text("Hi, I'm Finn."), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
