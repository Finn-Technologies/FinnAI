import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/creation_fallbacks.dart';
import 'package:finn_ai/src/features/creations/templates/template_catalog.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';
import 'package:finn_ai/src/features/creations/creation_generator.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/features/creations/creations_controller.dart';
import 'package:finn_ai/src/features/creations/json_salvage.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';

/// Records the stages a generation reported, so the progress bubble is covered.
class FakeCreationGenerator implements CreationGenerator {
  FakeCreationGenerator({this.fail = false});

  final bool fail;
  int calls = 0;
  final List<CreationStage> stages = [];

  @override
  Future<CreationOutcome> generate({
    required String prompt,
    required CreationKind kind,
    required void Function(CreationStage stage) onStage,
    String? templateId,
  }) async {
    calls++;
    onStage(CreationStage.designing);
    stages.add(CreationStage.designing);
    if (fail) throw StateError('generation failed');
    onStage(CreationStage.validating);
    stages.add(CreationStage.validating);
    return CreationOutcome(
      title: 'Pocket Planner',
      summary: 'A focused ${kind.label.toLowerCase()} for $prompt.',
      artifact: _artifactFor(kind),
      usedFallback: false,
    );
  }
}

/// The artifact must match the requested kind, otherwise filtering by kind
/// would classify every fake creation as an app.
CreationArtifact _artifactFor(CreationKind kind) => switch (kind) {
      CreationKind.app => const MiniAppArtifact(_pocketPlannerSpec),
      CreationKind.widget => CreationTemplates.byId('stat')!.build(
          SlotSanitizer.sanitize(
              CreationTemplates.byId('stat')!.slots, const <String, Object?>{}),
        ),
      CreationKind.presentation => CreationFallbacks.starterDeck(),
    };

const _pocketPlannerSpec = MiniAppSpec(
  title: 'Pocket Planner',
  accent: MiniAppAccent.mint,
  nodes: [
    TextNode(value: 'Count: {count}', role: MiniAppTextRole.title),
    ButtonNode(label: 'Add', action: ResetAction()),
  ],
);

