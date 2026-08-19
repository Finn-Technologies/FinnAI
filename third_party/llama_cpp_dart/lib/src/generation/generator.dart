import 'dart:ffi';

import '../batch/batch.dart';
import '../context/context.dart';
import '../ffi/library_loader.dart';
import '../sampling/sampler.dart';
import '../sampling/sampler_factory.dart';
import '../sampling/sampler_params.dart';
import '../tokenizer/tokenizer.dart';
import '../tokenizer/utf8_accumulator.dart';
import '../types/exceptions.dart';
import 'context_shift.dart';
import 'event.dart';
import 'lookahead.dart';
import 'request.dart';
import 'stop.dart';

/// Drives the prefill + decode loop for one [Request].
///
/// One generator can be reused for multiple sequential requests on the same
/// context. Internally allocates a batch sized to `context.nBatch`.
final class Generator implements Finalizable {
  final LlamaContext context;
  final Tokenizer tokenizer;
  final LlamaBatch _batch;
  final bool _ownsBatch;
  bool _disposed = false;

  Generator(this.context, this.tokenizer, {LlamaBatch? batch})
      : _batch = batch ?? LlamaBatch(context.nBatch),
        _ownsBatch = batch == null;

  /// Run [request], yielding [TokenEvent]s as tokens are sampled and a final
  /// [DoneEvent] describing why the stream ended. May also yield
  /// [ShiftEvent]s when [Request.shiftPolicy] is `auto`.
  Stream<GenerationEvent> run(Request request) async* {
    _ensureAlive();
    if (request.promptTokens.isEmpty) {
      throw ArgumentError.value(
        request.promptTokens,
        'promptTokens',
        'Request.promptTokens must be non-empty',
      );
    }
    if (request.shiftPolicy == ContextShiftPolicy.auto && !context.canShift) {
      throw const LlamaContextException(
        'shiftPolicy=auto requested but the context cannot be shifted '
        '(recurrent / iSWA / hybrid cache). Use shiftPolicy.off and handle '
        'context overflow at the application level, or load a model whose '
        'memory backend reports llama_memory_can_shift = true.',
      );
    }

    final lib = LlamaLibrary.bindings;
    final vocab = context.model.vocab;
    final accumulator = Utf8Accumulator();

    final sampler = SamplerFactory.build(request.sampler, model: context.model);
    // Lookahead (self-speculative) decoding verifies n-gram draft tokens in
    // a single batched forward pass. It requires recurrent-state snapshots
    // (`nRsSeq > 0`) on hybrid/recurrent models so rejected drafts can be
    // rolled back; on pure-attention models the KV rollback always works but
    // we still gate on nRsSeq to stay conservative.
    final useLookahead = request.lookaheadWindow > 0 && context.nRsSeq > 0;
    // Greedy (filtered-argmax) twin of the request's sampler chain: same
    // logit-bias / penalties / top-k / top-p / min-p stages, but argmax
    // instead of temperature+dist. Drafts are verified against its picks,
    // which are exactly what a deterministic run of the same chain would
    // emit — so accepted drafts are real, penalty-aware model continuations
    // (a temperature draw would rarely match an n-gram guess and kept
    // lookahead from ever firing).
    final greedySampler = useLookahead
        ? SamplerFactory.build(
            request.sampler.copyWith(
              temperature: 0.0,
              dynamicTemp: DynamicTempConfig.disabled,
              mirostat: MirostatConfig.disabled,
              adaptiveP: AdaptivePConfig.disabled,
            ),
            model: context.model,
          )
        : null;
    final ngram = useLookahead ? NGramTable() : null;
    // Verified stream (never mutated by speculative drafts): prompt + the
    // caller-supplied conversation history that precedes it.
    final history = <int>[
      ...request.historyTokens,
      ...request.promptTokens,
    ];
    if (ngram != null) ngram.seed(history);

    // Lookahead stats for the perf-trace build (never compiled into prod).
    var laFired = 0;
    var laAccepted = 0;
    var laBatches = 0;

    try {
      var pos = await _prefill(request, sampler, greedySampler);
      var generated = 0;
      // Batch-logits index whose prediction targets `pos`. -1 means "last
      // submitted position" (the normal case after a single-token decode).
      var logitsIdx = -1;

      while (true) {
        final t0 = sampler.sample(context, idx: logitsIdx);
        final g0 = greedySampler?.sample(context, idx: logitsIdx) ?? t0;
        final drafts = useLookahead
            ? ngram!.draft(history, request.lookaheadWindow)
            : const <int>[];

        if (drafts.isNotEmpty && g0 == drafts[0]) {
          // The model's (filtered) argmax matches the first draft: decode
          // the whole draft window in one batch and verify the rest.
          var wCap = drafts.length;
          final remain = request.maxTokens - generated;
          if (wCap > remain) wCap = remain;
          final space = context.nCtx - pos;
          if (wCap > space) wCap = space;

          if (wCap >= 2) {
            _batch.clear();
            for (var i = 0; i < wCap; i++) {
              _batch.add(drafts[i], pos + i, [request.seqId], wantLogits: true);
            }
            final decodeWatch = Stopwatch()..start();
            final rc = lib.llama_decode(context.pointer, _batch.raw);
            decodeWatch.stop();
            if (const bool.fromEnvironment('FINN_PERF_TRACE')) {
              // ignore: avoid_print
              print(
                'FINN_LOOKAHEAD_BATCH window=$wCap decode_ms=${decodeWatch.elapsedMilliseconds}',
              );
            }
            if (rc != 0) {
              throw LlamaDecodeException(
                rc,
                'lookahead decode failed at gen $generated',
              );
            }

            // Verify drafts[1..] against the greedy twin's picks at each
            // batch position. Both sampler chains accept verified tokens in
            // lockstep so their penalty state matches a sequential run.
            var nAccept = 1; // drafts[0] == g0 already verified pre-batch.
            sampler.accept(drafts[0]);
            greedySampler!.accept(drafts[0]);
            try {
              for (var i = 1; i < wCap; i++) {
                final gi = greedySampler.sample(context, idx: i - 1);
                if (gi != drafts[i]) break;
                sampler.accept(gi);
                greedySampler.accept(gi);
                nAccept++;
              }
            } catch (_) {
              // A sampler failure mid-verification just truncates the
              // accepted prefix; the loop below rolls back the rest.
            }
            laFired++;
            laBatches++;
            laAccepted += nAccept;

            // Emit the accepted prefix. Stops (EOG / maxTokens) may land
            // mid-prefix; the unemitted tail is then rolled back so the KV
            // and recurrent state stay consistent for the next request.
            var emitted = 0;
            DoneEvent? stop;
            for (var i = 0; i < nAccept; i++) {
              final tok = drafts[i];
              // Note: sampler.accept/greedySampler.accept already ran for the
              // whole accepted prefix during verification (lockstep, so the
              // penalty state matches a sequential run).
              history.add(tok);
              final bytes = tokenizer.encodeToken(tok);
              final isEog = vocab.isEog(tok);
              if (isEog) {
                accumulator.clear();
                yield TokenEvent(
                  id: tok,
                  bytes: bytes,
                  text: '',
                  position: pos + emitted,
                );
                stop = DoneEvent(
                  reason: const StopEog(),
                  generatedCount: generated + emitted + 1,
                  committedPosition: pos + emitted + 1,
                );
                emitted++;
                break;
              }
              final text = accumulator.accept(bytes);
              yield TokenEvent(
                id: tok,
                bytes: bytes,
                text: text,
                position: pos + emitted,
              );
              emitted++;
              generated++;
              if (generated >= request.maxTokens) {
                stop = DoneEvent(
                  reason: const StopMaxTokens(),
                  generatedCount: generated,
                  committedPosition: pos + emitted,
                  trailingText: accumulator.flush(),
                );
                break;
              }
            }

            pos += emitted;
            if (emitted < wCap) {
              // Roll back the recurrent state and KV for rejected drafts.
              final mem = lib.llama_get_memory(context.pointer);
              lib.llama_memory_seq_rm(
                mem,
                request.seqId,
                pos,
                pos + (wCap - emitted),
              );
            }
            if (stop != null) {
              yield stop;
              return;
            }
            // The logits at batch index (emitted - 1) predict the token at
            // the new `pos`; remember that for the next sample.
            logitsIdx = emitted - 1;
            continue;
          }
        }

        // --- normal single-token step (t0 was already sampled) ---
        final token = t0;
        sampler.accept(token);
        greedySampler?.accept(token);
        history.add(token);

        final bytes = tokenizer.encodeToken(token);
        final isEog = vocab.isEog(token);

        if (isEog) {
          // Drop any pending UTF-8 fragments and suppress the EOG marker
          // from streaming text. Consumers can still inspect `bytes` or
          // re-decode `id` via the tokenizer if they need the marker.
          accumulator.clear();
          yield TokenEvent(
            id: token,
            bytes: bytes,
            text: '',
            position: pos,
          );
          yield DoneEvent(
            reason: const StopEog(),
            generatedCount: generated + 1,
            committedPosition: pos,
          );
          return;
        }

        final text = accumulator.accept(bytes);

        yield TokenEvent(
          id: token,
          bytes: bytes,
          text: text,
          position: pos,
        );
        generated++;

        if (generated >= request.maxTokens) {
          yield DoneEvent(
            reason: const StopMaxTokens(),
            generatedCount: generated,
            committedPosition: pos,
            trailingText: accumulator.flush(),
          );
          return;
        }

        // Make room in the KV cache before the next decode if needed.
        if (pos + 1 >= context.nCtx) {
          if (request.shiftPolicy != ContextShiftPolicy.auto) {
            throw LlamaDecodeException(
              0,
              'context full at pos=$pos / nCtx=${context.nCtx}; '
              'set Request.shiftPolicy = ContextShiftPolicy.auto to shift '
              'or stop earlier',
            );
          }
          final shifted = _applyShift(request, pos);
          pos -= shifted.nDiscard;
          yield ShiftEvent(
            nKeep: shifted.nKeep,
            nDiscard: shifted.nDiscard,
            newPosition: pos,
          );
        }

        // Commit token: feed back and decode so the next sample sees its logits.
        _batch.clear();
        _batch.add(token, pos, [request.seqId], wantLogits: true);
        final decodeWatch = Stopwatch()..start();
        final rc = lib.llama_decode(context.pointer, _batch.raw);
        decodeWatch.stop();
        // FinnAI dev aid: per-decode attribution, active only when the
        // harness build opts in (FINN_PERF_TRACE). Production never pays the
        // per-token string/IO cost or log spam.
        if (const bool.fromEnvironment('FINN_PERF_TRACE')) {
          // ignore: avoid_print
          print(
            'FINN_DECODE_ALL gen=$generated decode_ms=${decodeWatch.elapsedMilliseconds}',
          );
        }
        if (rc != 0) {
          throw LlamaDecodeException(rc, 'decode failed at gen $generated');
        }
        pos++;
        logitsIdx = -1;
      }
    } finally {
      if (const bool.fromEnvironment('FINN_PERF_TRACE')) {
        // ignore: avoid_print
        print(
          'FINN_LOOKAHEAD_STATS fired=$laFired batches=$laBatches '
          'accepted=$laAccepted',
        );
      }
      greedySampler?.dispose();
      sampler.dispose();
    }
  }

