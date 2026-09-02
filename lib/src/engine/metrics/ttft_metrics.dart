import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

enum TtftPhase {
  sendAccepted,
  intentClassified,
  routeSelected,
  modelLoadRequested,
  modelReady,
  sessionReady,
  promptRendered,
  decisionPass,
  generationRequested,
  nativeToken,
  sanitizedToken,
  uiPaintScheduled,
  uiPaintCompleted,
}

/// Monotonic, prompt-free timing record for one user-visible generation.
class TtftTrace {
  TtftTrace({required this.generationId, required this.conversationId}) {
    mark(TtftPhase.sendAccepted);
  }

  final String generationId;
  final String conversationId;
  final Stopwatch _watch = Stopwatch()..start();
  final Map<TtftPhase, int> _micros = {};

  String modelTier = 'unknown';
  bool modelAlreadyResident = false;
  bool basePrefixCacheHit = false;
  bool conversationSessionCacheHit = false;
  int? prefixStateTokens;
  int? prefixStateBytes;
  int? prefixStatePreparationMicros;
  int? prefixStateRestorationMicros;
  double? prefixPromptTokensPerSecond;
  int? promptTokenCount;
  int? availableRamBytes;
  bool lowMemory = false;
  int? threads;
  int? batchThreads;
  int? batchSize;
  int? microBatchSize;
  String kvType = 'unknown';
  String flashAttention = 'unknown';
  bool _reported = false;

  void mark(TtftPhase phase) {
    _micros.putIfAbsent(phase, () => _watch.elapsedMicroseconds);
  }

  bool get hasUiPaintScheduled =>
      _micros.containsKey(TtftPhase.uiPaintScheduled);
  bool get hasUiPaintCompleted =>
      _micros.containsKey(TtftPhase.uiPaintCompleted);

  int? _at(TtftPhase phase) => _micros[phase];
  int? _duration(TtftPhase start, TtftPhase end) {
    final a = _at(start);
    final b = _at(end);
    return a == null || b == null ? null : ((b - a) / 1000).round();
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 1,
        'generation_id': generationId,
        // A stable opaque ID is useful for grouping without prompt contents.
        'conversation_id': conversationId,
        'total_ttft_ms': _duration(
          TtftPhase.sendAccepted,
          hasUiPaintCompleted
              ? TtftPhase.uiPaintCompleted
              : TtftPhase.uiPaintScheduled,
        ),
        'routing_ms':
            _duration(TtftPhase.sendAccepted, TtftPhase.routeSelected),
        'model_load_ms': _duration(
          TtftPhase.modelLoadRequested,
          TtftPhase.modelReady,
        ),
        'session_prepare_ms': _duration(
          TtftPhase.modelReady,
          TtftPhase.sessionReady,
        ),
        'prompt_build_ms': _duration(
          TtftPhase.sessionReady,
          TtftPhase.promptRendered,
        ),
        // llama_cpp_dart currently reports its first event only after
        // tokenisation, prefill, and first sampling. Keep that combined interval
        // honest instead of fabricating sub-phase precision.
        'prompt_eval_ms': _duration(
          TtftPhase.generationRequested,
          TtftPhase.nativeToken,
        ),
        'first_decode_ms': null,
        'sanitization_ms': _duration(
          TtftPhase.nativeToken,
          TtftPhase.sanitizedToken,
        ),
        'ui_delivery_ms': _duration(
          TtftPhase.sanitizedToken,
          hasUiPaintCompleted
              ? TtftPhase.uiPaintCompleted
              : TtftPhase.uiPaintScheduled,
        ),
        'prompt_token_count': promptTokenCount,
        'prompt_token_count_estimated': true,
        'model_tier': modelTier,
        'model_already_resident': modelAlreadyResident,
        'base_prefix_cache_hit': basePrefixCacheHit,
        'prefix_state_tokens': prefixStateTokens,
        'prefix_state_bytes': prefixStateBytes,
        'prefix_state_preparation_ms': prefixStatePreparationMicros == null
            ? null
            : prefixStatePreparationMicros! / 1000,
        'prefix_state_restoration_ms': prefixStateRestorationMicros == null
            ? null
            : prefixStateRestorationMicros! / 1000,
        'prefix_prompt_tokens_per_second': prefixPromptTokensPerSecond,
        'conversation_session_cache_hit': conversationSessionCacheHit,
        'available_ram_bytes': availableRamBytes,
        'low_memory': lowMemory,
        'threads': threads,
        'batch_threads': batchThreads,
        'n_batch': batchSize,
        'n_ubatch': microBatchSize,
        'kv_type': kvType,
        'flash_attention': flashAttention,
      };

  void report({bool force = false}) {
    if (_reported || (!force && !hasUiPaintScheduled)) return;
    _reported = true;
    if (kReleaseMode) return;
    final json = toJson();
    debugPrint('FINN_TTFT ${jsonEncode(json)}');
    debugPrint(
      'FINN_TTFT_SUMMARY total=${json['total_ttft_ms']}ms '
      'route=${json['routing_ms']}ms load=${json['model_load_ms']}ms '
      'session=${json['session_prepare_ms']}ms '
      'prompt_eval=${json['prompt_eval_ms']}ms '
      'ui=${json['ui_delivery_ms']}ms model=$modelTier '
      'resident=$modelAlreadyResident session_hit=$conversationSessionCacheHit',
    );
  }
}

@immutable
class PrefixCacheCompatibilityKey {
  const PrefixCacheCompatibilityKey({
    required this.modelSha256,
    required this.modelTier,
    required this.runtimeVersion,
    required this.architectureIdentity,
    required this.systemPromptVersion,
    required this.chatTemplateVersion,
    required this.contextSize,
    required this.kvTypeK,
    required this.kvTypeV,
    required this.tokenizerSettings,
  });

  final String modelSha256;
  final String modelTier;
  final String runtimeVersion;
  final String architectureIdentity;
  final int systemPromptVersion;
  final int chatTemplateVersion;
  final int contextSize;
  final String kvTypeK;
  final String kvTypeV;
  final String tokenizerSettings;

  String get stableHash => sha256
      .convert(
        utf8.encode(
          [
            modelSha256,
            modelTier,
            runtimeVersion,
            architectureIdentity,
            systemPromptVersion,
            chatTemplateVersion,
            contextSize,
            kvTypeK,
            kvTypeV,
            tokenizerSettings,
          ].join('|'),
        ),
      )
      .toString();

  @override
  bool operator ==(Object other) =>
      other is PrefixCacheCompatibilityKey && stableHash == other.stableHash;

  @override
  int get hashCode => stableHash.hashCode;

  Map<String, Object?> toDiagnosticJson() => <String, Object?>{
        'key_hash': stableHash,
        'model_sha256': modelSha256,
        'model_tier': modelTier,
        'runtime_version': runtimeVersion,
        'architecture_identity': architectureIdentity,
        'system_prompt_version': systemPromptVersion,
        'chat_template_version': chatTemplateVersion,
        'context_size': contextSize,
        'kv_type_k': kvTypeK,
        'kv_type_v': kvTypeV,
        'tokenizer_settings': tokenizerSettings,
      };
}
