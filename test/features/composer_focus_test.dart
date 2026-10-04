import 'package:finn_ai/src/features/chat/home_shell.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'on a desktop the composer has the cursor as soon as the app opens',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
  });
}
