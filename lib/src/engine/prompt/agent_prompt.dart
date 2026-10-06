import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:finn_ai/src/engine/finn_engine_types.dart';

/// The prompt shape for an agent caller (FinnAI Code): the caller's own
/// system prompt and nothing else.
///
/// The chat prompt wraps its system context in the chat persona, marks it as
/// private configuration, trims history by its own rules and puts the date
/// right before the question. An agent protocol fights all of that: the 1.6B
/// model echoed the date as its "summary" and followed the persona's
/// article-writing rules instead of the protocol. An agent caller budgets its
/// own history, so here it is replayed verbatim.
abstract final class AgentPrompt {
  /// The whole prompt for a fresh session. [history] is replayed as given.
  static String render({
    required String system,
    required List<LocalChatTurn> history,
    required String prompt,
    String start = '',
  }) {
    final buffer = StringBuffer()
      ..write('<|im_start|>system\n')
      ..write(system.trim())
      ..write('<|im_end|>\n');
    for (final turn in history) {
      buffer
        ..write('<|im_start|>${turn.role}\n')
        ..write(turn.content)
        ..write('<|im_end|>\n');
    }
    _writeUser(buffer, prompt, start);
    return buffer.toString();
  }

  /// What a session that already holds the conversation is fed: its last
  /// reply is closed and the new message appended.
  static String continuation(String prompt, {String start = ''}) {
    final buffer = StringBuffer()..write('<|im_end|>\n');
    _writeUser(buffer, prompt, start);
    return buffer.toString();
  }

  /// [start] is written as the first words of the reply: the model carries
  /// on from it. An agent uses it when the next step is already known, so a
  /// small model fills in the details instead of choosing the format.
  static void _writeUser(StringBuffer buffer, String prompt, String start) {
    buffer
      ..write('<|im_start|>user\n')
      ..write(prompt)
      ..write('<|im_end|>\n<|im_start|>assistant\n')
      // Same empty reasoning block the chat prompt primes, so the model
      // answers instead of thinking at length.
      ..write('<think>\n\n</think>\n\n')
      ..write(start);
  }

  /// Identifies what a session holds once it has been fed [history] and
  /// [prompt] (everything but the reply itself).
  static String key(List<LocalChatTurn> history, String prompt) =>
      _hash([...history, LocalChatTurn(role: 'user', content: prompt)]);

  /// Whether a session whose content is [heldKey] can be continued for this
  /// call: the new history must be the held turns plus one reply. The reply
  /// is not compared — the caller replays it reformatted — but every turn
  /// before it must match exactly, or the session holds something else.
  static bool continues(String? heldKey, List<LocalChatTurn> history) {
    if (heldKey == null || history.isEmpty) return false;
    if (history.last.role != 'assistant') return false;
    return _hash(history.sublist(0, history.length - 1)) == heldKey;
  }

  static String _hash(List<LocalChatTurn> turns) => sha256
      .convert(utf8.encode([
        for (final turn in turns) '${turn.role}\u0000${turn.content}',
      ].join('\u0001')))
      .toString();
}
