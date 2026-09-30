import 'package:finn_ai/src/engine/finn_accelerator.dart';
import 'package:flutter_test/flutter_test.dart';

/// A session's KV cache is only reusable when it is holding exactly what the
/// next turn is about to assume. The per-intent task instruction is such a
/// thing — it is a `system` block that stays in the cache for the whole life of
/// the session — and it was not part of the session's identity.
///
/// The visible symptom on the Xiaomi was `session_hit` flapping `false ->
/// true` across identical repeats and false on the *second* turn of a
/// conversation, which the audit read as inconsistent session reuse. The cause
/// was that the key did not describe the session's contents.
void main() {
  const stable = 'prefix-cache-stable-hash';

  String key({
    String systemContext = '',
    String taskInstruction = '',
    String stableHash = stable,
  }) =>
      sessionConfigurationHash(
        stableHash: stableHash,
        systemContext: systemContext,
        taskInstruction: taskInstruction,
      );

  test('the same session renders the same key', () {
    // A repeated identical turn must hit the cache. If this flapped, the
    // device saw a full re-prefill for a question it had just answered.
    expect(
      key(taskInstruction: 'answer in one word'),
      key(taskInstruction: 'answer in one word'),
    );
  });

  test('an intent switch produces a different key', () {
    // The defect. A one-word answer followed by a summarisation request
    // reused the session, so the "answer in one word" instruction was still
    // resident underneath the summarisation prompt.
    expect(
      key(taskInstruction: 'answer in one word'),
      isNot(key(taskInstruction: 'write a thorough summary')),
    );
  });

  test('an absent instruction differs from a present one', () {
    expect(key(), isNot(key(taskInstruction: 'answer in one word')));
  });

  test('a change in private context produces a different key', () {
    expect(
      key(systemContext: 'name: Abhi', taskInstruction: 'x'),
      isNot(key(systemContext: 'name: Someone', taskInstruction: 'x')),
    );
  });

  test('a change in the model or template changes the key', () {
    expect(
      key(stableHash: stable),
      isNot(key(stableHash: '$stable-v2')),
    );
  });

  test('whitespace in the instruction is not a different session', () {
    // Trimming matters because the same instruction arrives with different
    // surrounding whitespace depending on which caller rendered it, and a
    // needless miss costs a full re-prefill.
    expect(
      key(taskInstruction: 'answer in one word'),
      key(taskInstruction: '  answer in one word\n'),
    );
  });

  test('the key carries no prompt text', () {
    // The key can appear in a log line; the instruction is hashed for that
    // reason as well as for brevity.
    final hashed = key(taskInstruction: 'my private profile detail');
    expect(hashed, isNot(contains('private')));
    expect(hashed, hasLength(64));
  });

  test('the task instruction cannot collide with the private context', () {
    // The two are joined with a separator and hashed separately, so moving a
    // string across the boundary must not produce the same key.
    expect(
      key(systemContext: 'a', taskInstruction: 'b'),
      isNot(key(systemContext: 'a|b', taskInstruction: '')),
    );
  });
}
