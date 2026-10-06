part of '../finn_accelerator.dart';

/// The identity of a chat session: the token under which its KV cache may be
/// reused.
///
/// A session is only reusable when the cache is holding exactly what the next
/// turn is about to assume. That includes the per-intent task instruction,
/// which is a `system` block that lives in the KV cache for the whole life of
/// the session. It was left out of this hash, so a conversation that switched
/// intent — a one-word answer, then a summarisation request — reused the
/// session and carried the *first* turn's instruction underneath the second
/// turn's prompt. Two instructions, one of them contradicting the other, and
/// nothing in the cache key said so.
///
/// The instruction's text is hashed rather than embedded, so a long instruction
/// does not make the key large and no prompt text ends up in a logged key.
@visibleForTesting
String sessionConfigurationHash({
  required String stableHash,
  required String systemContext,
  String taskInstruction = '',
  String mode = 'chat',
}) {
  final contextHash =
      sha256.convert(utf8.encode(systemContext.trim())).toString();
  final taskHash =
      sha256.convert(utf8.encode(taskInstruction.trim())).toString();
  return sha256
      .convert(
        utf8.encode('$stableHash|$contextHash|task=$taskHash|mode=$mode'),
      )
      .toString();
}