  ({int nKeep, int nDiscard}) _applyShift(Request request, int pos) {
    final lib = LlamaLibrary.bindings;
    var nKeep = request.shift.nKeep < 0
        ? request.startPos + request.promptTokens.length
        : request.shift.nKeep;
    if (request.shift.keepBos) nKeep += 1;
    final keepCap = context.nCtx - 4;
    if (nKeep > keepCap) nKeep = keepCap < 0 ? 0 : keepCap;
    if (nKeep < 0) nKeep = 0;

    final nLeft = pos - nKeep;
    if (nLeft <= 0) {
      throw LlamaDecodeException(
        0,
        'cannot shift: n_left=$nLeft (n_past=$pos, n_keep=$nKeep)',
      );
    }
    final nDiscard = request.shift.nDiscard ?? (nLeft ~/ 2);
    if (nDiscard <= 0 || nDiscard > nLeft) {
      throw LlamaDecodeException(
        0,
        'invalid n_discard=$nDiscard (n_left=$nLeft)',
      );
    }

    final mem = lib.llama_get_memory(context.pointer);
    lib.llama_memory_seq_rm(
      mem,
      request.seqId,
      nKeep,
      nKeep + nDiscard,
    );
    lib.llama_memory_seq_add(
      mem,
      request.seqId,
      nKeep + nDiscard,
      pos,
      -nDiscard,
    );
    return (nKeep: nKeep, nDiscard: nDiscard);
  }

