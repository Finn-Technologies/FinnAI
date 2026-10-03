import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_host.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_persistence.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_state.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';

const _spec = MiniAppSpec(
  title: 'Shopping',
  accent: MiniAppAccent.mint,
  nodes: [
    ImageNode(emoji: '🛒', url: ''),
    FieldNode(key: 'draft', hint: 'Add an item'),
    ButtonNode(
      label: 'Add',
      action: AppendAction(key: 'items', value: '{draft}', clearKey: 'draft'),
    ),
    ListNode(bind: 'items', empty: 'Nothing yet'),
    ToggleNode(key: 'done', label: 'Done'),
    ButtonNode(label: 'More', action: IncrementAction(key: 'count', by: 1)),
    TextNode(value: 'Count: {count}', role: MiniAppTextRole.body),
  ],
);

void main() {
  group('restoring saved state', () {
    test('values of the right shape come back', () {
      final state = MiniAppState(_spec)
        ..restore({
          'items': ['milk', 'eggs'],
          'done': true,
          'count': 4,
          'draft': 'half typed',
        });
      expect(state.valueOf('items'), ['milk', 'eggs']);
      expect(state.valueOf('done'), true);
      expect(state.valueOf('count'), 4);
      expect(state.valueOf('draft'), 'half typed');
    });

    test('a value of the wrong shape is ignored, not trusted', () {
      final state = MiniAppState(_spec)
        ..restore({
          'items': 'not a list',
          'done': 'yes',
          'count': 'many',
          'draft': 7,
        });
      expect(state.valueOf('items'), isEmpty);
      expect(state.valueOf('done'), false);
      expect(state.valueOf('count'), 0);
      // A number where text belongs is read as that number's text.
      expect(state.valueOf('draft'), '7');
    });

    test('keys the app no longer has are dropped', () {
      final state = MiniAppState(_spec)..restore({'gone': 'x', 'count': 2});
      expect(state.values.containsKey('gone'), isFalse);
      expect(state.valueOf('count'), 2);
    });

    test('text and lists are capped', () {
      final state = MiniAppState(_spec)
        ..restore({
          'draft': 'x' * 5000,
          'items': [for (var i = 0; i < 1000; i++) 'item $i'],
        });
      expect((state.valueOf('draft')! as String).length,
          MiniAppState.maxSavedText);
      expect(
          (state.valueOf('items')! as List).length, MiniAppState.maxSavedItems);
    });

    test('reset goes back to the starting values, not the saved ones', () {
      final state = MiniAppState(_spec)..restore({'count': 9});
      state.reset();
      expect(state.valueOf('count'), 0);
    });
  });

  group('the store', () {
    late Directory directory;
    late MiniAppStateStore store;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('finn_app_state_');
      store = MiniAppStateStore(
        store: CreationStore(directoryProvider: () async => directory),
      );
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('values survive a save and a load', () async {
      await store.save('a-1', {
        'count': 3,
        'items': ['milk'],
      });
      expect(await store.load('a-1'), {
        'count': 3,
        'items': ['milk'],
      });
    });

    test('an app that never saved loads as empty', () async {
      expect(await store.load('nothing'), isEmpty);
    });

    test('a damaged file loads as empty instead of throwing', () async {
      await store.save('a-2', {'count': 1});
      final dir = await CreationStore(directoryProvider: () async => directory)
          .appStateDirectory();
      await File('${dir.path}/a-2.json').writeAsString('{ not json');
      expect(await store.load('a-2'), isEmpty);
    });

    test('an id cannot walk out of the folder', () async {
      await store.save('../../escape', {'count': 1});
      final dir = await CreationStore(directoryProvider: () async => directory)
          .appStateDirectory();
      expect(
        dir.listSync().map((e) => e.path.split('/').last),
        everyElement(isNot(contains('/'))),
      );
      expect(File('${directory.parent.path}/escape.json').existsSync(), false);
    });

    test('clear forgets', () async {
      await store.save('a-3', {'count': 1});
      await store.clear('a-3');
      expect(await store.load('a-3'), isEmpty);
    });

    test('autosave restores, then writes a change after the delay', () async {
      await store.save('a-4', {'count': 5});
      final state = MiniAppState(_spec);
      final autosave = MiniAppAutosave(
        creationId: 'a-4',
        state: state,
        store: store,
        delay: const Duration(milliseconds: 20),
      );
      await autosave.start();
      expect(state.valueOf('count'), 5);

      state.dispatch(const IncrementAction(key: 'count', by: 1));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect((await store.load('a-4'))['count'], 6);
      autosave.dispose();
    });

    test('closing the app writes the last change without waiting', () async {
      final state = MiniAppState(_spec);
      final autosave = MiniAppAutosave(
        creationId: 'a-5',
        state: state,
        store: store,
        delay: const Duration(seconds: 30),
      );
      await autosave.start();
      state.dispatch(const IncrementAction(key: 'count', by: 2));
      autosave.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect((await store.load('a-5'))['count'], 2);
    });
  });

  group('the host', () {
    Widget host() => MaterialApp(
          theme: FluxTheme.light,
          home: MiniAppHost(title: 'Shopping', spec: _spec, onBack: () {}),
        );

    testWidgets('owns the whole screen: no page header above the app', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.byType(FinnPageHeader), findsNothing);
      // The title is drawn once, large, inside the app.
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.byKey(const ValueKey('page-back-button')), findsOneWidget);
    });

    testWidgets('the leading emoji sits beside the title, not in the body', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host());
      await tester.pump();
      expect(find.text('🛒'), findsOneWidget);
    });

    testWidgets('a button changes the app and the screen shows it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host());
      await tester.pump();
      expect(find.text('Count: 0'), findsOneWidget);
      await tester.tap(find.text('More'));
      await tester.pump();
      expect(find.text('Count: 1'), findsOneWidget);
    });
  });
}
