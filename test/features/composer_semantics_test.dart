import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/chat/home_shell.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// TalkBack read the empty chat as one screen-sized text field labelled with
/// the greeting: the composer band carried a label and the text-field flag
/// without being a semantics container, so both merged into the node above.
void main() {
  testWidgets('the empty chat exposes one text field, the composer\'s own', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final conversations = ConversationStore();
    addTearDown(conversations.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: FluxTheme.dark,
      home: HomeShell(
        conversationStore: conversations,
        initializeServices: false,
      ),
    ));
    await tester.pump(const Duration(seconds: 2));

    final fields =
        find.semantics.byFlag(SemanticsFlag.isTextField).evaluate().toList();
    expect(fields, hasLength(1));
    final field = fields.single;
    expect(field.label, isNot(contains("what's on your mind")));
    expect(field.rect.height, lessThan(200), reason: 'not screen-sized');
    semantics.dispose();
  });
}