  /// Returns the position of the last decoded prefill token + 1, i.e., the
  /// next free KV slot. Logits are produced only at the last submitted token.
  Future<int> _prefill(
    Request request,
    Sampler sampler,
    Sampler? greedySampler,
  ) async {
    final lib = LlamaLibrary.bindings;
    final prompt = request.promptTokens;
    final cap = _batch.capacity;
    var pos = request.startPos;

    for (var i = 0; i < prompt.length;) {
      final end = (i + cap) > prompt.length ? prompt.length : i + cap;
      final isFinalChunk = end == prompt.length;

      _batch.clear();
      for (var j = i; j < end; j++) {
        final isLast = isFinalChunk && j == end - 1;
        _batch.add(prompt[j], pos++, [request.seqId], wantLogits: isLast);
        // Inform stateful samplers (penalties etc) of the prompt context.
        sampler.accept(prompt[j]);
        greedySampler?.accept(prompt[j]);
      }
      final prefillWatch = Stopwatch()..start();
      final rc = lib.llama_decode(context.pointer, _batch.raw);
      prefillWatch.stop();
      if (const bool.fromEnvironment('FINN_PERF_TRACE')) {
        // ignore: avoid_print
        print(
          'FINN_PREFILL_CHUNK tokens=${end - i} decode_ms=${prefillWatch.elapsedMilliseconds}',
        );
      }
      if (rc != 0) {
        throw LlamaDecodeException(
          rc,
          'prefill decode failed (chunk $i..${end - 1})',
        );
      }
      i = end;
    }
    return pos;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_ownsBatch) _batch.dispose();
  }

  void _ensureAlive() {
    if (_disposed) {
      throw StateError('Generator has been disposed.');
    }
  }
}
