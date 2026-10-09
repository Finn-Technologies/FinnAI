import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';

/// One thing the agent can do in a step. Kept deliberately tiny: a 1.6B model
/// picks reliably among few options, and every tool maps onto a primitive that
/// already exists (`CodeWorkspace`, `CodeActionRunner`).
enum AgentTool { read, list, write, edit, bash }

/// A single decoded action from one model reply.
@immutable
class AgentCall {
  const AgentCall({
    required this.tool,
    this.path = '',
    this.content = '',
    this.command = '',
  });

  const AgentCall.read(String path) : this(tool: AgentTool.read, path: path);
  const AgentCall.list([String path = ''])
      : this(tool: AgentTool.list, path: path);
  const AgentCall.write(String path, String content)
      : this(tool: AgentTool.write, path: path, content: content);
  const AgentCall.edit(String path, String blocks)
      : this(tool: AgentTool.edit, path: path, content: blocks);
  const AgentCall.bash(String command)
      : this(tool: AgentTool.bash, command: command);

  final AgentTool tool;

  /// The target file/dir, for read/list/write/edit.
  final String path;

  /// The file body (write), or the raw SEARCH/REPLACE blocks (edit).
  final String content;

  /// The shell command, for bash.
  final String command;

  bool get isShell => tool == AgentTool.bash;
  bool get isEdit => tool == AgentTool.edit;
}

/// What one model reply decoded to.
@immutable
class AgentReply {
  const AgentReply({
    this.call,
    this.prose = '',
    this.answer = false,
    this.malformed = false,
    this.notice = '',
  });

  /// The action to run, or null when the model is answering or slipped.
  final AgentCall? call;

  /// Text around the action; for an answer, the summary itself.
  final String prose;

  /// The model is done: it wrote a summary (or plain text) and no action.
  final bool answer;

  /// A block tagged as an action that could not be used: cut off, a file with
  /// no name, an edit/shell the current environment does not offer. Nothing
  /// runs; [notice] tells the model what was wrong.
  final bool malformed;
  final String notice;

  bool get hasCall => call != null;
}

/// What a tool did, ready to be turned into the next message the model sees.
@immutable
class ToolResult {
  const ToolResult({
    this.ok = true,
    this.path = '',
    this.text = '',
    this.exitCode,
    this.truncated = false,
    this.timedOut = false,
    this.denied,
    this.deniedDetail = '',
    this.previous,
    this.after = '',
  });

  final bool ok;

  /// The file or folder this result is about, where one applies.
  final String path;

  /// Read/list content, command stdout, or the error text of a failed file op.
  final String text;
  final int? exitCode;
  final bool truncated;
  final bool timedOut;

  /// Set when the policy refused the action before it ran.
  final PolicyReason? denied;
  final String deniedDetail;

  /// The file before a write/edit, and after it.
  final String? previous;
  final String after;
}

/// Reads the one action out of a model reply.
///
/// Text protocol on purpose, but a *closed* one: the model names a tool with a
/// fenced tag and the harness reads exactly one action, then stops. This is the
/// decode step of the validate/repair pattern Creations uses — a reply that
/// breaks the shape becomes [AgentReply.malformed] with a reason, not a crash.
///
/// [allowShell] and [allowEdit] reflect the environment/model: where commands
/// cannot run a `sh` block is malformed; the on-device 1.6B is not offered edits
/// (a full `write` is more reliable from it).
abstract final class AgentProtocol {
  static const Set<String> _shellTags = {
    'sh',
    'bash',
    'shell',
    'zsh',
    'console',
  };
  static const Set<String> _fileTags = {'file', 'write', 'create', 'save'};
  static const Set<String> _editTags = {'edit', 'patch'};
  static const Set<String> _answerTags = {'answer', 'done', 'finished'};

  static const String _malformedNotice =
      'That action block was not usable, so nothing ran. A file block needs a '
      'name: ```write notes.txt.';
  static const String _cutOffNotice =
      'Your reply was cut off before the action ended, so nothing ran. Send a '
      'shorter action.';
  static const String _shellOffNotice =
      'Commands cannot run here. Use ```write to create or change a file.';
  static const String _editOffNotice =
      'Edits are not available here. Use ```write <path> with the whole file.';

  /// [raw] without the model's reasoning markers and echoed reminders.
  static String clean(String raw) => raw
      .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
      .replaceAll(RegExp(r'<think>[\s\S]*$'), '')
      .replaceAll(RegExp(r'</?think>'), '')
      .trim();

