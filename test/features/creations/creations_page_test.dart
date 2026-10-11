import 'dart:async';
import 'dart:io';

import 'package:finn_ai/src/platform/platform_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/creation_generator.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/features/creations/creations_controller.dart';
import 'package:finn_ai/src/features/creations/creations_page.dart';
import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/widget_spec.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// A generator the test drives directly, so progress and completion states can
/// be asserted without an engine.
class FakeGenerator implements CreationGenerator {
  FakeGenerator({required this.artifact});

  CreationArtifact artifact;
  int calls = 0;
  String? lastPrompt;
  final List<CreationStage> stages = [];
  Completer<void>? gate;

  @override
  Future<CreationOutcome> generate({
    required String prompt,
    required CreationKind kind,
    required void Function(CreationStage stage) onStage,
  }) async {
    calls++;
    lastPrompt = prompt;
    onStage(CreationStage.designing);
    stages.add(CreationStage.designing);
    if (gate != null) await gate!.future;
    onStage(CreationStage.validating);
    return CreationOutcome(
      title: 'Habit Tracker',
      summary: 'Track a daily habit.',
      artifact: artifact,
    );
  }
}

/// A generator that always fails, standing in for a model that produced
/// nothing usable even after its repair round.
class _FailingGenerator implements CreationGenerator {
  @override
  Future<CreationOutcome> generate({
    required String prompt,
    required CreationKind kind,
    required void Function(CreationStage stage) onStage,
  }) async {
    onStage(CreationStage.designing);
    throw const CreationUnusable('nothing usable');
  }
}

const _appArtifact = MiniAppArtifact(
  MiniAppSpec(
    title: 'Habit Tracker',
    accent: MiniAppAccent.mint,
    nodes: [
      TextNode(value: 'Done: {count}', role: MiniAppTextRole.title),
      ButtonNode(
        label: 'Add',
        action: IncrementAction(key: 'count', by: 1),
      ),
    ],
  ),
);

const _widgetArtifact = WidgetArtifact(
  HomeWidgetSpec(
    title: 'Hydration',
    accent: MiniAppAccent.sky,
    rows: [HomeWidgetRow(label: 'Glasses', value: '3')],
  ),
);

const _deckArtifact = PresentationArtifact(
  DeckSpec(
    title: 'Review',
    slides: [
      DeckSlide(title: 'Review', bullets: ['One']),
      DeckSlide(title: 'Next', bullets: ['Ship it']),
    ],
  ),
);

FinnCreation _creation({
  required String id,
  required String title,
  required CreationArtifact artifact,
  int day = 1,
}) =>
    FinnCreation(
      id: id,
      prompt: 'a brief',
      title: title,
      summary: 'summary',
      artifact: artifact,
      createdAt: DateTime(2026, 7, day),
    );

