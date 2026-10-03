import 'dart:async';

import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/providers/code_model.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/providers/provider_client.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/prompt_intent.dart';

/// Answers with the model that lives on the phone. Nothing is sent anywhere.
class LocalCodeGateway implements CodeModelGateway {
  LocalCodeGateway([FinnInference? inference])
      : _inference = inference ?? FinnInference.instance;

  final FinnInference _inference;

  @override
  String get label => 'FinnAI';

  @override
  bool get isLocal => true;

  @override
  CodeBudget get budget => CodeBudget.onDevice;

  @override
  Stream<String> complete(CodeCompletion request) {
    final turns = request.turns;
    final history = [
      for (final turn in turns.take(turns.length - 1))
        LocalChatTurn(role: turn.role, content: turn.content),
    ];
    return _inference.generateReplyQueued(
      turns.last.content,
      // One conversation per session, so the engine keeps the session's
      // prefix warm between the steps of a request.
      conversationId: request.conversationId,
      history: history,
      systemContext: request.system,
      // Code is answered as code: the factual sampler, the coding budget, and
      // the English the protocol is written in.
      promptAnalysis: const PromptAnalysis(
        intent: PromptIntent.coding,
        language: PromptLanguage.english,
      ),
      samplerProfile: PromptIntentPolicy.sampler(PromptIntent.coding),
      maxOutputTokens: request.maxTokens,
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
