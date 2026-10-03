import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';

enum CodeActionKind { shell, writeFile }

/// Where an action is in its life.
enum CodeActionStatus {
  /// Shown to the user, waiting for a tap.
  proposed,
  running,
  done,

  /// Ran and failed: a non-zero exit, a timeout, a file that could not be
  /// written.
  failed,

  /// The user chose not to run it.
  skipped,

  /// The policy refused it before it started.
  denied,
}

/// One thing the agent did or asked to do: run a command, or write a file.
@immutable
class CodeAction {
  const CodeAction({
    required this.kind,
    this.status = CodeActionStatus.proposed,
    this.command = '',
    this.path = '',
    this.content = '',
    this.output = '',
    this.exitCode,
    this.truncated = false,
    this.timedOut = false,
    this.deniedReason,
    this.deniedDetail = '',
  });

  const CodeAction.shell(String command)
      : this(kind: CodeActionKind.shell, command: command);

  const CodeAction.write(String path, String content)
      : this(kind: CodeActionKind.writeFile, path: path, content: content);

  final CodeActionKind kind;
  final CodeActionStatus status;

  /// For [CodeActionKind.shell].
  final String command;

  /// For [CodeActionKind.writeFile]: relative to the project folder.
  final String path;
  final String content;

  /// What the command printed, or why a write failed.
  final String output;
  final int? exitCode;
  final bool truncated;
  final bool timedOut;
  final PolicyReason? deniedReason;
  final String deniedDetail;

  bool get isShell => kind == CodeActionKind.shell;

  /// Waiting on the user, or on the shell.
  bool get open =>
      status == CodeActionStatus.proposed || status == CodeActionStatus.running;

  /// Same action, ignoring what happened to it. The loop uses this to notice
  /// a model repeating itself.
  String get signature => isShell ? 'sh:$command' : 'file:$path:$content';

  /// Longest output and file text kept on disk. The workspace holds the real
  /// files; this is only what the transcript shows.
  static const int storedOutputChars = 4000;
  static const int storedContentChars = 4000;

  CodeAction copyWith({
    CodeActionStatus? status,
    String? output,
    int? exitCode,
    bool? truncated,
    bool? timedOut,
    PolicyReason? deniedReason,
    String? deniedDetail,
  }) =>
      CodeAction(
        kind: kind,
        status: status ?? this.status,
        command: command,
        path: path,
        content: content,
        output: output ?? this.output,
        exitCode: exitCode ?? this.exitCode,
        truncated: truncated ?? this.truncated,
        timedOut: timedOut ?? this.timedOut,
        deniedReason: deniedReason ?? this.deniedReason,
        deniedDetail: deniedDetail ?? this.deniedDetail,
      );

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'status': status.name,
        if (command.isNotEmpty) 'command': command,
        if (path.isNotEmpty) 'path': path,
        if (content.isNotEmpty) 'content': _clip(content, storedContentChars),
        if (output.isNotEmpty) 'output': _clip(output, storedOutputChars),
        if (exitCode != null) 'exit': exitCode,
        if (truncated) 'truncated': true,
        if (timedOut) 'timedOut': true,
        if (deniedReason != null) 'denied': deniedReason!.name,
        if (deniedDetail.isNotEmpty) 'deniedDetail': deniedDetail,
      };

  static CodeAction? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = CodeActionKind.values
        .where((value) => value.name == json['kind'])
        .firstOrNull;
    if (kind == null) return null;
    var status = CodeActionStatus.values
            .where((value) => value.name == json['status'])
            .firstOrNull ??
        CodeActionStatus.failed;
    // An action cannot still be waiting for a tap after the app was closed.
    if (status == CodeActionStatus.proposed ||
        status == CodeActionStatus.running) {
      status = CodeActionStatus.skipped;
    }
    return CodeAction(
      kind: kind,
      status: status,
      command: json['command'] as String? ?? '',
      path: json['path'] as String? ?? '',
      content: json['content'] as String? ?? '',
      output: json['output'] as String? ?? '',
      exitCode: json['exit'] as int?,
      truncated: json['truncated'] == true,
      timedOut: json['timedOut'] == true,
      deniedReason: PolicyReason.values
          .where((value) => value.name == json['denied'])
          .firstOrNull,
      deniedDetail: json['deniedDetail'] as String? ?? '',
    );
  }

  static String _clip(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}…';
}

