import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/agent/agent_protocol.dart';
import 'package:finn_ai/src/features/code/agent/code_mentions.dart';
import 'package:finn_ai/src/features/code/agent/small_model_aids.dart';
import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/providers/provider_errors.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';

/// What the agent is doing right now.
enum CodeAgentPhase {
  idle,

  /// Waiting on the model.
  thinking,

  /// An action is shown and waits for the user's tap.
  awaitingApproval,

  /// A command is running.
  running,
}

/// Builds the gateway for the model the user has selected.
typedef CodeGatewayFactory = Future<CodeModelGateway> Function();

/// Runs a request: sends the conversation to the model, carries out the one
/// action it answers with, shows the result to it, and repeats until the model
/// answers in plain text, the step limit is reached, or the user stops it.
///
/// One request at a time. The loop is bounded three ways, because a small
/// model left alone will loop: a step limit, a stop on the same action three
/// times running, and the user's stop button.
class CodeAgent extends ChangeNotifier {
  CodeAgent({
    required this.sessions,
    required this.settings,
    required this.runner,
    required this.gatewayFactory,
    this.streamUpdateInterval = const Duration(milliseconds: 60),
  });

  final CodeSessionStore sessions;
  final CodeSettingsStore settings;
  final CodeActionRunner runner;
  final CodeGatewayFactory gatewayFactory;

  /// Tokens arrive far faster than a screen can use them; the transcript is
  /// updated at most this often while a reply streams.
  final Duration streamUpdateInterval;

  CodeAgentPhase _phase = CodeAgentPhase.idle;
  String? _sessionId;
  String? _pendingMessageId;
  Completer<bool>? _approval;
  Completer<String?>? _streamDone;
  StreamSubscription<String>? _subscription;
  CodeModelGateway? _gateway;
  int _epoch = 0;
  int _idSequence = 0;

  CodeAgentPhase get phase => _phase;
  bool get busy => _phase != CodeAgentPhase.idle;

  /// The session a request is running in, while one is.
  String? get runningSessionId => _sessionId;

  /// The message whose action waits for a tap.
  String? get pendingMessageId => _pendingMessageId;

  /// Repeating the same action this many times in one request ends it.
  static const int repeatLimit = 3;

  void _setPhase(CodeAgentPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    notifyListeners();
  }

  String _nextId() =>
      'm${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_idSequence++}';

  // ---------------------------------------------------------------- API

  /// Adds [text] to the active session (starting one if there is none) and
  /// runs the request. Completes when the request ends.
  ///
  /// [attachments] are files the user picked: they are copied into the
  /// session's project folder first, and the request names them, so the
  /// agent knows to look. Returns the names of any that could not be added.
  ///
  /// Files named with `@path` are read now and shown to the model with the
  /// request, up to [mentionChars] in all (the on-device model's window is
  /// small; a cloud model's is not).
  Future<List<String>> send(
    String text, {
    List<File> attachments = const [],
    int mentionChars = 1200,
  }) async {
    var trimmed = text.trim();
    if ((trimmed.isEmpty && attachments.isEmpty) || busy) return const [];
    final session = sessions.active ?? sessions.create();
    // Named after what was asked, not after the attachment note.
    if (session.title.isEmpty && trimmed.isNotEmpty) {
      sessions.rename(session.id, CodeSessionStore.titleFrom(trimmed));
    }
    final failed = <String>[];
    if (attachments.isNotEmpty) {
      final workspace = await sessions.workspaceOf(session.id);
      final added = <String>[];
      for (final file in attachments) {
        try {
          added.add(await workspace.importFile(file));
        } catch (_) {
          failed.add(file.uri.pathSegments.last);
        }
      }
      if (added.isNotEmpty) {
        final note = 'Attached: ${added.join(', ')}';
        trimmed = trimmed.isEmpty ? note : '$note\n\n$trimmed';
      }
      if (trimmed.isEmpty) return failed;
    }
    final context = await CodeMentions.read(
      await sessions.workspaceOf(session.id),
      trimmed,
      budget: mentionChars,
    );
    sessions.appendMessage(
      session.id,
      CodeMessage(
        id: _nextId(),
        role: CodeRole.user,
        createdAt: DateTime.now(),
        text: trimmed,
        context: context,
      ),
    );
    await _run(session.id);
    return failed;
  }

