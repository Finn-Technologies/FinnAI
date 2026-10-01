import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/you/you_memory_store.dart';
import 'package:finn_ai/src/features/you/you_page.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

void main() {
  late Directory directory;
  late YouMemoryStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_you_');
    store = YouMemoryStore(directoryProvider: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  group('YouMemoryStore', () {
    test('keeps what is added and does not duplicate it', () async {
      await store.initialize();
      await store.add('You like short answers', YouCategory.preferences);
      await store.add('you like short answers', YouCategory.preferences);

      expect(store.keptCount, 1);
      expect(store.inCategory(YouCategory.preferences), hasLength(1));
    });

    test('survives a restart', () async {
      await store.initialize();
      await store.add('Marta runs the workshop', YouCategory.people);

      final again = YouMemoryStore(directoryProvider: () async => directory);
      await again.initialize();
      expect(again.kept.single.text, 'Marta runs the workshop');
    });

    test('observe queues a statement for review, not as kept', () async {
      await store.initialize();
      await store.observe('I am a product designer in Rome', 'Greetings');

      expect(store.keptCount, 0);
      expect(store.pending.single.text, 'You are a product designer in Rome');
      expect(store.pending.single.sources, ['Greetings']);
    });

    test('observe does nothing while learning is off', () async {
      await store.initialize();
      await store.setLearn(false);
      await store.observe('I am learning Italian', 'Chat');
      expect(store.pending, isEmpty);
    });

    test('the prompt names only kept, unmuted items and records them',
        () async {
      await store.initialize();
      await store.add('You are learning Italian', YouCategory.interests);
      final muted = await store.add('Secret thing', YouCategory.work);
      await store.update(muted!.id, useInChats: false);
      await store.observe('I like trains', 'Chat');

      final context = store.promptContextFor('help me with Italian');

      expect(context, contains('You are learning Italian'));
      expect(context, isNot(contains('Secret thing')));
      expect(context, isNot(contains('trains')));
      expect(store.lastUsed, hasLength(1));
    });

    test('use in new chats off gives the model nothing', () async {
      await store.initialize();
      await store.add('You are learning Italian', YouCategory.interests);
      await store.setUseInNewChats(false);

      expect(store.promptContextFor('Italian'), isEmpty);
      expect(store.lastUsed, isEmpty);
    });

    test('deleteStorage removes the file and the items', () async {
      await store.initialize();
      await store.add('One', YouCategory.work);
      expect(await store.deleteStorage(), isEmpty);

      expect(store.keptCount, 0);
      expect(File('${directory.path}/you_memory.json').existsSync(), isFalse);
    });
  });

  testWidgets('You shows the empty state, then the six groups', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shared = YouMemoryStore.instance;
    await tester.runAsync(shared.deleteStorage);

    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: YouPage(onBack: () {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Still getting to know you'), findsOneWidget);

    await tester.runAsync(
      () => shared.add('You are a designer', YouCategory.work),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('What FinnAI knows about you'), findsOneWidget);
    for (final label in ['People', 'Work', 'Routines', 'Preferences']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.runAsync(shared.deleteStorage);
  });
}
