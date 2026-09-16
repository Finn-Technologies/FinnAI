import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/creation_generator.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/json_salvage.dart';

/// Drives the pipeline from canned model output, so every branch of
/// parse → validate → repair → fallback is covered without an engine.
class ScriptedCompletion {
  ScriptedCompletion(this.responses);

  final List<String> responses;
  final List<String> requests = [];
  int _index = 0;

  Future<String> call(String request) async {
    requests.add(request);
    final response = responses[_index.clamp(0, responses.length - 1)];
    _index++;
    return response;
  }
}

Future<
    ({
      CreationOutcome outcome,
      List<CreationStage> stages,
      ScriptedCompletion model
    })> run({
  required List<String> responses,
  required CreationKind kind,
  String prompt = 'a habit tracker',
  int maxRepairRounds = 1,
}) async {
  final model = ScriptedCompletion(responses);
  final generator = FinnCreationGenerator(
    complete: model.call,
    maxRepairRounds: maxRepairRounds,
  );
  final stages = <CreationStage>[];
  final outcome = await generator.generate(
    prompt: prompt,
    kind: kind,
    onStage: stages.add,
  );
  return (outcome: outcome, stages: stages, model: model);
}

const _validApp = '{"title":"Habit Tracker","summary":"Track daily habits.",'
    '"accent":"mint","nodes":['
    '{"type":"text","value":"Done: {count}","style":"title"},'
    '{"type":"button","label":"Add","action":{"kind":"set","key":"count","expr":"count + 1"}}]}';

const _invalidApp = '{"title":"Habit Tracker","summary":"Track habits.",'
    '"nodes":[{"type":"webview","url":"https://example.com"}]}';

const _validWidget = '{"title":"Hydration","summary":"Water.",'
    '"accent":"sky","rows":[{"label":"Glasses","value":"3"}],'
    '"footer":"Tap to open"}';

const _validDeck = '{"title":"Review","summary":"A deck.","slides":['
    '{"title":"Review","bullets":["One","Two"]},'
    '{"title":"Next","bullets":["Ship it"]}]}';