void main() {
  // The creations page reads its store from disk on open. Real file I/O never
  // completes under the default test binding's fake clock, so these tests run
  // on the live binding where asynchronous work resolves on the real clock.
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late CreationStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn_page_');
    store = CreationStore(directoryProvider: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  /// Pumps the page and waits for its store load to settle.
  ///
  /// The page loads its creations on open; on the live binding that resolves on
  /// the real clock, so a short real pause is what makes the loaded state
  /// observable.
  Future<CreationsController> pumpPage(
    WidgetTester tester, {
    required CreationGenerator generator,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = CreationsController(store, generator);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: CreationsPage(controller: controller),
      ),
    );
    await tester.pump();
    // Wait for the page's own load to finish rather than guessing a duration:
    // the live binding does real I/O and can be slow under a full-suite run.
    for (var attempt = 0; attempt < 60 && controller.loading; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    expect(controller.loading, isFalse, reason: 'store load did not settle');
    await tester.pump(const Duration(milliseconds: 60));
    return controller;
  }

  /// Taps after scrolling the target into view: both the transcript and the
  /// gallery are scrollable, so a control can legitimately be off-screen.
  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  /// Chooses what to make from the "Create" sheet, from the gallery's plus or
  /// from the builder's attachment button.
  Future<void> chooseKind(WidgetTester tester, String label) async {
    final plus = find.bySemanticsLabel('New creation');
    if (plus.evaluate().isNotEmpty) {
      await tester.tap(plus);
    } else {
      await tester.tap(find.byKey(const ValueKey('add-attachment-button')));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final name = switch (label) {
      'App' => 'app',
      'Widget' => 'widget',
      _ => 'presentation',
    };
    await tester.tap(find.byKey(Key('creation-kind-$name')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Waits until the generation job (including its persistence write) is done.
  ///
  /// Saving created the file on disk, so the live binding needs real time.
  Future<void> waitForGeneration(
    WidgetTester tester,
    CreationsController controller,
  ) async {
    for (var attempt = 0; attempt < 60 && controller.generating; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 60));
  }

  Future<void> send(WidgetTester tester, String brief) async {
    await tester.enterText(find.byType(TextField), brief);
    await tester.pump();
    // The composer is the shared chat one, so its action carries the shared
    // label rather than a Creations-specific one.
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  group('builder', () {
    testWidgets('an empty store shows the empty gallery and a plus', (
      tester,
    ) async {
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      expect(find.text('No Creations yet.'), findsOneWidget);
      expect(find.bySemanticsLabel('New creation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('choosing a kind asks for the brief', (tester) async {
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      await chooseKind(tester, 'Widget');

      expect(find.text('Tell me what your Widget should do.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kind then brief generates and shows the artifact', (
      tester,
    ) async {
      final generator = FakeGenerator(artifact: _appArtifact);
      final controller = await pumpPage(tester, generator: generator);

      await chooseKind(tester, 'App');
      await send(tester, 'a habit tracker');
      await waitForGeneration(tester, controller);

      expect(generator.calls, 1);
      expect(find.text('Habit Tracker'), findsWidgets);
      expect(find.text('2 elements'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows progress while generating and a stop control', (
      tester,
    ) async {
      final generator = FakeGenerator(artifact: _appArtifact)
        ..gate = Completer<void>();
      final controller = await pumpPage(tester, generator: generator);

      await chooseKind(tester, 'App');
      await send(tester, 'a habit tracker');
      await tester.pump();

      expect(find.text('Designing…'), findsOneWidget);
      expect(find.bySemanticsLabel('Stop generating'), findsOneWidget);
      expect(find.text('Open'), findsNothing);

      generator.gate!.complete();
      await waitForGeneration(tester, controller);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a failed generation shows a try-again message, not a stand-in',
      (tester) async {
        final controller = await pumpPage(
          tester,
          generator: _FailingGenerator(),
        );

        await chooseKind(tester, 'App');
        await send(tester, 'something impossible');
        await waitForGeneration(tester, controller);

        expect(
          find.text('Finn could not finish that creation. Please try again.'),
          findsOneWidget,
        );
        expect(find.text('Open'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('gallery', () {
    testWidgets('saved creations appear as round tiles with their titles', (
      tester,
    ) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
        _creation(
          id: 'b',
          title: 'BT Audio Receiver',
          artifact: _widgetArtifact,
          day: 2,
        ),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      expect(find.text('Flappy Bird'), findsOneWidget);
      expect(find.text('BT Audio Receiver'), findsOneWidget);
      // The filter row is the gallery's distinguishing feature.
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Apps'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filters narrow the tiles to one kind', (tester) async {
      // Widgets are a phone's home-screen feature, hidden on a desktop.
      debugSetFinnPlatformOverride(FinnPlatform.android);
      addTearDown(() => debugSetFinnPlatformOverride(null));
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
        _creation(
          id: 'b',
          title: 'BT Audio Receiver',
          artifact: _widgetArtifact,
          day: 2,
        ),
        _creation(
          id: 'c',
          title: 'Quarterly Review',
          artifact: _deckArtifact,
          day: 3,
        ),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      await tapText(tester, 'Widgets');

      expect(find.text('BT Audio Receiver'), findsOneWidget);
      expect(find.text('Flappy Bird'), findsNothing);
      expect(find.text('Quarterly Review'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a filtered kind with nothing saved shows the empty state', (
      tester,
    ) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      await tapText(tester, 'Presentations');

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the plus offers the three kinds', (tester) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      await tester.tap(find.bySemanticsLabel('New creation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Widget'), findsOneWidget);
      expect(find.text('Mini app'), findsWidgets);
      expect(find.text('Presentation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('choosing a kind opens the builder with it chosen', (
      tester,
    ) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      await chooseKind(tester, 'Widget');

      expect(find.text('New widget'), findsOneWidget);
      expect(find.text('Tell me what your Widget should do.'), findsOneWidget);
    });

    testWidgets('the composer attachment button opens the Create sheet', (
      tester,
    ) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));
      await chooseKind(tester, 'App');

      await tester.tap(find.byKey(const ValueKey('add-attachment-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Create'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the builder offers a way back to the saved creations', (
      tester,
    ) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      await tester.tap(find.bySemanticsLabel('New creation'));
      await tester.pump(const Duration(milliseconds: 60));
      // In the builder the "All" control switches back to the gallery.
      await tapText(tester, 'All');

      expect(find.text('Flappy Bird'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cards sit in two columns', (tester) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
        _creation(
          id: 'b',
          title: 'BT Audio Receiver',
          artifact: _widgetArtifact,
          day: 2,
        ),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      final a = tester.getCenter(find.text('Flappy Bird'));
      final b = tester.getCenter(find.text('BT Audio Receiver'));
      expect((a.dx - b.dx).abs(), greaterThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long press opens the creation menu', (tester) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      await tester.longPress(find.text('Flappy Bird'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      for (final label in [
        'Open',
        'Edit with FinnAI',
        'Add to home screen',
        'Share',
        'Duplicate',
        'Delete',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });
  });

  group('no templates', () {
    testWidgets('choosing a kind goes straight to describing the brief', (
      tester,
    ) async {
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));
      await chooseKind(tester, 'App');

      // No "want a starting point?" chips: the model designs it.
      expect(find.text('Let Finn choose'), findsNothing);
      expect(find.text('Counter'), findsNothing);
      expect(find.text('Scoreboard'), findsNothing);
      expect(find.text('Tell me what your App should do.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the brief reaches the generator unchanged', (tester) async {
      final generator = FakeGenerator(artifact: _appArtifact);
      final controller = await pumpPage(tester, generator: generator);

      await chooseKind(tester, 'App');
      await send(tester, 'keep score of game night');
      await waitForGeneration(tester, controller);

      expect(generator.lastPrompt, 'keep score of game night');
      expect(generator.calls, 1);
    });

    testWidgets('a generated creation offers Open, never Edit', (tester) async {
      final generator = FakeGenerator(artifact: _appArtifact);
      final controller = await pumpPage(tester, generator: generator);

      await chooseKind(tester, 'App');
      await send(tester, 'a habit tracker');
      await waitForGeneration(tester, controller);

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    });
  });

  group('tap targets', () {
    testWidgets('gallery filter chips are at least 48dp tall', (tester) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      final chip = find.ancestor(
        of: find.text('All'),
        matching: find.byType(InkWell),
      );
      expect(chip, findsOneWidget);
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  });
}
