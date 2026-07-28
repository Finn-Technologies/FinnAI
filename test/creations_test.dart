import 'dart:io';

import 'package:finn_ai/src/creations/creation_generator.dart';
import 'package:finn_ai/src/creations/creation_model.dart';
import 'package:finn_ai/src/creations/creation_store.dart';
import 'package:finn_ai/src/creations/creations_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCreationGenerator implements CreationGenerator {
  FakeCreationGenerator({this.fail = false});

  final bool fail;
  int calls = 0;

  @override
  Future<CreationDraft> generate(String prompt, CreationKind kind) async {
    calls++;
    if (fail) throw StateError('generation failed');
    return CreationDraft(
      title: 'Pocket Planner',
      summary: 'A focused ${kind.label.toLowerCase()} for $prompt.',
      sections: const [
        CreationSection(
          heading: 'Experience',
          body: 'Capture a task and see the next useful action.',
        ),
      ],
    );
  }
}

void main() {
  late Directory temporaryDirectory;
  late CreationStore store;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'finn_creations_',
    );
    store = CreationStore(directoryProvider: () async => temporaryDirectory);
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('creation model round-trips through the versioned JSON store', () async {
    final createdAt = DateTime(2026, 7, 27, 12, 30);
    final creation = FinnCreation(
      id: 'one',
      kind: CreationKind.app,
      prompt: 'Make a calm task manager',
      title: 'Calm Tasks',
      summary: 'A distraction-free task manager.',
      sections: const [
        CreationSection(heading: 'Flow', body: 'Capture, choose, complete.'),
      ],
      createdAt: createdAt,
    );

    await store.save([creation]);
    final restored = await store.load();

    expect(restored, hasLength(1));
    expect(restored.single.id, 'one');
    expect(restored.single.kind, CreationKind.app);
    expect(restored.single.createdAt, createdAt);
    expect(restored.single.sections.single.heading, 'Flow');
  });

  test('damaged storage is quarantined instead of overwritten', () async {
    final directory = Directory('${temporaryDirectory.path}/creations');
    await directory.create();
    final file = File('${directory.path}/creations.json');
    await file.writeAsString('{not json');

    await expectLater(store.load(), throwsFormatException);
    expect(file.existsSync(), isFalse);
    final quarantined = directory
        .listSync()
        .whereType<File>()
        .where((item) => item.path.contains('.damaged-'))
        .toList();
    expect(quarantined, hasLength(1));
    expect(await quarantined.single.readAsString(), '{not json');
  });

  test('deleteStorage clears every persisted creation', () async {
    final creation = FinnCreation(
      id: 'delete-me',
      kind: CreationKind.presentation,
      prompt: 'A launch presentation',
      title: 'Launch',
      summary: 'A compact launch narrative.',
      sections: const [],
      createdAt: DateTime(2026, 7, 27),
    );
    await store.save([creation]);

    expect(await store.deleteStorage(), isTrue);
    expect(await store.load(), isEmpty);
    expect(await store.deleteStorage(), isTrue);
  });

  test('controller creates, filters, persists and deletes creations', () async {
    final generator = FakeCreationGenerator();
    final clock = DateTime(2026, 7, 27, 14);
    final controller = CreationsController(
      store,
      generator,
      clock: () => clock,
    );
    await controller.load();

    final app = await controller.create('a private planner', CreationKind.app);
    final widget = await controller.create(
      'a weather glance',
      CreationKind.widget,
    );

    expect(generator.calls, 2);
    expect(controller.creations, hasLength(2));
    expect(controller.creations.first, widget);
    controller.setFilter(CreationKind.app);
    expect(controller.visible, [app]);

    final restored = CreationsController(store, FakeCreationGenerator());
    await restored.load();
    expect(restored.creations.map((item) => item.kind), [
      CreationKind.widget,
      CreationKind.app,
    ]);

    await restored.delete(restored.creations.first);
    expect(restored.creations.single.kind, CreationKind.app);
    expect((await store.load()).single.kind, CreationKind.app);
  });

  test('generation failure is surfaced without fabricating a record', () async {
    final controller = CreationsController(
      store,
      FakeCreationGenerator(fail: true),
    );
    await controller.load();

    final result = await controller.create('anything', CreationKind.app);

    expect(result, isNull);
    expect(controller.creations, isEmpty);
    expect(controller.generating, isFalse);
    expect(controller.error, contains('could not finish'));
  });

  test('structured model JSON is parsed from a fenced response', () {
    final draft = parseCreationDraft('''
Some preface
```json
{"title":"Daylight","summary":"A simple day planner.","sections":[{"heading":"Home","body":"Show today at a glance."}]}
```
''', 'planner');

    expect(draft.title, 'Daylight');
    expect(draft.summary, 'A simple day planner.');
    expect(draft.sections.single.heading, 'Home');
  });

  test('plain model output remains a useful creation fallback', () {
    final draft = parseCreationDraft(
      'Build three slides: problem, evidence, and next step.',
      'Quarterly review presentation for the design team',
    );

    expect(draft.title, 'Quarterly review presentation for the design');
    expect(draft.summary, contains('three slides'));
    expect(draft.sections, isEmpty);
  });

  test('truncated model JSON is recovered into a polished creation', () {
    final draft = parseCreationDraft(
      '{"title":"Water Tracker","summary":"A focused hydration app.",'
          '"sections":[{"heading":"Experience","body":"Log water in one tap."},'
          '{"heading":"Behavior","body":"Set',
      'water app',
    );

    expect(draft.title, 'Water Tracker');
    expect(draft.summary, 'A focused hydration app.');
    expect(draft.sections, hasLength(1));
    expect(draft.sections.single.heading, 'Experience');
  });
}