/// Why a reply ended without an answer.
///
/// A short code, not a sentence: the screen words it in the user's language.
/// `provider:<failure>` carries a [ProviderFailure] name; the rest are the
/// loop's own stops.
abstract final class CodeErrorCode {
  static const String stepLimit = 'step_limit';
  static const String repeating = 'repeating';
  static const String empty = 'empty';
  static const String cutOff = 'cut_off';
  static const String malformed = 'malformed_action';
  static const String modelUnavailable = 'model_unavailable';
  static const String engine = 'engine';
  static const String providerPrefix = 'provider:';
}

enum CodeRole { user, assistant }

@immutable
class CodeMessage {
  const CodeMessage({
    required this.id,
    required this.role,
    required this.createdAt,
    this.text = '',
    this.action,
    this.errorCode,
    this.errorDetail = '',
    this.modelLabel,
  });

  final String id;
  final CodeRole role;
  final DateTime createdAt;

  /// What the person typed, or what the model said around its action.
  final String text;
  final CodeAction? action;
  final String? errorCode;
  final String errorDetail;

  /// Which model wrote it (assistant messages).
  final String? modelLabel;

  bool get isUser => role == CodeRole.user;
  bool get failed => errorCode != null;

  CodeMessage copyWith({
    String? text,
    CodeAction? action,
    bool clearAction = false,
    String? errorCode,
    String? errorDetail,
  }) =>
      CodeMessage(
        id: id,
        role: role,
        createdAt: createdAt,
        text: text ?? this.text,
        action: clearAction ? null : (action ?? this.action),
        errorCode: errorCode ?? this.errorCode,
        errorDetail: errorDetail ?? this.errorDetail,
        modelLabel: modelLabel,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'role': role.name,
        'at': createdAt.toIso8601String(),
        if (text.isNotEmpty) 'text': text,
        if (action != null) 'action': action!.toJson(),
        if (errorCode != null) 'error': errorCode,
        if (errorDetail.isNotEmpty) 'errorDetail': errorDetail,
        if (modelLabel != null) 'model': modelLabel,
      };

  static CodeMessage? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final role = CodeRole.values
        .where((value) => value.name == json['role'])
        .firstOrNull;
    if (id is! String || role == null) return null;
    return CodeMessage(
      id: id,
      role: role,
      createdAt: DateTime.tryParse('${json['at']}') ?? DateTime.now(),
      text: json['text'] as String? ?? '',
      action: CodeAction.fromJson(json['action']),
      errorCode: json['error'] as String?,
      errorDetail: json['errorDetail'] as String? ?? '',
      modelLabel: json['model'] as String?,
    );
  }
}

/// One coding conversation and the project folder it works in.
@immutable
class CodeSession {
  const CodeSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.pinned = false,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CodeMessage> messages;
  final bool pinned;

  /// Newest first in the sidebar; pinned ones above the rest.
  static int byRecency(CodeSession a, CodeSession b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  }

  CodeSession copyWith({
    String? title,
    DateTime? updatedAt,
    List<CodeMessage>? messages,
    bool? pinned,
  }) =>
      CodeSession(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messages: messages ?? this.messages,
        pinned: pinned ?? this.pinned,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'created': createdAt.toIso8601String(),
        'updated': updatedAt.toIso8601String(),
        if (pinned) 'pinned': true,
        'messages': [for (final message in messages) message.toJson()],
      };

  static CodeSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final created = DateTime.tryParse('${json['created']}') ?? DateTime.now();
    return CodeSession(
      id: id,
      title: json['title'] as String? ?? '',
      createdAt: created,
      updatedAt: DateTime.tryParse('${json['updated']}') ?? created,
      pinned: json['pinned'] == true,
      messages: [
        for (final raw in (json['messages'] as List?) ?? const [])
          if (CodeMessage.fromJson(raw) case final message?) message,
      ],
    );
  }
}
