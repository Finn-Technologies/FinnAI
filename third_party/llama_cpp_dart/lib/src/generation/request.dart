import '../sampling/sampler_params.dart';
import 'context_shift.dart';

/// A single generation request. Immutable.
final class Request {
  /// Tokens to prefill before sampling begins.
  final List<int> promptTokens;

  /// Sampling configuration.
  final SamplerParams sampler;

  /// Maximum number of tokens to emit.
  final int maxTokens;

  /// Sequence id within the parent context.
  final int seqId;

  /// First KV position to use for prefill. `0` for fresh sequences;
  /// continuations supply the post-decode position from the previous run.
  final int startPos;

  /// What the generator should do when the KV cache is one slot from full.
  final ContextShiftPolicy shiftPolicy;

  /// Tunables for [ContextShiftPolicy.auto].
  final ContextShift shift;

  /// Verified tokens that precede [promptTokens] in the KV cache (the full
  /// conversation history). Used to seed the n-gram table for lookahead
  /// decoding so drafts are available from the first generated token, not
  /// just after the model has produced enough text. Never decoded by this
  /// request — it is metadata only.
  final List<int> historyTokens;

  /// Lookahead window in tokens. `0` disables speculative decoding.
  ///
  /// When enabled, the generator verifies up to this many n-gram draft
  /// tokens in a single batched forward pass. Requires a context created
  /// with `nRsSeq >= window - 1` (recurrent/hybrid models) so rejected
  /// drafts can be rolled back; for pure-attention models the KV rollback
  /// always works, but the generator still verifies `context.nRsSeq > 0`
  /// before enabling.
  final int lookaheadWindow;

  const Request({
    required this.promptTokens,
    this.sampler = const SamplerParams(),
    this.maxTokens = 256,
    this.seqId = 0,
    this.startPos = 0,
    this.shiftPolicy = ContextShiftPolicy.off,
    this.shift = ContextShift.defaults,
    this.historyTokens = const <int>[],
    this.lookaheadWindow = 0,
  });
}
