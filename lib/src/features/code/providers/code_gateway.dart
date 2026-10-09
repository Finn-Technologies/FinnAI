import 'package:flutter/foundation.dart';

/// One message in the conversation the model is shown.
@immutable
class CodeTurn {
  const CodeTurn(this.role, this.content);

  const CodeTurn.user(this.content) : role = 'user';
  const CodeTurn.assistant(this.content) : role = 'assistant';

  /// `user` or `assistant`. The system prompt travels separately.
  final String role;
  final String content;

  @override
  bool operator ==(Object other) =>
      other is CodeTurn && other.role == role && other.content == content;

  @override
  int get hashCode => Object.hash(role, content);
}

/// Everything a model needs to produce the next reply.
@immutable
class CodeCompletion {
  const CodeCompletion({
    required this.system,
    required this.turns,
    required this.conversationId,
    this.maxTokens = 768,
    this.start = '',
  });

  final String system;

  /// Oldest first, ending with the message the model must answer.
  final List<CodeTurn> turns;

  /// Stable per session, so the on-device engine can reuse its cached prefix.
  final String conversationId;
  final int maxTokens;

  /// Reserved for a forced reply start. Unused by the harness (it decides no
  /// words for the model); kept so `complete` stays a stable shape.
  final String start;
}

/// Something that can answer a [CodeCompletion]: the on-device model or a
/// cloud provider. The agent loop does not know which.
abstract class CodeModelGateway {
  /// Short name for the reply's byline: `FinnAI`, `OpenRouter · model`.
  String get label;

  /// True when nothing leaves the device.
  bool get isLocal;

  /// How much conversation and command output the model can be shown. The
  /// on-device model has a small window; a cloud model a large one.
  CodeBudget get budget;

  /// Streams the reply as text fragments. Cancelling the subscription stops
  /// the request.
  Stream<String> complete(CodeCompletion request);

  /// Stops the reply in flight, if any. Safe to call when idle.
  Future<void> cancel();
}

/// Size limits that follow from the model's context window.
@immutable
class CodeBudget {
  const CodeBudget({
    required this.observationChars,
    required this.historyChars,
    required this.maxSteps,
    this.examples = false,
  });

  /// The longest command result shown to the model in one message.
  final int observationChars;

  /// How much earlier conversation is replayed.
  final int historyChars;

  /// Default actions per request.
  final int maxSteps;

  /// Show the model a worked example before the conversation. A small model
  /// follows an example far more reliably than a rule; a large one does not
  /// need it and its context is better spent on the project.
  final bool examples;

  /// A 1.6B model with a 2–4k window: short results, short memory.
  static const onDevice = CodeBudget(
    observationChars: 700,
    historyChars: 3200,
    maxSteps: 8,
    examples: true,
  );

  static const cloud = CodeBudget(
    observationChars: 6000,
    historyChars: 60000,
    maxSteps: 20,
  );
}
