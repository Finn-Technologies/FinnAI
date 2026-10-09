import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/providers/code_model.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/providers/provider_client.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/prompt_intent.dart';

/// The engine arguments one [LocalCodeGateway] request maps to. Split out so
/// the wiring (agent prompt, coding sampler, grammar on/off, history) is
/// testable without a loaded model.
typedef LocalEngineArgs = ({
  String prompt,
  List<LocalChatTurn> history,
  String system,
  String conversationId,
  IntentSamplerProfile sampler,
  int maxTokens,
  bool agentPrompt,
});

/// Answers with the model that lives on the phone. Nothing is sent anywhere.
class LocalCodeGateway implements CodeModelGateway {
  LocalCodeGateway([FinnInference? inference])
      : _inference = inference ?? FinnInference.instance;

  final FinnInference _inference;

  /// The sampler for the agentic loop: the coding settings, grammar off until
  /// the on-device A/B (plan Task 11) shows a grammar helps. Phase-B tuning
  /// lands here; both tiers share this until then.
  static const IntentSamplerProfile agenticSampler = IntentSamplerProfile(
    temperature: .30,
    topK: 30,
    topP: .90,
    minP: .05,
    repeatPenalty: 1.05,
    penaltyLastN: 256,
  );

  @override
  String get label => 'FinnAI';

  @override
  bool get isLocal => true;

  @override
  CodeBudget get budget => CodeBudget.onDevice;

  /// The engine arguments [request] maps to. Code is answered as code: the
  /// factual coding sampler and Code's own system prompt verbatim (no chat
  /// persona, date, or private-context wrapper).
  @visibleForTesting
  LocalEngineArgs argsFor(CodeCompletion request) {
    final turns = request.turns;
    return (
      prompt: turns.last.content,
      history: [
        for (final turn in turns.take(turns.length - 1))
          LocalChatTurn(role: turn.role, content: turn.content),
      ],
      system: request.system,
      conversationId: request.conversationId,
      sampler: agenticSampler,
      maxTokens: request.maxTokens,
      agentPrompt: true,
    );
  }

  @override
  Stream<String> complete(CodeCompletion request) async* {
    if (request.start.isNotEmpty) yield request.start;
    final args = argsFor(request);
    yield* _inference.generateReplyQueued(
      args.prompt,
      // One conversation per session, so the engine keeps the session's
      // prefix warm between the steps of a request.
      conversationId: args.conversationId,
      history: args.history,
      systemContext: args.system,
      promptAnalysis: const PromptAnalysis(
        intent: PromptIntent.coding,
        language: PromptLanguage.english,
      ),
      samplerProfile: args.sampler,
      maxOutputTokens: args.maxTokens,
      agentPrompt: args.agentPrompt,
    );
  }

  @override
  Future<void> cancel() => _inference.stopGeneration();
}

/// Answers with a cloud provider, using the user's own key. The conversation,
/// including file contents and command output, is sent to that provider.
class RemoteCodeGateway implements CodeModelGateway {
  RemoteCodeGateway({
    required this.model,
    required this.baseUrl,
    required CodeProviderClient client,
    this.apiKey,
    this.onWire,
  }) : _client = client;

  final CodeModel model;
  final String baseUrl;
  final String? apiKey;
  final CodeProviderClient _client;

  /// Told which request shape worked, so it is remembered for next time.
  final void Function(CodeWire wire)? onWire;

  @override
  String get label => model.provider == CodeProvider.custom
      ? model.name
      : '${model.provider.displayName} · ${model.name}';

  @override
  bool get isLocal => false;

  /// A small-window cloud model gets the on-device budget for history, so the
  /// agent does not overrun it; a large one gets room to read real files.
  @override
  CodeBudget get budget {
    final window = model.contextLength;
    if (window != null && window < 16000) return CodeBudget.onDevice;
    if (window != null && window < 64000) {
      return const CodeBudget(
        observationChars: 3000,
        historyChars: 24000,
        maxSteps: 16,
      );
    }
    return CodeBudget.cloud;
  }

  @override
  Stream<String> complete(CodeCompletion request) => _client.stream(
        model,
        baseUrl: baseUrl,
        completion: request,
        apiKey: apiKey,
        onWire: onWire,
      );

  /// Cancelling the subscription closes the connection; there is nothing
  /// else to stop.
  @override
  Future<void> cancel() async {}
}
