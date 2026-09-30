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
  String? templateId,
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
    templateId: templateId,
  );
  return (outcome: outcome, stages: stages, model: model);
}

const _counterReply = '{"title":"Water tracker","unit":"Glasses","goal":8,'
    '"emoji":"💧","accent":"sky"}';

const _widgetReply = '{"title":"Reading streak","label":"Days in a row",'
    '"value":"12","footer":"Keep going","accent":"mint"}';

const _validDeck = '{"title":"Review","summary":"A deck.","theme":"midnight",'
    '"slides":[{"title":"Review","layout":"title","bullets":["One","Two"]},'
    '{"title":"Next","bullets":["Ship it"]}]}';

void main() {
  group('apps and widgets are filled into a template', () {
    test('a good reply becomes the chosen template', () async {
      final result = await run(
        responses: [_counterReply],
        kind: CreationKind.app,
        prompt: 'count how many glasses of water I drink',
      );
      expect(result.outcome.usedFallback, isFalse);
      expect(result.outcome.title, 'Water tracker');
      expect(result.outcome.artifact, isA<MiniAppArtifact>());
      expect(result.outcome.template?.id, 'counter');
      expect(result.outcome.template?.slots['goal'], 8);
      expect(result.model.requests, hasLength(1));
    });

    test('the app picks the template, the model is never asked to', () async {
      final result = await run(
        responses: ['{"title":"Groceries"}'],
        kind: CreationKind.app,
        prompt: 'a shopping list',
      );
      expect(result.outcome.template?.id, 'list');
      expect(result.model.requests.single, contains('list the user adds to'));
    });

    test('a chosen template id is honoured for its own kind only', () async {
      final scoreboard = await run(
        responses: ['{"title":"Game night","nameA":"Us","nameB":"Them"}'],
        kind: CreationKind.app,
        prompt: 'keep track of something',
        templateId: 'scoreboard',
      );
      expect(scoreboard.outcome.template?.id, 'scoreboard');
      final wrongKind = await run(
        responses: ['{"title":"x"}'],
        kind: CreationKind.widget,
        prompt: 'something',
        templateId: 'scoreboard', // an app template, asked for a widget
      );
      expect(wrongKind.outcome.artifact, isA<WidgetArtifact>());
    });

    test('widget', () async {
      final result = await run(
        responses: [_widgetReply],
        kind: CreationKind.widget,
        prompt: 'a streak counter',
      );
      expect(result.outcome.artifact, isA<WidgetArtifact>());
      expect(result.outcome.template?.id, 'stat');
    });

    test('out-of-range and hostile values are repaired, not rejected',
        () async {
      final result = await run(
        responses: [
          '{"title":"  {count} Steps  ","unit":"a very long unit name '
              'that goes on","goal":99999,"emoji":"no emoji","accent":"plaid"}',
        ],
        kind: CreationKind.app,
        prompt: 'count steps',
      );
      final slots = result.outcome.template!.slots;
      expect(slots['goal'], 500);
      expect(slots['accent'], 'mint');
      expect(slots['emoji'], '✨');
      expect('${slots['title']}', isNot(contains('{')));
      expect('${slots['unit']}'.length, lessThanOrEqualTo(20));
    });

    test('reports designing, writing and validating in order', () async {
      final result = await run(
        responses: [_counterReply],
        kind: CreationKind.app,
      );
      expect(result.stages, [
        CreationStage.designing,
        CreationStage.writing,
        CreationStage.validating,
      ]);
    });
  });

  group('when the reply is unusable', () {
    test('it asks once more, then builds the template from the brief',
        () async {
      final result = await run(
        responses: ['sorry, I cannot do that', '{"nothing":"useful"}'],
        kind: CreationKind.app,
        prompt: 'a packing checklist for a trip',
      );
      expect(result.model.requests, hasLength(2));
      expect(result.model.requests.last, contains('could not be used'));
      expect(result.outcome.usedFallback, isTrue);
      // Not a generic counter: the template the brief asked for, titled by it.
      expect(result.outcome.template?.id, 'checklist');
      expect(result.outcome.title, 'A packing checklist for a trip');
      expect(result.outcome.artifact, isA<MiniAppArtifact>());
    });

    test('honours maxRepairRounds of zero', () async {
      final result = await run(
        responses: ['not json'],
        kind: CreationKind.app,
        maxRepairRounds: 0,
      );
      expect(result.model.requests, hasLength(1));
      expect(result.outcome.usedFallback, isTrue);
    });

    test('a second reply can rescue the first', () async {
      final result = await run(
        responses: ['not json', _counterReply],
        kind: CreationKind.app,
        prompt: 'count glasses of water',
      );
      expect(result.outcome.usedFallback, isFalse);
      expect(result.outcome.title, 'Water tracker');
    });
  });

  group('presentations stay free-form', () {
    test('a valid deck is used as-is, with its theme', () async {
      final result = await run(
        responses: [_validDeck],
        kind: CreationKind.presentation,
      );
      expect(result.outcome.usedFallback, isFalse);
      final deck = (result.outcome.artifact as PresentationArtifact).spec;
      expect(deck.theme.name, 'midnight');
      expect(deck.slides.first.layoutAt(0).name, 'title');
      expect(result.outcome.template, isNull);
    });

    test('an invalid deck is repaired once, then falls back', () async {
      final result = await run(
        responses: ['{"title":"x","slides":[]}', '{"title":"x","slides":[]}'],
        kind: CreationKind.presentation,
      );
      expect(result.model.requests, hasLength(2));
      expect(result.outcome.usedFallback, isTrue);
      expect(result.outcome.artifact, isA<PresentationArtifact>());
    });
  });

  group('json salvage feeds the pipeline', () {
    test('recovers a reply wrapped in a think block and fences', () async {
      final result = await run(
        responses: ['<think>hm</think>```json\n$_counterReply\n```'],
        kind: CreationKind.app,
      );
      expect(result.outcome.usedFallback, isFalse);
      expect(result.outcome.title, 'Water tracker');
    });

    test('ignores a browser tool call emitted before the answer', () async {
      final result = await run(
        responses: [
          '<tool_call>{"name":"browser_search","arguments":{"query":"x"}}'
              '</tool_call>$_counterReply',
        ],
        kind: CreationKind.app,
      );
      expect(result.outcome.usedFallback, isFalse);
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