  /// Carries on from where the session stopped: after a step limit, an error,
  /// or a stop. Does nothing when the session already ends with an answer.
  Future<void> resume() async {
    final session = sessions.active;
    if (session == null || busy || session.messages.isEmpty) return;
    final last = session.messages.last;
    if (last.isUser) {
      await _run(session.id);
      return;
    }
    // Continue from the last handled action, or retry the failed reply.
    final action = last.action;
    final retryable = last.failed || (action != null && !action.open);
    if (!retryable) return;
    await _run(session.id);
  }

  /// The user's tap on "Run" (or "Allow").
  void approve(String messageId) => _decide(messageId, true);

  /// The user's tap on "Skip".
  void skip(String messageId) => _decide(messageId, false);

  void _decide(String messageId, bool allowed) {
    if (_pendingMessageId != messageId) return;
    final approval = _approval;
    if (approval != null && !approval.isCompleted) approval.complete(allowed);
  }

  /// Stops the request now: the reply being written, a command waiting for a
  /// tap, or the next step.
  Future<void> stop() async {
    if (!busy) return;
    _epoch++;
    // Taken first: ending the stream lets the loop finish, and its cleanup
    // clears these fields before this method gets to use them.
    final gateway = _gateway;
    final subscription = _subscription;
    final approval = _approval;
    if (approval != null && !approval.isCompleted) approval.complete(false);
    // A reply being streamed ends here: its subscription is cancelled, so
    // nothing else would ever complete the wait on it.
    final stream = _streamDone;
    if (stream != null && !stream.isCompleted) stream.complete(null);
    await subscription?.cancel();
    try {
      await gateway?.cancel().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Stopping is best effort; the loop has already been told to end.
    }
  }

  // --------------------------------------------------------------- loop

  Future<void> _run(String sessionId) async {
    final epoch = _epoch;
    _sessionId = sessionId;
    _setPhase(CodeAgentPhase.thinking);
    try {
      final gateway = _gateway = await gatewayFactory();
      final limit = settings.settings.maxSteps ?? gateway.budget.maxSteps;
      final recent = <String>[];
      CodeAction? lastResult;
      var cutOffs = 0;
      var acted = false;

      for (var step = 0; step < limit; step++) {
        if (epoch != _epoch) return;
        final session = sessions.byId(sessionId);
        if (session == null) return;

        final messageId = _nextId();
        sessions.appendMessage(
          sessionId,
          CodeMessage(
            id: messageId,
            role: CodeRole.assistant,
            createdAt: DateTime.now(),
            modelLabel: gateway.label,
          ),
        );
        _setPhase(CodeAgentPhase.thinking);

        final raw = await _stream(gateway, sessionId, messageId, epoch);
        if (epoch != _epoch) {
          _abandon(sessionId, messageId);
          return;
        }
        if (raw == null) return; // _stream recorded the error.

        var parsed = AgentProtocol.parse(raw);
        if (gateway.budget.examples) {
          final messages =
              sessions.byId(sessionId)?.messages ?? const <CodeMessage>[];
          final request = messages.reversed
                  .where((message) => message.isUser)
                  .firstOrNull
                  ?.text ??
              '';
          parsed = SmallModelAids.repair(parsed, request: request);
        }
        // A reply whose action cannot be used (cut off, or a file block with
        // no name) is not an answer: the model is told what was wrong and
        // tries again. Twice in a row ends the request.
        if (parsed.cutOff || parsed.malformed) {
          cutOffs++;
          _finishMessage(
            sessionId,
            messageId,
            text: parsed.prose,
            errorCode:
                parsed.cutOff ? CodeErrorCode.cutOff : CodeErrorCode.malformed,
          );
          if (cutOffs >= 2) return;
          continue;
        }
        cutOffs = 0;

        final action = parsed.action;
        if (action == null && parsed.prose.isEmpty && acted) {
          // The work was done and the model had nothing to add. The action
          // cards say what happened; an "empty reply" error would not be fair.
          sessions.removeMessage(sessionId, messageId);
          return;
        }
        if (action == null) {
          _finishMessage(
            sessionId,
            messageId,
            text: parsed.prose,
            errorCode: parsed.prose.isEmpty ? CodeErrorCode.empty : null,
          );
          return;
        }

        recent.add(action.signature);
        // The same action a third time in one request is a loop, whether it
        // comes back to back or alternates with another (chmod, sudo chmod,
        // chmod…, seen on the device).
        final repeating =
            recent.where((signature) => signature == action.signature).length >=
                repeatLimit;

        _finishMessage(sessionId, messageId,
            text: parsed.prose, action: action);
        final handled = await _handle(sessionId, messageId, action, epoch);
        if (epoch != _epoch || handled == null) return;
        acted = true;
        // The model ran what it just ran, and it worked the same way again:
        // the work is done and it is only failing to say so. End quietly,
        // rather than run it a third time and report a loop.
        if (_sameSuccessAsBefore(handled, lastResult)) return;
        lastResult = handled;
        if (repeating) {
          _appendError(sessionId, CodeErrorCode.repeating);
          return;
        }
      }
      _appendError(sessionId, CodeErrorCode.stepLimit);
    } catch (error) {
      _appendError(sessionId, _codeFor(error), detail: _detailFor(error));
    } finally {
      // Only one request runs at a time, so whichever way this one ended
      // (finished, failed, stopped) the agent is free again.
      _sessionId = null;
      _pendingMessageId = null;
      _approval = null;
      _streamDone = null;
      _subscription = null;
      _gateway = null;
      _setPhase(CodeAgentPhase.idle);
      unawaited(sessions.flush());
    }
  }