FinnCreation _creation({
  String id = 'one',
  String title = 'Calm Tasks',
  CreationKind kind = CreationKind.app,
  DateTime? createdAt,
}) =>
    FinnCreation(
      id: id,
      prompt: 'Make a calm task manager',
      title: title,
      summary: 'A distraction-free task manager.',
      artifact: _artifactFor(kind),
      createdAt: createdAt ?? DateTime(2026, 7, 27, 12, 30),
    );

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

  group('storage', () {
    test('creation model round-trips through the versioned JSON store',
        () async {
      final createdAt = DateTime(2026, 7, 27, 12, 30);
      await store.save([_creation(createdAt: createdAt)]);

      final restored = await store.load();

      expect(restored, hasLength(1));
      expect(restored.single.id, 'one');
      expect(restored.single.kind, CreationKind.app);
      expect(restored.single.createdAt, createdAt);
      expect(restored.single.artifact, isA<MiniAppArtifact>());
      final spec = (restored.single.artifact as MiniAppArtifact).spec;
      expect(spec.title, 'Pocket Planner');
      expect(spec.nodes, hasLength(2));
    });

    test('writes the current schema version', () async {
      await store.save([_creation()]);
      final raw = jsonDecode(
        await File('${temporaryDirectory.path}/creations/creations.json')
            .readAsString(),
      );
      expect(raw['version'], CreationStore.currentVersion);
    });

    test('upgrades version-1 records into runnable artifacts', () async {
      final directory = Directory('${temporaryDirectory.path}/creations');
      await directory.create(recursive: true);
      await File('${directory.path}/creations.json').writeAsString(
        jsonEncode({
          'version': 1,
          'creations': [
            {
              'id': 'legacy-1',
              'kind': 'presentation',
              'prompt': 'A launch deck',
              'title': 'Launch',
              'summary': 'A compact launch narrative.',
              'sections': [
                {'heading': 'Flow', 'body': 'Capture, choose, complete.'},
              ],
              'createdAt': '2026-07-27T12:30:00.000Z',
            },
          ],
        }),
      );

      final restored = await store.load();

      expect(restored, hasLength(1));
      final artifact = restored.single.artifact;
      expect(artifact, isA<LegacyDocumentArtifact>());
      // The original category is carried across so the filter the user last saw
      // the creation under does not silently change.
      expect(restored.single.kind, CreationKind.presentation);
      expect(
        (artifact as LegacyDocumentArtifact).sections.single.heading,
        'Flow',
      );
    });

    test('re-saving an upgraded store writes version 2', () async {
      final directory = Directory('${temporaryDirectory.path}/creations');
      await directory.create(recursive: true);
      await File('${directory.path}/creations.json').writeAsString(
        jsonEncode({
          'version': 1,
          'creations': [
            {
              'id': 'legacy-1',
              'kind': 'app',
              'prompt': 'p',
              'title': 'T',
              'summary': 'S',
              'sections': <Object?>[],
              'createdAt': '2026-07-27T12:30:00.000Z',
            },
          ],
        }),
      );

      await store.save(await store.load());

      final raw = jsonDecode(
        await File('${directory.path}/creations.json').readAsString(),
      );
      expect(raw['version'], CreationStore.currentVersion);
      expect(
        (raw['creations'] as List).single['artifact']['type'],
        'document',
      );
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

    test('an unsupported future version is quarantined', () async {
      final directory = Directory('${temporaryDirectory.path}/creations');
      await directory.create();
      await File(
        '${directory.path}/creations.json',
      ).writeAsString(jsonEncode({'version': 99, 'creations': <Object?>[]}));

      await expectLater(store.load(), throwsFormatException);
    });

    test('one damaged record does not hide the healthy ones', () async {
      final directory = Directory('${temporaryDirectory.path}/creations');
      await directory.create(recursive: true);
      await store.save([_creation(id: 'healthy')]);
      final file = File('${directory.path}/creations.json');
      final raw = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      (raw['creations'] as List).add({'id': 'broken'});
      await file.writeAsString(jsonEncode(raw));

      final restored = await store.load();

      expect(restored, hasLength(1));
      expect(restored.single.id, 'healthy');
    });

    test('deleteStorage clears every persisted creation', () async {
      await store.save([_creation()]);

      expect(await store.deleteStorage(), isTrue);
      expect(await store.load(), isEmpty);
      expect(await store.deleteStorage(), isTrue);
    });

    test('exportsDirectory lives under the creations folder', () async {
      final exports = await store.exportsDirectory();
      expect(exports.path, contains('creations'));
      expect(exports.existsSync(), isTrue);
    });
  });

  group('controller', () {
    test('creates, filters, persists and deletes creations', () async {
      final generator = FakeCreationGenerator();
      final clock = DateTime(2026, 7, 27, 14);
      final controller = CreationsController(
        store,
        generator,
        clock: () => clock,
      );
      await controller.load();

      final app =
          await controller.create('a private planner', CreationKind.app);
      final widget = await controller.create(
        'a weather glance',
        CreationKind.widget,
      );

      expect(app, isNotNull);
      expect(generator.calls, 2);
      expect(app!.usedFallback, isFalse);
      expect(controller.creations, hasLength(2));
      expect(controller.creations.first.title, 'Pocket Planner');
      expect(widget!.creation.kind, CreationKind.widget);
      controller.setFilter(CreationKind.app);
      expect(controller.visible.map((item) => item.id), [app.creation.id]);

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

    test('reports each generation stage then clears it', () async {
      final generator = FakeCreationGenerator();
      final controller = CreationsController(store, generator);
      await controller.load();

      final seen = <CreationStage?>[];
      controller.addListener(() => seen.add(controller.stage));

      await controller.create('a planner', CreationKind.app);

      expect(seen, contains(CreationStage.designing));
      expect(seen, contains(CreationStage.validating));
      expect(controller.stage, isNull);
      expect(controller.activePrompt, isNull);
    });

    test('exposes the active brief while generating', () async {
      final controller = CreationsController(store, FakeCreationGenerator());
      await controller.load();

      final future = controller.create('a tiny timer', CreationKind.app);
      expect(controller.generating, isTrue);
      expect(controller.activePrompt, 'a tiny timer');
      expect(controller.activeKind, CreationKind.app);
      await future;

      expect(controller.generating, isFalse);
      expect(controller.activePrompt, isNull);
    });

    test('a load that finishes after disposal does not throw', () async {
      // Closing the screen while the initial load is still in flight is normal,
      // and the store must not notify a disposed listener when it lands.
      final gate = Completer<void>();
      final slowStore = CreationStore(
        directoryProvider: () async {
          await gate.future;
          return temporaryDirectory;
        },
      );
      final controller =
          CreationsController(slowStore, FakeCreationGenerator());

      final loading = controller.load();
      controller.dispose();
      gate.complete();

      await expectLater(loading, completes);
    });

    test('generation failure is surfaced without fabricating a record',
        () async {
      final controller = CreationsController(
        store,
        FakeCreationGenerator(fail: true),
      );
      await controller.load();

      final result = await controller.create('anything', CreationKind.app);

      expect(result, isNull);
      expect(controller.creations, isEmpty);
      expect(controller.generating, isFalse);
      expect(controller.failure, CreationFailure.create);
      expect(controller.wasCancelled, isFalse);
    });

    test('an empty brief is ignored', () async {
      final generator = FakeCreationGenerator();
      final controller = CreationsController(store, generator);
      await controller.load();

      expect(await controller.create('   ', CreationKind.app), isNull);
      expect(generator.calls, 0);
    });

    test('a failed save rolls the list back', () async {
      final controller = CreationsController(
        store,
        FakeCreationGenerator(),
      );
      await controller.load();
      await controller.create('a planner', CreationKind.app);

      // Pointing the store at an unwritable path makes the follow-up save fail.
      await Directory('${temporaryDirectory.path}/creations').delete(
        recursive: true,
      );
      await File(
        '${temporaryDirectory.path}/creations',
      ).writeAsString('not a directory');

      final result = await controller.create('another', CreationKind.app);

      expect(result, isNull);
      expect(controller.creations, hasLength(1));
    });
  });

  group('json salvage prefers a spec-shaped object', () {
    test('skips a leading stray object for the real spec', () {
      final decoded = extractJsonObject(
        '{"note":"thinking"}\n'
        '{"title":"Counter","nodes":[{"type":"text","value":"hi"}]}',
      );
      expect(decoded?['title'], 'Counter');
    });

    test('still accepts an object that is merely first', () {
      expect(extractJsonObject('{"title":"Bare"}')?['title'], 'Bare');
    });

    test('a tool call is never mistaken for a spec', () {
      expect(
        extractJsonObject(
          '<tool_call>{"name":"browser_search","arguments":{}}</tool_call>',
        ),
        isNull,
      );
    });
  });
}
