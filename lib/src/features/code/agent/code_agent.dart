import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/agent/agent_prompt.dart';
import 'package:finn_ai/src/features/code/agent/agent_tools.dart';
import 'package:finn_ai/src/features/code/agent/code_mentions.dart';
import 'package:finn_ai/src/features/code/agent/code_tool_runner.dart';
import 'package:finn_ai/src/features/code/agent/live_output.dart';
import 'package:finn_ai/src/features/code/agent/session_grants.dart';
import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/providers/provider_errors.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';

/// What the agent is doing right now.
enum CodeAgentPhase {
  idle,
  thinking,
  awaitingApproval,
  running,
}

/// Builds the gateway for the model the user has selected.
typedef CodeGatewayFactory = Future<CodeModelGateway> Function();

/// Runs a request: sends the conversation to the model, carries out the one
/// action it answers with, shows the result to it, and repeats until the model
/// answers with `answer`, the step/repeat limit is hit, or the user stops it.
///
/// One request at a time. Bounded three ways because a small model left alone
/// will loop: a step limit, a stop on the same action three times running, and
/// the user's stop button. Two consecutive malformed replies also end it.
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
  final CodeToolRunner runner;
  final CodeGatewayFactory gatewayFactory;

  final CodeSessionGrants grants = CodeSessionGrants();
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
  String? get runningSessionId => _sessionId;
  String? get pendingMessageId => _pendingMessageId;

  static const int repeatLimit = 3;

  void _setPhase(CodeAgentPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    notifyListeners();
  }

  String _nextId() =>
      'm${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_idSequence++}';

  // ---------------------------------------------------------------- API

  Future<List<String>> send(
    String text, {
    List<File> attachments = const [],
    int mentionChars = 1200,
  }) async {
    var trimmed = text.trim();
    if ((trimmed.isEmpty && attachments.isEmpty) || busy) return const [];
    final session = sessions.active ?? sessions.create();
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

  Future<void> resume() async {
    final session = sessions.active;
    if (session == null || busy || session.messages.isEmpty) return;
    final last = session.messages.last;
    if (last.isUser) {
      await _run(session.id);
      return;
    }
    final action = last.action;
    final retryable = last.failed || (action != null && !action.open);
    if (!retryable) return;
    await _run(session.id);
  }

  void approve(String messageId) => _decide(messageId, true);

  void approveForSession(String messageId) {
    final action = _message(_sessionId ?? '', messageId)?.action;
    if (action != null) grants.grant(_sessionId!, action);
    _decide(messageId, true);
  }

  void skip(String messageId) => _decide(messageId, false);

  void _decide(String messageId, bool allowed) {
    if (_pendingMessageId != messageId) return;
    final approval = _approval;
    if (approval != null && !approval.isCompleted) approval.complete(allowed);
  }

  Future<void> stop() async {
    if (!busy) return;
    _epoch++;
    final gateway = _gateway;
    final subscription = _subscription;
    final approval = _approval;
    if (approval != null && !approval.isCompleted) approval.complete(false);
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
      final small = gateway.budget.examples;
      final allowEdit = !gateway.isLocal;
      final allowShell = runner.allowShell;
      final env = runner.environment;
      final recent = <String>[];
      var malformedStreak = 0;
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

        final raw = await _stream(gateway, sessionId, messageId, epoch,
            small: small,
            allowShell: allowShell,
            allowEdit: allowEdit,
            env: env);
        if (epoch != _epoch) {
          _abandon(sessionId, messageId);
          return;
        }
        if (raw == null) return; // _stream recorded the error.

        final reply = AgentProtocol.decode(
          raw,
          allowShell: allowShell,
          allowEdit: allowEdit,
        );

        if (reply.malformed) {
          malformedStreak++;
          _finishMessage(
            sessionId,
            messageId,
            text: reply.prose,
            errorCode: reply.notice == AgentProtocol.cutOffNotice
                ? CodeErrorCode.cutOff
                : CodeErrorCode.malformed,
          );
          if (malformedStreak >= 2) return;
          continue;
        }
        malformedStreak = 0;

        if (reply.answer) {
          if (reply.prose.isEmpty && acted) {
            sessions.removeMessage(sessionId, messageId);
            return;
          }
          _finishMessage(
            sessionId,
            messageId,
            text: reply.prose,
            errorCode: reply.prose.isEmpty ? CodeErrorCode.empty : null,
          );
          return;
        }

        final call = reply.call!;
        recent.add(call.signature);
        final repeating =
            recent.where((s) => s == call.signature).length >= repeatLimit;
        _finishMessage(sessionId, messageId,
            text: reply.prose, action: _codeActionFor(call));
        final handled = await _handle(sessionId, messageId, call, epoch);
        if (epoch != _epoch || handled == null) return;
        acted = true;
        if (repeating) {
          _appendError(sessionId, CodeErrorCode.repeating);
          return;
        }
      }
      _appendError(sessionId, CodeErrorCode.stepLimit);
    } catch (error) {
      _appendError(sessionId, _codeFor(error), detail: _detailFor(error));
    } finally {
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

  Future<String?> _stream(
    CodeModelGateway gateway,
    String sessionId,
    String messageId,
    int epoch, {
    required bool small,
    required bool allowShell,
    required bool allowEdit,
    required CommandEnvironment env,
  }) async {
    final session = sessions.byId(sessionId)!;
    final history = [
      for (final message in session.messages)
        if (message.id != messageId) message,
    ];
    final turns = AgentPrompt.buildTurns(
      history,
      remind: small,
      observationChars: gateway.budget.observationChars,
    );
    if (small) {
      turns.insertAll(0, AgentPrompt.exampleTurns(allowShell: allowShell));
    }
    if (turns.isEmpty || turns.last.role != 'user') {
      turns.add(const CodeTurn.user('Continue.'));
    }
    final completion = CodeCompletion(
      system: AgentPrompt.systemPrompt(
        env: env,
        allowShell: allowShell,
        allowEdit: allowEdit,
      ),
      turns: turns,
      conversationId: 'code-$sessionId',
      maxTokens: gateway.isLocal ? 1024 : 4096,
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

    bool acted(String text) {
      // Only a complete action stops the read early. A prose answer can't be
      // recognised mid-stream (a partial ```wri is not yet a tag), so it ends
      // with the stream instead.
      return AgentProtocol.decode(text,
              allowShell: allowShell, allowEdit: allowEdit)
          .hasCall;
    }

    final stream = gateway.complete(completion);
    _subscription = stream.listen(
      (fragment) {
        if (epoch != _epoch) return;
        buffer.write(fragment);
        pending ??= Timer(streamUpdateInterval, show);
        // Stop reading once one complete action is present, or the model has
        // written a lot and none of it is for the user (reasoning on repeat).
        if (buffer.length > 48 &&
            AgentProtocol.clean(buffer.toString()).trim().isEmpty) {
          _cancelStream();
          finish(buffer.toString());
          return;
        }
        if (fragment.contains('`') && acted(buffer.toString())) {
          _cancelStream();
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

  void _cancelStream() {
    unawaited(_subscription?.cancel());
    unawaited(_gateway
        ?.cancel()
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .catchError((Object _) {}));
  }

  Future<ToolResult?> _handle(
    String sessionId,
    String messageId,
    AgentCall call,
    int epoch,
  ) async {
    final proposed = _codeActionFor(call);
    if (codeNeedsApproval(settings.settings.permissionMode, proposed) &&
        !grants.covers(sessionId, proposed)) {
      _pendingMessageId = messageId;
      _approval = Completer<bool>();
      _setPhase(CodeAgentPhase.awaitingApproval);
      final allowed = await _approval!.future;
      _pendingMessageId = null;
      _approval = null;
      if (epoch != _epoch) {
        _setAction(sessionId, messageId,
            proposed.copyWith(status: CodeActionStatus.skipped));
        return null;
      }
      if (!allowed) {
        _setAction(sessionId, messageId,
            proposed.copyWith(status: CodeActionStatus.skipped));
        return null;
      }
    }
    _setPhase(CodeAgentPhase.running);
    _setAction(sessionId, messageId,
        proposed.copyWith(status: CodeActionStatus.running));
    final live = LiveOutput((text) {
      final current = _message(sessionId, messageId)?.action;
      if (current == null || current.status != CodeActionStatus.running) return;
      _setAction(sessionId, messageId, current.copyWith(output: text));
    });
    final result = await runner.run(sessionId, call, onOutput: live.add);
    live.close();
    final finished = _finished(proposed, result);
    if (epoch != _epoch) {
      _setAction(sessionId, messageId, finished);
      return null;
    }
    _setAction(sessionId, messageId, finished);
    return result;
  }

  // ------------------------------------------------------------ helpers

  static CodeAction _codeActionFor(AgentCall call) => switch (call.tool) {
        AgentTool.read =>
          CodeAction(kind: CodeActionKind.readFile, path: call.path),
        AgentTool.list =>
          CodeAction(kind: CodeActionKind.listDir, path: call.path),
        AgentTool.write => CodeAction(
            kind: CodeActionKind.writeFile,
            path: call.path,
            content: call.content),
        AgentTool.edit => CodeAction(
            kind: CodeActionKind.editFile,
            path: call.path,
            content: call.content),
        AgentTool.bash => CodeAction.shell(call.command),
      };

  static CodeAction _finished(CodeAction base, ToolResult result) {
    final status = result.denied != null
        ? CodeActionStatus.denied
        : (result.ok ? CodeActionStatus.done : CodeActionStatus.failed);
    return CodeAction(
      kind: base.kind,
      status: status,
      command: base.command,
      path: base.path,
      content: base.content,
      output: result.text,
      exitCode: result.exitCode,
      truncated: result.truncated,
      timedOut: result.timedOut,
      deniedReason: result.denied,
      deniedDetail: result.deniedDetail,
      previous: result.previous,
      after: base.isEdit ? result.after : base.after,
    );
  }

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