  /// Streams the model's reply into message [messageId]. Returns the full
  /// text, or null if the request failed (the failure is recorded).
  Future<String?> _stream(
    CodeModelGateway gateway,
    String sessionId,
    String messageId,
    int epoch,
  ) async {
    final session = sessions.byId(sessionId)!;
    final small = gateway.budget.examples;
    final turns = AgentProtocol.turnsFor(
      [
        for (final message in session.messages)
          if (message.id != messageId) message,
      ],
      budget: gateway.budget,
      remind: small,
      shell: runner.canRunCommands,
    );
    // The model answers the last message, which must be the user's.
    if (turns.isEmpty || turns.last.role != 'user') {
      turns.add(const CodeTurn.user('Continue.'));
    }
    if (small) {
      // A small model gets a worked example first: see
      // [AgentProtocol.exampleTurns].
      turns.insertAll(
        0,
        AgentProtocol.exampleTurns(shell: runner.canRunCommands),
      );
    }
    final completion = CodeCompletion(
      system: AgentProtocol.systemPrompt(
        shell: runner.canRunCommands,
        container: runner.environment == CommandEnvironment.container,
        edits: !small,
      ),
      turns: turns,
      conversationId: 'code-$sessionId',
      maxTokens: gateway.isLocal ? 1024 : 4096,
      start: small
          ? SmallModelAids.forcedStart(
                [
                  for (final message in session.messages)
                    if (message.id != messageId) message,
                ],
                shell: runner.canRunCommands,
              ) ??
              ''
          : '',
    );

    final buffer = StringBuffer();
    final done = _streamDone = Completer<String?>();
    Timer? pending;

    void show() {
      pending = null;
      final message = _message(sessionId, messageId);
      if (message != null) {
        sessions.replaceMessage(
          sessionId,
          message.copyWith(text: AgentProtocol.clean(buffer.toString())),
        );
      }
    }

    void finish(String? value) {
      pending?.cancel();
      pending = null;
      if (!done.isCompleted) done.complete(value);
    }

    final stream = gateway.complete(completion);
    _subscription = stream.listen(
      (fragment) {
        if (epoch != _epoch) return;
        buffer.write(fragment);
        pending ??= Timer(streamUpdateInterval, show);
        // Stop reading once the action is complete: whatever follows is the
        // model inventing the result.
        // Likewise when the model has written a lot and none of it is for the
        // user (reasoning tags over and over): waiting out the whole budget
        // would only make the person wait.
        if (buffer.length > 48 &&
            AgentProtocol.clean(buffer.toString()).trim().isEmpty) {
          unawaited(_subscription?.cancel());
          unawaited(gateway
              .cancel()
              .timeout(const Duration(seconds: 3), onTimeout: () {})
              .catchError((Object _) {}));
          finish(buffer.toString());
          return;
        }
        if (fragment.contains('`') &&
            AgentProtocol.hasCompleteAction(buffer.toString())) {
          unawaited(_subscription?.cancel());
          unawaited(gateway
              .cancel()
              .timeout(const Duration(seconds: 3), onTimeout: () {})
              .catchError((Object _) {}));
          finish(buffer.toString());
        }
      },
      onError: (Object error) {
        if (epoch != _epoch) {
          finish(null);
          return;
        }
        pending?.cancel();
        final message = _message(sessionId, messageId);
        if (message != null) {
          sessions.replaceMessage(
            sessionId,
            message.copyWith(
              text: AgentProtocol.clean(buffer.toString()),
              errorCode: _codeFor(error),
              errorDetail: _detailFor(error),
            ),
          );
        }
        finish(null);
      },
      onDone: () => finish(buffer.toString()),
      cancelOnError: true,
    );
    final raw = await done.future;
    _subscription = null;
    return raw;
  }

