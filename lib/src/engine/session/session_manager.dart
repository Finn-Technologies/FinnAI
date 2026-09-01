import 'dart:async';
import '../backends/llama_shim.dart';
import '../finn_engine_types.dart';
import '../policy/residency_policy.dart';

/// Conversation session tracking and KV slot allocation.
class ConversationSession {
  ConversationSession({
    required this.session,
    required this.sequenceId,
    required this.conversationId,
    required this.promptConfigurationHash,
    required this.messageCount,
    required this.lastUsed,
    required this.basePrefixReady,
  });

  final EngineSession session;
  final int sequenceId;
  final String conversationId;
  String promptConfigurationHash;
  int messageCount;
  bool primed = false;
  final bool basePrefixReady;
  String? lastTaskInstruction;
  int lastUsed;
}

/// Active model runtime instance inside the engine worker isolate.
class ModelRuntime {
  ModelRuntime(
    this.model,
    this.engine, {
    required this.compactKv,
    required this.contextSize,
    required this.modelSha256,
    this.kvType = KvCacheType.iq4_nl,
  });

  final QwenModel model;
  final LlamaEngine engine;
  final bool compactKv;
  final int contextSize;
  final String modelSha256;
  final KvCacheType kvType;
  final Map<String, ConversationSession> sessions = {};
  final SerializedAsyncGate sessionSetupGate = SerializedAsyncGate();
  Future<PrefixStateReport>? prefixWarmup;
  int useSequence = 0;
}
