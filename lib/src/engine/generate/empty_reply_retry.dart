part of '../finn_accelerator.dart';

/// Whether a finished generation should be attempted once more.
///
/// True only for a reply that ended naturally with nothing visible and no
/// retry spent. A cancelled, errored or token-limited turn is never retried,
/// and neither is a turn that already retried: a second empty result is
/// reported as it is rather than looped on.
@visibleForTesting
bool shouldRetryEmptyReply({
  required int retriesLeft,
  required int visibleTokens,
  required String trailingText,
  required GenerationFinishReason finish,
}) =>
    retriesLeft > 0 &&
    visibleTokens == 0 &&
    trailingText.isEmpty &&
    finish == GenerationFinishReason.eos;