  /// Decides whether [action] needs a tap, waits for it, runs it, and records
  /// what happened. Returns the finished action, or null if the request was
  /// stopped while waiting.
  Future<CodeAction?> _handle(
    String sessionId,
    String messageId,
    CodeAction action,
    int epoch,
  ) async {
    if (_needsApproval(action)) {
      _pendingMessageId = messageId;
      _approval = Completer<bool>();
      _setPhase(CodeAgentPhase.awaitingApproval);
      final allowed = await _approval!.future;
      _pendingMessageId = null;
      _approval = null;
      if (epoch != _epoch) {
        _setAction(sessionId, messageId,
            action.copyWith(status: CodeActionStatus.skipped));
        return null;
      }
      if (!allowed) {
        final skipped = action.copyWith(status: CodeActionStatus.skipped);
        _setAction(sessionId, messageId, skipped);
        return skipped;
      }
    }
    _setPhase(CodeAgentPhase.running);
    _setAction(sessionId, messageId,
        action.copyWith(status: CodeActionStatus.running));
    final finished = await runner.run(sessionId, action);
    if (epoch != _epoch) {
      _setAction(sessionId, messageId, finished);
      return null;
    }
    _setAction(sessionId, messageId, finished);
    return finished;
  }

  static bool _sameSuccessAsBefore(CodeAction now, CodeAction? before) =>
      before != null &&
      now.isShell &&
      now.status == CodeActionStatus.done &&
      before.status == CodeActionStatus.done &&
      now.signature == before.signature &&
      now.output == before.output;

  bool _needsApproval(CodeAction action) {
    switch (settings.settings.permissionMode) {
      case CodePermissionMode.askEveryTime:
        return true;
      case CodePermissionMode.acceptEdits:
        return action.isShell;
      case CodePermissionMode.autoRun:
        return false;
    }
  }

  // ------------------------------------------------------------ helpers

  CodeMessage? _message(String sessionId, String messageId) {
    final session = sessions.byId(sessionId);
    if (session == null) return null;
    for (final message in session.messages) {
      if (message.id == messageId) return message;
    }
    return null;
  }

  void _finishMessage(
    String sessionId,
    String messageId, {
    required String text,
    CodeAction? action,
    String? errorCode,
  }) {
    final message = _message(sessionId, messageId);
    if (message == null) return;
    sessions.replaceMessage(
      sessionId,
      CodeMessage(
        id: message.id,
        role: message.role,
        createdAt: message.createdAt,
        modelLabel: message.modelLabel,
        text: text,
        action: action,
        errorCode: errorCode,
      ),
    );
  }

  void _setAction(String sessionId, String messageId, CodeAction action) {
    final message = _message(sessionId, messageId);
    if (message == null) return;
    sessions.replaceMessage(sessionId, message.copyWith(action: action));
  }

  /// A reply stopped before it said anything is removed; one that said
  /// something keeps what it said.
  void _abandon(String sessionId, String messageId) {
    final message = _message(sessionId, messageId);
    if (message != null &&
        message.text.trim().isEmpty &&
        message.action == null) {
      sessions.removeMessage(sessionId, messageId);
    }
  }

  void _appendError(String sessionId, String code, {String detail = ''}) {
    if (sessions.byId(sessionId) == null) return;
    sessions.appendMessage(
      sessionId,
      CodeMessage(
        id: _nextId(),
        role: CodeRole.assistant,
        createdAt: DateTime.now(),
        errorCode: code,
        errorDetail: detail,
      ),
    );
  }

  static String _codeFor(Object error) => error is ProviderException
      ? '${CodeErrorCode.providerPrefix}${error.failure.name}'
      : CodeErrorCode.engine;

  static String _detailFor(Object error) {
    if (error is ProviderException) return error.detail;
    final text = '$error'.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 200 ? text : '${text.substring(0, 200)}…';
  }
}
