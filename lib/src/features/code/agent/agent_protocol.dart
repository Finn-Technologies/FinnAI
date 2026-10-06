import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';

/// What one model reply contains.
@immutable
class ParsedReply {
  const ParsedReply({
    required this.prose,
    this.action,
    this.cutOff = false,
    this.malformed = false,
    this.ignoredActions = 0,
  });

  /// The words around the action: all of the reply when there is no action,
  /// the part before the action when there is one. Anything the model wrote
  /// *after* its action is dropped: it is a guess at a result that has not
  /// arrived yet.
  final String prose;
  final CodeAction? action;

  /// The reply ended inside the action block (out of tokens). A half-written
  /// file or command is never run.
  final bool cutOff;

  /// A block tagged as an action that cannot be used: a `file` block with no
  /// name, an empty `sh` block. Nothing ran; the model is told why.
  final bool malformed;

  /// Further action blocks after the first. Only one action runs per step.
  final int ignoredActions;

  bool get hasAction => action != null;
}

/// The text protocol between FinnAI Code and its model.
///
/// The model acts by writing one fenced block per reply, and stops:
///
///     ```sh
///     ls
///     ```
///
///     ```file notes.txt
///     the whole file
///     ```
///
/// Plain text, not JSON function calls, on purpose: a 1.6B model produces it
/// reliably, every provider carries it without special tool support, and a
/// reply that breaks the format degrades to ordinary prose instead of
/// failing. The result comes back as the next user message.
abstract final class AgentProtocol {
  static const Set<String> _shellTags = {
    'sh',
    'bash',
    'shell',
    'zsh',
    'console'
  };
  static const Set<String> _fileTags = {'file', 'write', 'create', 'save'};

  /// The instructions the model is given. Short on purpose: on the on-device
  /// model every token here is a token less for the project.
  ///
  /// [container] says commands run in the Linux container (busybox, scripts
  /// can be made executable) rather than in the device's toybox shell.
  static String systemPrompt({required bool shell, bool container = false}) {
    final buffer = StringBuffer()
      ..writeln('You are FinnAI Code, a coding agent in a project folder on '
          "the user's phone. You act by writing ONE action per reply, then "
          'you stop and wait. The result comes back in the next message.')
      ..writeln();
    if (shell) {
      buffer
        ..writeln('Run a shell command:')
        ..writeln('```sh')
        ..writeln('ls')
        ..writeln('```');
    }
    buffer
      ..writeln('Create or replace a whole file:')
      ..writeln('```file hello.sh')
      ..writeln('echo hello')
      ..writeln('```')
      ..writeln()
      ..writeln('Rules:')
      ..writeln('- Write at most one action per reply, and nothing after it.')
      ..writeln('- Paths are relative to the project folder. Never use / or ..')
      ..writeln('- To create or change a file, ALWAYS use the file action. '
          'Never just print its contents, and never use echo or heredocs.')
      ..writeln('- Look before you change things: ls, then cat.')
      ..writeln('- If a file contains three backticks, fence it with four.')
      ..writeln('- Never invent the result of an action. Wait for it.')
      ..writeln('- When the task is done, reply in plain text with a short '
          'summary and no action. Answer in the language the user wrote in.');
    if (shell && container) {
      buffer.writeln('- Commands run in a small Linux machine (busybox ash): '
          'ls cat head tail wc grep sed awk find sort uniq cut tr diff tar '
          'gzip vi chmod. Shell scripts run (chmod +x, then ./x.sh). There is '
          'no python, node, git, compiler or network.');
    } else if (shell) {
      buffer.writeln('- Commands: ls cat head tail wc grep sed awk find sort '
          'uniq cut tr diff tar gzip bc mkdir cp mv rm touch stat. There is '
          'no python, node, git or compiler.');
    } else {
      buffer.writeln('- You cannot run commands here, only write files.');
    }
    return buffer.toString().trimRight();
  }

