import 'dart:async';
import 'dart:io';

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
import 'package:finn_ai/src/features/creations/templates/template_catalog.dart';
import 'package:finn_ai/src/features/creations/templates/template_slots.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// A generator the test drives directly, so progress and completion states can
/// be asserted without an engine.
class FakeGenerator implements CreationGenerator {
  FakeGenerator({
    required this.artifact,
    this.usedFallback = false,
    this.template,
  });

  CreationArtifact artifact;
  bool usedFallback;
  TemplateRef? template;
  String? lastTemplateId;
  int calls = 0;
  final List<CreationStage> stages = [];
  Completer<void>? gate;

  @override
  Future<CreationOutcome> generate({
    required String prompt,
    required CreationKind kind,
    required void Function(CreationStage stage) onStage,
    String? templateId,
  }) async {
    calls++;
    lastTemplateId = templateId;
    onStage(CreationStage.designing);
    stages.add(CreationStage.designing);
    if (gate != null) await gate!.future;
    onStage(CreationStage.validating);
    return CreationOutcome(
      title: 'Habit Tracker',
      summary: 'Track a daily habit.',
      artifact: artifact,
      usedFallback: usedFallback,
      template: template,
    );
  }
}

const _appArtifact = MiniAppArtifact(
  MiniAppSpec(
    title: 'Habit Tracker',
    accent: MiniAppAccent.mint,
    nodes: [
      TextNode(value: 'Done: {count}', role: MiniAppTextRole.title),
      ButtonNode(label: 'Add', action: IncrementAction(key: 'count', by: 1)),
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

  Future<void> chooseKind(WidgetTester tester, String label) =>
      tapText(tester, label);

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
    testWidgets('an empty store opens the kind question with three answers',
        (tester) async {
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      expect(
        find.text('Is your new Creation an app, a widget or a presentation?'),
        findsOneWidget,
      );
      expect(find.text('App'), findsOneWidget);
      expect(find.text('Widget'), findsOneWidget);
      expect(find.text('Presentation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('choosing a kind asks for the brief', (tester) async {
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      await chooseKind(tester, 'Widget');

      expect(find.text('Tell me what your Widget should do.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a brief sent before the kind keeps the brief and asks', (
      tester,
    ) async {
      final generator = FakeGenerator(artifact: _appArtifact);
      await pumpPage(tester, generator: generator);

      await send(tester, 'a plant watering reminder');

      expect(find.text('a plant watering reminder'), findsOneWidget);
      expect(
        find.text('Is your new Creation an app, a widget or a presentation?'),
        findsOneWidget,
      );
      expect(generator.calls, 0);
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

    testWidgets('a brief sent first then a kind generates immediately', (
      tester,
    ) async {
      final generator = FakeGenerator(artifact: _appArtifact);
      final controller = await pumpPage(tester, generator: generator);

      await send(tester, 'a habit tracker');
      await chooseKind(tester, 'App');
      await waitForGeneration(tester, controller);

      expect(generator.calls, 1);
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

      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('notes when a starter template was substituted', (
      tester,
    ) async {
      final generator = FakeGenerator(
        artifact: _appArtifact,
        usedFallback: true,
      );
      final controller = await pumpPage(tester, generator: generator);

      await chooseKind(tester, 'App');
      await send(tester, 'something impossible');
      await waitForGeneration(tester, controller);

      expect(
        find.textContaining('working starter'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
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

    testWidgets('the new-creation action returns to the builder', (
      tester,
    ) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      await tapText(tester, 'New creation');

      expect(
        find.text('Is your new Creation an app, a widget or a presentation?'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    // On device this pill is the most obvious way in — it sits where the chat
    // composer sits and is the only control above the fold once the gallery has
    // a few tiles, because "New creation" scrolls out of view. Tapping it must
    // open the kind picker.
    testWidgets('the composer attachment button opens the kind picker', (
      tester,
    ) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      await tester.tap(
        find.byKey(const ValueKey('add-attachment-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('App'), findsOneWidget);
      expect(find.text('Widget'), findsOneWidget);
      expect(find.text('Presentation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the builder offers a way back to the saved creations', (
      tester,
    ) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      await tapText(tester, 'New creation');
      // In the builder the "All" control switches back to the gallery.
      await tapText(tester, 'All');

      expect(find.text('Flappy Bird'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tiles stagger into two columns with a clear gutter', (
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

      final labels = [
        tester.getCenter(find.text('Flappy Bird')),
        tester.getCenter(find.text('BT Audio Receiver')),
      ]..sort((a, b) => a.dx.compareTo(b.dx));
      final left = labels.first;
      final right = labels.last;

      // Side by side, in separate columns rather than stacked.
      expect(right.dx, greaterThan(left.dx + 40));
      // The right column rides lower, as in the reference grid.
      expect(right.dy, greaterThan(left.dy + 20));
      expect(tester.takeException(), isNull);
    });
  });

  group('templates', () {
    testWidgets('choosing an app offers its templates, and Finn by default', (
      tester,
    ) async {
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));
      await chooseKind(tester, 'App');

      expect(find.text('Let Finn choose'), findsOneWidget);
      for (final name in ['Counter', 'Checklist', 'List', 'Scoreboard']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('Big number'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a widget offers widget templates only', (tester) async {
      await pumpPage(tester,
          generator: FakeGenerator(artifact: _widgetArtifact));
      await chooseKind(tester, 'Widget');

      expect(find.text('Big number'), findsOneWidget);
      expect(find.text('Lines'), findsOneWidget);
      expect(find.text('Scoreboard'), findsNothing);
    });

    testWidgets('a presentation has no template question', (tester) async {
      await pumpPage(tester, generator: FakeGenerator(artifact: _deckArtifact));
      await chooseKind(tester, 'Presentation');

      expect(find.text('Let Finn choose'), findsNothing);
      expect(find.text('Tell me what your Presentation should do.'),
          findsOneWidget);
    });

    testWidgets('the chosen template reaches the generator', (tester) async {
      final generator = FakeGenerator(artifact: _appArtifact);
      final controller = await pumpPage(tester, generator: generator);

      await chooseKind(tester, 'App');
      await tapText(tester, 'Scoreboard');
      await send(tester, 'keep score of game night');
      await waitForGeneration(tester, controller);

      expect(generator.lastTemplateId, 'scoreboard');
    });

    testWidgets('no choice leaves the decision to the app', (tester) async {
      final generator = FakeGenerator(artifact: _appArtifact);
      final controller = await pumpPage(tester, generator: generator);

      await chooseKind(tester, 'App');
      await send(tester, 'keep score of game night');
      await waitForGeneration(tester, controller);

      expect(generator.lastTemplateId, isNull);
    });

    testWidgets('the template chips are at least 48dp tall', (tester) async {
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));
      await chooseKind(tester, 'App');

      for (final name in ['Let Finn choose', 'Counter', 'Scoreboard']) {
        final chip = find.ancestor(
          of: find.text(name),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(chip.first).height, greaterThanOrEqualTo(48),
            reason: name);
      }
    });

    testWidgets('a template-made creation can be edited without the model', (
      tester,
    ) async {
      final counter = CreationTemplates.byId('counter')!;
      final values = SlotSanitizer.sanitize(counter.slots, {
        'title': 'Water tracker',
        'goal': 8,
      });
      final generator = FakeGenerator(
        artifact: counter.build(values),
        template: TemplateRef(id: 'counter', slots: values.toJson()),
      );
      final controller = await pumpPage(tester, generator: generator);

      await chooseKind(tester, 'App');
      await send(tester, 'count my water');
      await waitForGeneration(tester, controller);
      expect(find.text('Edit'), findsOneWidget);

      await tapText(tester, 'Edit');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Edit details · Counter'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Name'), 'Tea cups');
      await tester.enterText(find.widgetWithText(TextField, 'Goal'), '3');
      await tester.tap(find.text('Save'));
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }

      final saved = controller.creations.single;
      expect(saved.title, 'Tea cups');
      expect(saved.template?.slots['goal'], 3);
      expect(generator.calls, 1, reason: 'editing must not call the model');
      expect(find.text('Tea cups'), findsWidgets);
    });

    testWidgets('a creation with no template has no Edit button', (
      tester,
    ) async {
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
    testWidgets('the tile badge keeps a 48dp hit area around its 30dp circle',
        (tester) async {
      await store.save([
        _creation(id: 'a', title: 'Flappy Bird', artifact: _appArtifact),
      ]);
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      final badge = find.bySemanticsLabel('Add to home screen');
      expect(badge, findsOneWidget);
      final size = tester.getSize(badge);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

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

    testWidgets('the kind answers are at least 48dp tall', (tester) async {
      await pumpPage(tester, generator: FakeGenerator(artifact: _appArtifact));

      final answer = find.ancestor(
        of: find.text('Widget'),
        matching: find.byType(InkWell),
      );
      expect(answer, findsOneWidget);
      expect(tester.getSize(answer).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  });
}
