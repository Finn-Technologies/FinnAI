import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/creation_generator.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';

/// Drives the pipeline from canned model output, so every branch of
/// parse -> validate -> repair is covered without an engine.
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
      CreationOutcome? outcome,
      List<CreationStage> stages,
      ScriptedCompletion model,
      Object? error,
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
  CreationOutcome? outcome;
  Object? error;
  try {
    outcome = await generator.generate(
      prompt: prompt,
      kind: kind,
      onStage: stages.add,
    );
  } on Object catch (caught) {
    error = caught;
  }
  return (outcome: outcome, stages: stages, model: model, error: error);
}

/// The model designs the whole app itself: its nodes and how they behave.
const _validApp = '{"title":"Water Tracker","accent":"sky","nodes":['
    '{"type":"text","value":"Glasses: {glasses}","style":"title"},'
    '{"type":"text","value":"Goal: 8","style":"caption"},'
    '{"type":"button","label":"Add a glass",'
    '"action":{"kind":"increment","key":"glasses","by":1}},'
    '{"type":"button","label":"Reset","action":{"kind":"reset"}}'
    ']}';

const _validWidget =
    '{"title":"Reading Streak","accent":"mint","kind":"counter",'
    '"rows":[{"label":"Days in a row","value":"12"}],"footer":"Keep going",'
    '"goal":30}';

const _validDeck = '{"title":"Review","summary":"A deck.","theme":"midnight",'
    '"slides":[{"title":"Review","layout":"title","bullets":["One","Two"]},'
    '{"title":"Next","bullets":["Ship it"]}]}';

void main() {
  group('the model writes the whole creation', () {
    test('a mini app arrives as the nodes the model chose', () async {
      final result = await run(
        responses: [_validApp],
        kind: CreationKind.app,
        prompt: 'count how many glasses of water I drink',
      );
      expect(result.error, isNull);
      final app = (result.outcome!.artifact as MiniAppArtifact).spec;
      expect(result.outcome!.title, 'Water Tracker');
      expect(app.accent.name, 'sky');
      expect(app.nodes, hasLength(4));
      expect(app.nodes[0], isA<TextNode>());
      expect((app.nodes[0] as TextNode).value, 'Glasses: {glasses}');
      expect(app.nodes[2], isA<ButtonNode>());
      expect(app.writtenKeys, contains('glasses'));
    });

    test('a widget arrives as the rows and kind the model chose', () async {
      final result = await run(
        responses: [_validWidget],
        kind: CreationKind.widget,
        prompt: 'track my reading streak',
      );
      final widget = (result.outcome!.artifact as WidgetArtifact).spec;
      expect(widget.kind.name, 'counter');
      expect(widget.goal, 30);
      expect(widget.rows.single.label, 'Days in a row');
    });

    test('a deck arrives as the slides and theme the model chose', () async {
      final result = await run(
        responses: [_validDeck],
        kind: CreationKind.presentation,
      );
      final deck = (result.outcome!.artifact as PresentationArtifact).spec;
      expect(deck.theme.name, 'midnight');
      expect(deck.slides, hasLength(2));
    });

    test('the prompt asks for the kind that was requested', () async {
      final app = await run(responses: [_validApp], kind: CreationKind.app);
      expect(app.model.requests.single, contains('mini app'));
      final deck = await run(
        responses: [_validDeck],
        kind: CreationKind.presentation,
      );
      expect(deck.model.requests.single, contains('presentation'));
    });

    test('the brief is the last thing the model reads', () async {
      final result = await run(
        responses: [_validApp],
        kind: CreationKind.app,
        prompt: 'a very specific brief',
      );
      final request = result.model.requests.single;
      expect(
        request.indexOf('Brief: "a very specific brief"'),
        greaterThan(request.lastIndexOf('{')),
      );
    });
  });

  group('when the reply is unusable', () {
    test('a second reply that fails is an error, not a stand-in', () async {
      final result = await run(
        responses: ['not json', 'still not json'],
        kind: CreationKind.app,
      );
      expect(result.model.requests, hasLength(2));
      expect(result.outcome, isNull);
      expect(result.error, isA<CreationUnusable>());
    });

    test('honours maxRepairRounds of zero', () async {
      final result = await run(
        responses: ['not json'],
        kind: CreationKind.app,
        maxRepairRounds: 0,
      );
      expect(result.model.requests, hasLength(1));
      expect(result.error, isA<CreationUnusable>());
    });

    test('the repair round quotes the validator problems back', () async {
      final result = await run(
        responses: [
          '{"title":"Bad","nodes":[{"type":"text","value":"{count}"}]}',
          _validApp,
        ],
        kind: CreationKind.app,
        prompt: 'count steps',
      );
      expect(result.model.requests, hasLength(2));
      final repair = result.model.requests.last;
      expect(repair, contains('rejected for these reasons'));
      // The reason is the validator's own words: every key that is displayed
      // must also be written somewhere.
      expect(repair, contains('count'));
      expect(result.outcome!.title, 'Water Tracker');
    });

    test('a second reply can rescue the first', () async {
      final result = await run(
        responses: ['not json', _validApp],
        kind: CreationKind.app,
      );
      expect(result.outcome!.title, 'Water Tracker');
      expect(result.error, isNull);
    });

    test('reports designing, writing and validating in order', () async {
      final result = await run(responses: [_validApp], kind: CreationKind.app);
      expect(result.stages, [
        CreationStage.designing,
        CreationStage.writing,
        CreationStage.validating,
      ]);
    });

    test('a repair reports the repairing stage', () async {
      final result = await run(
        responses: ['not json', _validApp],
        kind: CreationKind.app,
      );
      expect(result.stages, [
        CreationStage.designing,
        CreationStage.writing,
        CreationStage.repairing,
        CreationStage.writing,
        CreationStage.validating,
      ]);
    });
  });
}