  /// Said at the end of a user's request, to a small model only. The model
  /// weighs the last message most, and the assistant persona above it says
  /// "answer directly": without this, "create a file containing Hello" is
  /// answered with the word Hello. The reminder is the cheapest fix that
  /// works; it is not shown to the user.
  static String taskReminder({required bool shell}) => shell
      ? 'Reply with one action: ```file <path> with the whole file, or ```sh '
          'with a command.'
      : 'Reply with one action: ```file <path> with the whole file.';

  /// The same, after an action's result has come back.
  static const String resultReminder =
      'Is the task finished? Then reply with a short plain-text summary and no '
      'action block. If not, reply with the next action.';

  /// [turn] with the reminder that fits where it sits: [afterReply] is true
  /// when it answers one of the model's own replies (a result), false when it
  /// is the person's request.
  static CodeTurn reminded(
    CodeTurn turn, {
    required bool afterReply,
    required bool shell,
  }) =>
      CodeTurn(
        turn.role,
        '${turn.content}\n\n'
        '${afterReply ? resultReminder : taskReminder(shell: shell)}',
      );

  /// [raw] without the model's reasoning markers.
  ///
  /// The on-device model is prompted to think in `<think>` tags and sometimes
  /// writes only the tags, over and over, or leaves a stray closing one. The
  /// engine strips a block at the very start of a reply; this strips the rest,
  /// so what is parsed and shown is only what the model said to the user.
  ///
  /// A 1.6B model also sometimes repeats the hidden reminder that closes the
  /// prompt; that is an instruction to it, not an answer, so it is dropped.
  static String clean(String raw) {
    var text = raw
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
        .replaceAll(RegExp(r'<think>[\s\S]*$'), '')
        .replaceAll(RegExp(r'</?think>'), '');
    for (final echo in [
      resultReminder,
      taskReminder(shell: true),
      taskReminder(shell: false),
    ]) {
      text = text.replaceAll(echo, '');
    }
    return text.trim();
  }

  /// A short worked example, shown to a small model as if it had already
  /// happened: ask, act, see the result, act again, answer. One example of the
  /// exact format does more than any rule in the system prompt, because a 1.6B
  /// model copies what it has just seen. Its user turns carry the same
  /// reminders the real ones do.
  static List<CodeTurn> exampleTurns({required bool shell}) => [
        reminded(
          const CodeTurn.user('Create hello.txt that says hi.'),
          afterReply: false,
          shell: shell,
        ),
        CodeTurn.assistant(
          actionText(CodeAction.write('hello.txt', 'hi'), compact: false),
        ),
        reminded(
          const CodeTurn.user('Wrote hello.txt (2 characters).'),
          afterReply: true,
          shell: shell,
        ),
        if (shell) ...[
          CodeTurn.assistant(
            actionText(const CodeAction.shell('cat hello.txt'), compact: false),
          ),
          reminded(
            const CodeTurn.user('Result (exit code 0):\nhi'),
            afterReply: true,
            shell: shell,
          ),
        ],
        const CodeTurn.assistant(
            'Done. I created hello.txt and it contains: hi'),
      ];

