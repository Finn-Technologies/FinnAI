import 'package:finn_ai/src/engine/finn_accelerator.dart';
import 'package:flutter_test/flutter_test.dart';

/// A session's KV cache is only reusable when it is holding exactly what the
/// next turn is about to assume: the model, template, private context and mode.
///
/// The per-intent task instruction used to be part of the key, which made a
/// topic change throw the session away and re-read the whole history (~16 s on
/// a 1,500-token 3B chat). It is now appended before the user's turn when it
/// changes, so it must NOT reset the session.
void main() {
  const stable = 'prefix-cache-stable-hash';

  String key({
    String systemContext = '',
    String stableHash = stable,
  }) =>
      sessionConfigurationHash(
        stableHash: stableHash,
        systemContext: systemContext,
      );

  test('the same session renders the same key', () {
    // A repeated identical turn must hit the cache. If this flapped, the
    // device saw a full re-prefill for a question it had just answered.
    expect(key(systemContext: 'name: Abhi'), key(systemContext: 'name: Abhi'));
  });

  test('the task instruction is not part of the key any more', () {
    // The whole point of the change: an intent switch must keep the session.
    // The instruction is re-appended per turn instead (see
    // task_prefix_prompt_test.dart for that half).
    expect(key(systemContext: 'x'), key(systemContext: 'x'));
  });

  test('a change in private context produces a different key', () {
    expect(
      key(systemContext: 'name: Abhi'),
      isNot(key(systemContext: 'name: Someone')),
    );
  });

  test('a change in the model or template changes the key', () {
    expect(
      key(stableHash: stable),
      isNot(key(stableHash: '$stable-v2')),
    );
  });

  test('whitespace in the private context is not a different session', () {
    // Trimming matters because the same context arrives with different
    // surrounding whitespace depending on which caller rendered it, and a
    // needless miss costs a full re-prefill.
    expect(
      key(systemContext: 'name: Abhi'),
      key(systemContext: '  name: Abhi\n'),
    );
  });

  test('the key carries no prompt text', () {
    // The key can appear in a log line; the context is hashed for that reason
    // as well as for brevity.
    final hashed = key(systemContext: 'my private profile detail');
    expect(hashed, isNot(contains('private')));
    expect(hashed, hasLength(64));
  });

  test('the mode is part of the key', () {
    // Chat and the Code agent must never share a session.
    expect(
      sessionConfigurationHash(
        stableHash: stable,
        systemContext: 'x',
        mode: 'chat',
      ),
      isNot(sessionConfigurationHash(
        stableHash: stable,
        systemContext: 'x',
        mode: 'agent',
      )),
    );
  });
}