void main() {
  group('a valid first reply is used as-is', () {
    test('mini app', () async {
      final result = await run(
        responses: [_validApp],
        kind: CreationKind.app,
      );
      expect(result.outcome.usedFallback, isFalse);
      expect(result.outcome.title, 'Habit Tracker');
      expect(result.outcome.summary, 'Track daily habits.');
      expect(result.outcome.artifact, isA<MiniAppArtifact>());
      expect(result.model.requests, hasLength(1));
    });

    test('widget', () async {
      final result = await run(
        responses: [_validWidget],
        kind: CreationKind.widget,
      );
      expect(result.outcome.artifact, isA<WidgetArtifact>());
      expect(
        (result.outcome.artifact as WidgetArtifact).spec.rows.single.label,
        'Glasses',
      );
    });

    test('presentation', () async {
      final result = await run(
        responses: [_validDeck],
        kind: CreationKind.presentation,
      );
      expect(result.outcome.artifact, isA<PresentationArtifact>());
      expect(
        (result.outcome.artifact as PresentationArtifact).spec.slides,
        hasLength(2),
      );
    });

    test('reports designing, writing and validating in order', () async {
      final result = await run(
        responses: [_validApp],
        kind: CreationKind.app,
      );
      expect(result.stages, [
        CreationStage.designing,
        CreationStage.writing,
        CreationStage.validating,
      ]);
    });
  });

  group('repair round', () {
    test('re-prompts once with the validation errors and uses the fix',
        () async {
      final result = await run(
        responses: [_invalidApp, _validApp],
        kind: CreationKind.app,
      );

      expect(result.outcome.usedFallback, isFalse);
      expect(result.model.requests, hasLength(2));
      // The second request must quote the concrete problem back to the model.
      expect(result.model.requests[1], contains('webview'));
      expect(result.model.requests[1], contains('corrected JSON'));
      expect(result.stages, contains(CreationStage.repairing));
    });

    test('falls back when the repair is also invalid', () async {
      final result = await run(
        responses: [_invalidApp, _invalidApp],
        kind: CreationKind.app,
      );

      expect(result.outcome.usedFallback, isTrue);
      expect(result.model.requests, hasLength(2));
      expect(
        result.model.requests,
        hasLength(1 + 1),
        reason: 'exactly one repair round',
      );
    });

    test('honours maxRepairRounds of zero', () async {
      final result = await run(
        responses: [_invalidApp, _validApp],
        kind: CreationKind.app,
        maxRepairRounds: 0,
      );

      expect(result.outcome.usedFallback, isTrue);
      expect(result.model.requests, hasLength(1));
    });

    test('re-prompts when the reply is not JSON at all', () async {
      final result = await run(
        responses: ['I cannot help with that.', _validApp],
        kind: CreationKind.app,
      );

      expect(result.outcome.usedFallback, isFalse);
      expect(result.model.requests[1], contains('not a JSON object'));
    });
  });

  group('fallback', () {
    test('produces a runnable starter rather than an error', () async {
      final result = await run(
        responses: ['nonsense'],
        kind: CreationKind.app,
      );

      expect(result.outcome.usedFallback, isTrue);
      final spec = (result.outcome.artifact as MiniAppArtifact).spec;
      expect(spec.nodes, isNotEmpty);
      // The starter must be self-consistent: every displayed key is written.
      expect(spec.referencedKeys.difference(spec.writtenKeys), isEmpty);
    });

    test('names the creation after the brief', () async {
      final result = await run(
        responses: ['nonsense'],
        kind: CreationKind.app,
        prompt: 'a plant watering reminder',
      );
      expect(result.outcome.title, 'A plant watering reminder');
    });

    test('every kind has a distinct starter', () async {
      final app = await run(responses: ['x'], kind: CreationKind.app);
      final widget = await run(responses: ['x'], kind: CreationKind.widget);
      final deck = await run(responses: ['x'], kind: CreationKind.presentation);

      expect(app.outcome.artifact, isA<MiniAppArtifact>());
      expect(widget.outcome.artifact, isA<WidgetArtifact>());
      expect(deck.outcome.artifact, isA<PresentationArtifact>());
    });
  });

  group('json salvage feeds the pipeline', () {
    test('recovers a reply wrapped in a think block and fences', () async {
      final result = await run(
        responses: [
          '<think>planning the app</think>\n```json\n$_validApp\n```'
        ],
        kind: CreationKind.app,
      );
      expect(result.outcome.usedFallback, isFalse);
      expect(result.outcome.title, 'Habit Tracker');
    });

    test('recovers a reply truncated mid-object', () async {
      const truncated =
          '{"title":"Water","summary":"Hydration.","accent":"sky","nodes":['
          '{"type":"text","value":"Cups: {count}"},'
          '{"type":"button","label":"Add","action":{"kind":"set","key":"count","ex';
      final result = await run(
        responses: [truncated],
        kind: CreationKind.app,
      );
      // The salvaged spec is missing a complete action, so it is either
      // repaired or falls back — never a crash and never raw JSON in the UI.
      expect(result.outcome.title, isNotEmpty);
    });

    test('ignores a browser tool call emitted before the answer', () async {
      final result = await run(
        responses: [
          '<tool_call>{"name":"browser_search","arguments":{"query":"habits"}}'
              '</tool_call>$_validApp',
        ],
        kind: CreationKind.app,
      );
      expect(result.outcome.usedFallback, isFalse);
      expect(result.outcome.title, 'Habit Tracker');
    });
  });

  group('extractJsonObject', () {
    test('returns null when there is no object', () {
      expect(extractJsonObject('no json here'), isNull);
    });

    test('round-trips nested values', () {
      final decoded = extractJsonObject(
        'prefix {"a":{"b":[1,2,{"c":"}"}]}} suffix',
      );
      expect(decoded, isNotNull);
      expect(decoded!['a'], isA<Map<Object?, Object?>>());
    });

    test('strips an unterminated think block', () {
      expect(
        extractJsonObject('<think>still reasoning...'),
        isNull,
      );
    });
  });
}
