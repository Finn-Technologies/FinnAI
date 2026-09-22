import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_prompts.dart';
import 'package:flutter_test/flutter_test.dart';

/// The validator rejects a spec that displays a stored key nothing ever writes.
/// The prompt has to say that plainly and show the shape of the fix, or the
/// model keeps emitting a bare `list` and every repair round fails the same way
/// — which is exactly how an app brief ended in the fallback starter.
void main() {
  test('the app prompt spells out how a displayed key gets written', () {
    final prompt = CreationPrompts.build(
      kind: CreationKind.app,
      brief: 'a habit tracker',
    );

    expect(prompt, contains('Wiring:'));
    expect(
      prompt,
      contains('"append"'),
      reason: 'a list is only ever written by an append action',
    );
    expect(
      prompt,
      contains('do not use that node at all'),
      reason: 'the prompt must tell the model to drop unwired nodes',
    );
  });

  test('every kind still gets a complete worked example', () {
    for (final kind in CreationKind.values) {
      final prompt = CreationPrompts.build(kind: kind, brief: 'a brief');
      expect(prompt, contains('Example'), reason: 'kind $kind');
      expect(prompt, contains('"title"'), reason: 'kind $kind');
    }
  });

  // A small model continues from whatever it read last. When the worked example
  // was the final thing in the prompt, a "habit tracker" brief came back as the
  // example's tap counter — twice, on device. The brief has to close the prompt,
  // and the ban on reusing the example has to be explicit.
  test('the brief closes the prompt, after the worked example', () {
    for (final kind in CreationKind.values) {
      final prompt = CreationPrompts.build(kind: kind, brief: 'a brief');

      expect(
        prompt.indexOf('Brief: "a brief"'),
        greaterThan(prompt.indexOf('Example')),
        reason: 'kind $kind must read the brief after the example',
      );
      expect(
        prompt.indexOf('Brief: "a brief"'),
        greaterThan(prompt.lastIndexOf('{"title"')),
        reason: 'kind $kind must read the brief after the example JSON',
      );
      expect(
        prompt,
        contains('Do not reuse anything from the Example'),
        reason: 'kind $kind must forbid copying the example',
      );
      expect(
        prompt.trimRight().endsWith('nothing else.'),
        isTrue,
        reason: 'kind $kind must end on the JSON-only instruction',
      );
    }
  });

  test('a repair round still quotes the issues before the brief', () {
    final prompt = CreationPrompts.build(
      kind: CreationKind.app,
      brief: 'a habit tracker',
      repairIssues: '"items" is displayed but never changed',
    );

    expect(prompt, contains('"items" is displayed but never changed'));
    expect(
      prompt.indexOf('"items" is displayed but never changed'),
      lessThan(prompt.indexOf('Brief: "a habit tracker"')),
    );
  });
}
