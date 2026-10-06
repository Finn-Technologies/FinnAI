import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/chat/home_shell.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
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

        expect(find.text("Hi, what's on your mind?"), findsOneWidget);
        // The design's empty slate is the greeting and the composer alone: no
        // suggestion chips, no feature pills and no brand mark in the header.
        expect(find.byType(ActionChip), findsNothing);
        expect(find.text('Try asking'), findsNothing);
        expect(find.text('On-device'), findsNothing);
        expect(find.text('Offline'), findsNothing);
        expect(find.text('Private'), findsNothing);
        expect(find.text('FinnAI'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the greeting sits in the middle of the empty canvas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 912);
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
    // Past the greeting's reveal, which lifts it the last few pixels.
    await tester.pump(const Duration(milliseconds: 1200));

    // The design centres the 24px greeting on the screen: 442..471 on a
    // 420x912 canvas.
    final greeting = tester.getRect(find.text("Hi, what's on your mind?"));
    expect(greeting.center.dy, closeTo(456, 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome has no gradient layer and hides with a message', (
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

    expect(find.byKey(const ValueKey('welcome-gradient-fade')), findsNothing);
    expect(find.text("Hi, what's on your mind?"), findsOneWidget);

    conversations
      ..startNew()
      ..add(ConversationRole.user, 'Hello');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text("Hi, what's on your mind?"), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
