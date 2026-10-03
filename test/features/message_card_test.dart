import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/chat/message_card_view.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/conversations/message_card.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  group('a message remembers the card it made', () {
    ConversationMessage message({MessageCard? card}) => ConversationMessage(
          id: 'm',
          role: ConversationRole.assistant,
          text: 'Here it is',
          createdAt: DateTime(2026, 10, 2),
          card: card,
        );

    test('a card survives a save and a load', () {
      for (final card in const [
        MessageCard.creation('c-1'),
        MessageCard.flow('f-1'),
      ]) {
        final again =
            ConversationMessage.fromJson(message(card: card).toJson());
        expect(again.card, card);
      }
    });

    test('a message with no card stores none', () {
      expect(message().toJson().containsKey('card'), isFalse);
      expect(ConversationMessage.fromJson(message().toJson()).card, isNull);
    });

    test('a card this version does not know is ignored, not an error', () {
      final json = message().toJson()
        ..['card'] = {'kind': 'hologram', 'id': 'x'};
      expect(ConversationMessage.fromJson(json).card, isNull);
      json['card'] = 'junk';
      expect(ConversationMessage.fromJson(json).card, isNull);
      json['card'] = {'kind': 'flow', 'id': ''};
      expect(ConversationMessage.fromJson(json).card, isNull);
    });

    test('an edit keeps the card unless told otherwise', () {
      final original = message(card: const MessageCard.flow('f'));
      expect(original.copyWith(text: 'changed').card, original.card);
    });
  });

  group('the flow card', () {
    late Directory directory;
    late FlowsStore store;
    late FlowsActions actions;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('finn_card_');
      store = FlowsStore(directoryProvider: () async => directory);
      await store.initialize();
      actions = FlowsActions(store: store);
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    Future<String> addFlow({
      List<FlowTrigger> triggers = const [
        FlowTrigger.event(FlowTriggerKind.chargerConnected),
      ],
      List<FlowBlock> blocks = const [FlowBlock.notify('hi')],
    }) async {
      await store.upsertCustom(
        name: 'Charger note',
        description: '',
        instructions: '',
        enabled: false,
        blocks: blocks,
        triggers: triggers,
      );
      return store.flows.last.id;
    }

    Future<void> show(WidgetTester tester, String id) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: FluxTheme.light,
          home: Scaffold(
            body: MessageCardView(
              card: MessageCard.flow(id),
              host: MessageCardHost(flowActions: actions),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows what starts it and what it does', (tester) async {
      final id = await addFlow();
      await show(tester, id);

      expect(find.text('Charger note'), findsOneWidget);
      expect(find.text('Charger connected'), findsOneWidget);
      expect(find.text('Turn on'), findsOneWidget);
      expect(find.text('Open flow'), findsOneWidget);
    });

    testWidgets('Turn on switches it on', (tester) async {
      final id = await addFlow();
      await show(tester, id);

      await tester.tap(find.byKey(Key('flow-card-turn-on-$id')));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(store.flows.firstWhere((f) => f.id == id).enabled, isTrue);
      expect(find.text('Turned on'), findsOneWidget);
    });

    testWidgets('a flow that acts on the phone asks before it is turned on', (
      tester,
    ) async {
      final id = await addFlow(
        blocks: const [
          FlowBlock.action('torch', {'on': 'true'})
        ],
      );
      await show(tester, id);
      expect(
        find.textContaining('Allow it to run when you are not looking'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(Key('flow-card-turn-on-$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Our own question, not a silent switch.
      expect(find.textContaining('to act on your phone'), findsOneWidget);
      expect(store.flows.firstWhere((f) => f.id == id).enabled, isFalse);
      expect(store.flows.firstWhere((f) => f.id == id).granted, isFalse);
    });

    testWidgets('a flow nothing starts has no Turn on', (tester) async {
      final id = await addFlow(triggers: const []);
      await show(tester, id);

      expect(find.text('Turn on'), findsNothing);
      expect(find.text('Open flow'), findsOneWidget);
    });

    testWidgets('a deleted flow leaves no card', (tester) async {
      await show(tester, 'gone');
      expect(find.byType(Text), findsNothing);
    });
  });
}
