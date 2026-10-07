part of '../finn_accelerator.dart';

/// The identity of a chat session: the token under which its KV cache may be
/// reused.
///
/// A session is only reusable when the cache holds what the next turn assumes:
/// the same model, template, private context and mode. The per-intent task
/// instruction is deliberately *not* part of this key any more.
///
/// It used to be. That made a topic change — a one-word answer, then a poem —
/// throw the session away and re-read the whole history: on the 3B phone a
/// 1,500-token chat is ~16 s of prompt reading, and switching intent is the
/// most common way a real chat triggers it. Instead the instruction is
/// appended immediately before the user's turn whenever it differs from the
/// one the cache was primed with (`_ConversationSession.lastTaskInstruction`,
/// `turn.dart`), so the newest instruction is the one next to the question.
/// The cost is that the first turn's instruction stays resident underneath a
/// later, different one; the multi-turn topic-switch eval case measures
/// whether the model mixes them.
///
/// The private context stays in the key: it is prefilled into the cached
/// prefix and cannot be re-stated cheaply on every turn. It is hashed rather
/// than embedded, so no prompt text ends up in a key that may be logged.
@visibleForTesting
String sessionConfigurationHash({
  required String stableHash,
  required String systemContext,
  String mode = 'chat',
}) {
  final contextHash =
      sha256.convert(utf8.encode(systemContext.trim())).toString();
  return sha256
      .convert(
        utf8.encode('$stableHash|$contextHash|mode=$mode'),
      )
      .toString();
}