  /// Reads the first action out of a reply.
  ///
  /// A fence is an action only if it is tagged as one (`sh`, `file path`).
  /// Code shown in any other fence (` ```python `) is the model explaining,
  /// not acting, and stays in the prose.
  static ParsedReply parse(String raw) {
    final lines = clean(raw).split('\n');
    final prose = StringBuffer();
    CodeAction? action;
    var cutOff = false;
    var malformed = false;
    var ignored = 0;

    var i = 0;
    while (i < lines.length) {
      final open = _openingFence(lines[i]);
      if (open == null) {
        if (action == null) prose.writeln(lines[i]);
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
      final parsed = _actionFor(open.info, body);
      if (parsed == null && action == null && _isActionTag(open.info)) {
        malformed = true;
      }
      if (parsed == null) {
        // An ordinary code block: part of the prose (before any action).
        if (action == null) {
          prose.writeln(lines[i]);
          for (final line in body) {
            prose.writeln(line);
          }
          if (closed) prose.writeln(lines[j]);
        }
      } else if (action == null) {
        if (closed) {
          action = parsed;
        } else {
          cutOff = true;
          action = null;
        }
      } else {
        ignored++;
      }
      i = closed ? j + 1 : lines.length;
    }
    return ParsedReply(
      prose: prose.toString().trim(),
      action: action,
      cutOff: cutOff,
      malformed: malformed && action == null,
      ignoredActions: ignored,
    );
  }

  /// True when [info] names an action, whether or not the block is usable.
  static bool _isActionTag(String info) {
    if (info.isEmpty) return false;
    final tag = info
        .split(RegExp(r'\s+'))
        .first
        .toLowerCase()
        .replaceAll(RegExp(r':$'), '');
    return _shellTags.contains(tag) || _fileTags.contains(tag);
  }

  /// True once the reply holds a complete action. The loop stops reading the
  /// stream at that point: a small model tends to carry on and make up the
  /// result, and every token after the action is time the user waits for.
  static bool hasCompleteAction(String raw) => parse(raw).hasAction;

  static ({int length, String info})? _openingFence(String line) {
    final match = RegExp(r'^\s{0,3}(`{3,})\s*([^`]*)$').firstMatch(line);
    if (match == null) return null;
    return (length: match.group(1)!.length, info: match.group(2)!.trim());
  }

  static bool _closes(String line, int openLength) {
    final match = RegExp(r'^\s{0,3}(`{3,})\s*$').firstMatch(line);
    return match != null && match.group(1)!.length >= openLength;
  }

  static CodeAction? _actionFor(String info, List<String> body) {
    if (info.isEmpty) return null;
    final parts = info.split(RegExp(r'\s+'));
    final tag = parts.first.toLowerCase().replaceAll(RegExp(r':$'), '');
    if (_shellTags.contains(tag)) {
      final command = body
          .map((line) => line.replaceFirst(RegExp(r'^\s*\$ '), ''))
          .join('\n')
          .trim();
      return command.isEmpty ? null : CodeAction.shell(command);
    }
    if (_fileTags.contains(tag)) {
      var path = parts.skip(1).join(' ').trim();
      // `file: hello.py`, `file path=hello.py`, `file "hello.py"`.
      path = path
          .replaceFirst(RegExp(r'^(path|name|filename)\s*=\s*'), '')
          .replaceAll(RegExp(r'''^["'`]+|["'`]+$'''), '')
          .trim();
      if (path.isEmpty && info.contains(':')) {
        path = info.substring(info.indexOf(':') + 1).trim();
      }
      if (path.isEmpty) return null;
      return CodeAction.write(path, body.join('\n'));
    }
    return null;
  }

  // ---------------------------------------------------- back to the model

  /// What the model is told after [action] was handled.
  static String observation(CodeAction action, {required int maxChars}) {
    switch (action.status) {
      case CodeActionStatus.skipped:
        return 'The user chose not to run that. Ask what they want instead, '
            'or continue without it.';
      case CodeActionStatus.denied:
        return 'Not run: ${_denial(action)} Use only paths inside the project '
            'folder and no network.';
      case CodeActionStatus.proposed:
      case CodeActionStatus.running:
        return '';
      case CodeActionStatus.done:
      case CodeActionStatus.failed:
        break;
    }
    if (!action.isShell) {
      return action.status == CodeActionStatus.done
          ? 'Wrote ${action.path} (${action.content.length} characters).'
          : 'Could not write ${action.path}: ${action.output}';
    }
    final output = action.output.trim();
    final buffer = StringBuffer();
    if (action.timedOut) {
      buffer.write('The command timed out and was stopped.');
    } else {
      buffer.write('Result (exit code ${action.exitCode ?? 0})');
    }
    buffer.write(':\n');
    buffer.write(output.isEmpty ? '(no output)' : clip(output, maxChars));
    if (action.truncated) buffer.write('\n(output was cut short)');
    return buffer.toString();
  }

  static String _denial(CodeAction action) => switch (action.deniedReason) {
        PolicyReason.blockedProgram =>
          '"${action.deniedDetail}" is not allowed.',
        PolicyReason.network => 'network commands are off.',
        PolicyReason.outsideWorkspace =>
          '"${action.deniedDetail}" is outside the project folder.',
        PolicyReason.parentPath => '".." is not allowed in paths.',
        PolicyReason.obfuscated => 'that command is not allowed.',
        PolicyReason.tooLong => 'the command is too long.',
        PolicyReason.empty => 'the command is empty.',
        null => 'that was refused.',
      };

  /// Message for a block tagged as an action that could not be used.
  static const String malformedNotice =
      'That action block was not usable, so nothing ran. A file block needs a '
      'name: ```file notes.txt. A command goes in ```sh.';

  /// Message for a reply that ended inside its action block.
  static const String cutOffNotice =
      'Your reply was cut off before the action ended, so nothing ran. '
      'Send a shorter action.';

  /// Keeps the head and the tail of [text] when it is longer than [max]:
  /// the start says what the output is, the end says how it finished.
  static String clip(String text, int max) {
    if (text.length <= max) return text;
    final head = (max * 0.6).floor();
    final tail = max - head;
    final omitted = text.length - head - tail;
    return '${text.substring(0, head)}\n… $omitted characters omitted …\n'
        '${text.substring(text.length - tail)}';
  }

  // ---------------------------------------------------------- transcript

  /// How an action appears when the model's own earlier reply is replayed.
  /// Older file writes are shortened: the file is on disk and `cat` brings it
  /// back, so replaying it whole would spend the model's small window on text
  /// it already wrote.
  static String actionText(CodeAction action, {required bool compact}) {
    if (action.isShell) return '```sh\n${action.command}\n```';
    var content = action.content;
    if (compact && content.length > 240) {
      final lines = '\n'.allMatches(content).length + 1;
      content = '(… $lines lines …)';
    }
    final fence = content.contains('```') ? '````' : '```';
    return '${fence}file ${action.path}\n$content\n$fence';
  }

  /// The conversation the model is shown for [messages]: each user message,
  /// each of the model's own replies with its action, and a result message
  /// after every handled action.
  ///
  /// Newest last. Older turns are dropped first when [budget] is exceeded, and
  /// the result of the newest action is always kept: it is what the model has
  /// to answer.
  static List<CodeTurn> turnsFor(
    List<CodeMessage> messages, {
    required CodeBudget budget,
  }) {
    final turns = <CodeTurn>[];
    final lastActionIndex = messages.lastIndexWhere((m) => m.action != null);
    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      if (message.isUser) {
        turns.add(CodeTurn.user(message.text));
        continue;
      }
      final action = message.action;
      final text = [
        if (message.text.trim().isNotEmpty) message.text.trim(),
        if (action != null)
          actionText(action, compact: index != lastActionIndex),
      ].join('\n\n');
      final retried = message.errorCode == CodeErrorCode.cutOff ||
          message.errorCode == CodeErrorCode.malformed;
      if (text.isEmpty && !retried) continue;
      turns.add(CodeTurn.assistant(text.isEmpty ? '…' : text));
      if (action != null && !action.open) {
        final result = observation(action, maxChars: budget.observationChars);
        if (result.isNotEmpty) turns.add(CodeTurn.user(result));
      } else if (message.errorCode == CodeErrorCode.cutOff) {
        turns.add(const CodeTurn.user(cutOffNotice));
      } else if (message.errorCode == CodeErrorCode.malformed) {
        turns.add(const CodeTurn.user(malformedNotice));
      }
    }
    return _fit(turns, budget.historyChars);
  }

  /// Drops the oldest turns until the rest fit, keeping the newest turn and
  /// starting on a user turn.
  static List<CodeTurn> _fit(List<CodeTurn> turns, int maxChars) {
    var total = 0;
    var start = turns.length;
    for (var i = turns.length - 1; i >= 0; i--) {
      total += turns[i].content.length + 16;
      if (total > maxChars && start < turns.length) break;
      start = i;
    }
    var kept = turns.sublist(start);
    while (kept.length > 1 && kept.first.role != 'user') {
      kept = kept.sublist(1);
    }
    return kept;
  }
}
