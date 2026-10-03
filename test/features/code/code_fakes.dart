import 'dart:async';

import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';

/// Plays back one scripted reply per request. A reply is a string (streamed in
/// small pieces), an exception (thrown by the stream) or a stream.
class FakeGateway implements CodeModelGateway {
  FakeGateway(
    this.replies, {
    this.budget = const CodeBudget(
      observationChars: 700,
      historyChars: 3200,
      maxSteps: 8,
    ),
  });

  final List<Object> replies;
  final List<CodeCompletion> requests = [];
  int cancels = 0;

  @override
  final CodeBudget budget;

  @override
  String get label => 'Fake';

  @override
  bool get isLocal => true;

  @override
  Stream<String> complete(CodeCompletion request) {
    requests.add(request);
    final reply = replies[(requests.length - 1).clamp(0, replies.length - 1)];
    if (reply is Stream<String>) return reply;
    if (reply is Exception) return Stream.error(reply);
    final text = reply as String;
    return Stream.fromIterable([
      for (var i = 0; i < text.length; i += 6)
        text.substring(i, (i + 6).clamp(0, text.length)),
    ]);
  }

  @override
  Future<void> cancel() async => cancels++;
}

class FakeRunner implements CodeActionRunner {
  FakeRunner({this.canRun = true, this.results = const []});

  final bool canRun;
  final List<CodeAction> results;
  final List<CodeAction> ran = [];

  @override
  bool get canRunCommands => canRun;

  @override
  Future<CodeAction> run(String sessionId, CodeAction action) async {
    ran.add(action);
    if (ran.length <= results.length) return results[ran.length - 1];
    return action.copyWith(
      status: CodeActionStatus.done,
      output: action.isShell ? 'ok' : '',
      exitCode: 0,
    );
  }
}