  static AgentReply decode(
    String raw, {
    required bool allowShell,
    required bool allowEdit,
  }) {
    final lines = clean(raw).split('\n');
    final prose = StringBuffer();
    var action = _ScanState();
    var i = 0;
    while (i < lines.length) {
      final open = _openingFence(lines[i]);
      if (open == null) {
        if (!action.settled) prose.writeln(lines[i]);
        i++;
        continue;
      }
      final body = <String>[];
      var closed = false;
      var j = i + 1;
      for (; j < lines.length; j++) {
        if (_closes(lines[j], open.length)) {
          closed = true;
          break;
        }
        body.add(lines[j]);
      }
      final tag = _tag(open.info);

      if (tag == TagKind.answer && action.settled == false) {
        final summary = [
          prose.toString().trim(),
          body.join('\n').trim(),
        ].where((s) => s.isNotEmpty).join('\n');
        return AgentReply(prose: summary, answer: true);
      }

      final call = _actionFor(open.info, body);
      if (call == null) {
        // Not an action tag: ordinary code, part of the prose (before any
        // action). After an action it is a guess at a result and is dropped.
        if (!_isActionTag(tag)) {
          if (!action.settled) {
            prose.writeln(lines[i]);
            for (final line in body) {
              prose.writeln(line);
            }
            if (closed) prose.writeln(lines[j]);
          }
        } else if (!action.settled) {
          // A block tagged as an action but unusable.
          action = closed
              ? const _ScanState.malformed(AgentProtocol._malformedNotice)
              : const _ScanState.malformed(AgentProtocol._cutOffNotice);
        }
      } else if (!action.settled) {
        final blocked = _blockedReason(call, allowShell, allowEdit);
        if (blocked != null) {
          action = _ScanState.malformed(blocked);
        } else if (!closed) {
          action = const _ScanState.malformed(AgentProtocol._cutOffNotice);
        } else {
          return AgentReply(
            call: call,
            prose: prose.toString().trim(),
          );
        }
      }
      i = closed ? j + 1 : lines.length;
    }

    if (action.malformed) {
      return AgentReply(malformed: true, notice: action.notice);
    }
    final text = prose.toString().trim();
    return AgentReply(prose: text, answer: true);
  }

  static String? _blockedReason(
    AgentCall call,
    bool allowShell,
    bool allowEdit,
  ) {
    if (call.isShell && !allowShell) return _shellOffNotice;
    if (call.isEdit && !allowEdit) return _editOffNotice;
    return null;
  }

  static bool _isActionTag(TagKind tag) => tag != TagKind.none;

  static TagKind _tag(String info) {
    if (info.isEmpty) return TagKind.none;
    final first =
        info.split(RegExp(r'\s+')).first.toLowerCase().replaceAll(':', '');
    if (_shellTags.contains(first)) return TagKind.shell;
    if (_fileTags.contains(first)) return TagKind.file;
    if (_editTags.contains(first)) return TagKind.edit;
    if (first == 'read') return TagKind.read;
    if (first == 'list' || first == 'ls' || first == 'dir') return TagKind.list;
    if (_answerTags.contains(first)) return TagKind.answer;
    return TagKind.none;
  }

  static ({int length, String info})? _openingFence(String line) {
    final match = RegExp(r'^\s{0,3}(`{3,})\s*([^`]*)$').firstMatch(line);
    if (match == null) return null;
    return (length: match.group(1)!.length, info: match.group(2)!.trim());
  }

  static bool _closes(String line, int openLength) {
    final match = RegExp(r'^\s{0,3}(`{3,})\s*$').firstMatch(line);
    return match != null && match.group(1)!.length >= openLength;
  }

  static AgentCall? _actionFor(String info, List<String> body) {
    if (info.isEmpty) return null;
    final parts = info.split(RegExp(r'\s+'));
    final tag = parts.first.toLowerCase().replaceAll(':', '');
    if (_shellTags.contains(tag)) {
      final command = body
          .map((line) => line.replaceFirst(RegExp(r'^\s*\$ '), ''))
          .join('\n')
          .trim();
      return command.isEmpty ? null : AgentCall.bash(command);
    }
    if (_fileTags.contains(tag)) {
      final path = _path(parts.skip(1).join(' '), info);
      return path.isEmpty ? null : AgentCall.write(path, body.join('\n'));
    }
    if (_editTags.contains(tag)) {
      final path = _path(parts.skip(1).join(' '), info);
      return path.isEmpty ? null : AgentCall.edit(path, body.join('\n'));
    }
    if (tag == 'read') {
      final path = _path(parts.skip(1).join(' '), info);
      return path.isEmpty ? null : AgentCall.read(path);
    }
    if (tag == 'list' || tag == 'ls' || tag == 'dir') {
      return AgentCall.list(_path(parts.skip(1).join(' '), info));
    }
    return null;
  }

  /// Pulls a path out of `path=x`, `"x"`, `file: x`, or a bare token.
  static String _path(String rest, String info) {
    var path = rest.trim();
    path =
        path.replaceFirst(RegExp(r'^(path|name|filename)\s*=\s*'), '').trim();
    path = path.replaceAll(RegExp(r'''^["'`]+|["'`]+$'''), '').trim();
    if (path.isEmpty && info.contains(':')) {
      path = info.substring(info.indexOf(':') + 1).trim();
      path = path.replaceAll(RegExp(r'''^["'`]+|["'`]+$'''), '').trim();
    }
    return path;
  }
}

enum TagKind { none, shell, file, edit, read, list, answer }

/// Scanning state for [AgentProtocol.decode].
@immutable
class _ScanState {
  const _ScanState({this.malformed = false, this.notice = ''});
  const _ScanState.malformed(this.notice) : malformed = true;

  final bool malformed;
  final String notice;

  /// True once a fence has produced a call/answer or been judged; later text
  /// is a guess at an unseen result and is ignored.
  bool get settled => malformed;
}
