import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/agent/agent_tools.dart';
import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';

/// Everything the model is shown as instructions: the system prompt, a worked
/// example for the small model, and (later tasks) the observation text fed back
/// after each action. One clear voice: short, closed, and exact about the tags.
abstract final class AgentPrompt {
  static String systemPrompt({
    required CommandEnvironment env,
    required bool allowShell,
    required bool allowEdit,
  }) {
    final buffer = StringBuffer()
      ..writeln('You are FinnAI Code, a coding agent in a private project '
          'folder. Act by writing ONE action per reply, then stop and wait; '
          'the result comes back in the next message.')
      ..writeln()
      ..writeln('Read a file:')
      ..writeln('```read path```')
      ..writeln('List a folder (omit the path for the root):')
      ..writeln('```list```')
      ..writeln('Create or replace a whole file:')
      ..writeln('```write path')
      ..writeln('<the whole file>')
      ..writeln('```')
      ..writeln('When the task is done, reply with a short summary and no '
          'file:')
      ..writeln('```answer')
      ..writeln('<summary>')
      ..writeln('```');
    if (allowEdit) {
      buffer
        ..writeln('Change part of an existing file:')
        ..writeln('```edit path')
        ..writeln('<<<<<<< SEARCH')
        ..writeln('exact text to find')
        ..writeln('=======')
        ..writeln('replacement')
        ..writeln('>>>>>>> REPLACE')
        ..writeln('```');
    }
    if (allowShell) {
      buffer
        ..writeln('Run a shell command:')
        ..writeln('```sh')
        ..writeln('<command>')
        ..writeln('```');
    }
    buffer
      ..writeln()
      ..writeln('Rules:')
      ..writeln('- Write at most one action per reply, and nothing after it.')
      ..writeln('- Paths are relative to the project folder; never start with '
          '"/" and never use "..".')
      ..writeln('- Look before you change: list, then read, then write.')
      ..writeln('- If a file body contains three backticks, fence the block '
          'with four.')
      ..writeln('- Never invent a result; wait for it to come back.')
      ..writeln('- Answer in the language the user wrote in.')
      ..writeln(_environmentLine(env, allowShell));
    return buffer.toString().trim();
  }

  static String _environmentLine(CommandEnvironment env, bool allowShell) {
    if (!allowShell) {
      return 'You cannot run commands here; you can only read, list, and write '
          'files.';
    }
    return switch (env) {
      CommandEnvironment.linux =>
        'Commands run in Alpine Linux (sh) in /workspace with internet: install '
            'what you need first (apk add python3 nodejs npm git build-base; '
            'pip install and npm install work).',
      CommandEnvironment.container =>
        'Commands run in a small Linux machine (busybox ash): ls cat head tail '
            'wc grep sed awk find sort uniq cut tr diff tar gzip vi chmod. No '
            'python, node, git, compiler, or network.',
      CommandEnvironment.device =>
        'Commands: ls cat head tail wc grep sed awk find sort uniq cut tr diff '
            'tar gzip bc mkdir cp mv rm touch stat. No python, node, git, or '
            'compiler.',
      CommandEnvironment.none =>
        'You cannot run commands here; you can only read, list, and write '
            'files.',
    };
  }

  /// A worked example shown to a small model before the conversation. One
  /// example of the exact shape does more than any rule: the model copies what
  /// it just saw. Ends on a plain-text answer so "done with no action" is part
  /// of the pattern too.
  static List<CodeTurn> exampleTurns({required bool allowShell}) => [
        const CodeTurn.user('Create hello.txt containing hi.'),
        const CodeTurn.assistant('```write hello.txt\nhi\n```'),
        const CodeTurn.user('Wrote hello.txt (2 characters).'),
        if (allowShell) ...[
          const CodeTurn.assistant('```sh\ncat hello.txt\n```'),
          const CodeTurn.user('Result (exit code 0):\nhi'),
        ],
        const CodeTurn.assistant('Done. hello.txt now contains: hi'),
      ];

  /// What the model is told after [result] came back from [tool]. Short and
  /// literal: it names what happened and, for a command, the exit code and the
  /// output — so the model sees the truth instead of inventing it.
  static String observationFor(
    ToolResult result, {
    required AgentTool tool,
    int maxChars = 1600,
  }) {
    if (result.denied != null) {
      return 'Not run: ${_denial(result)} Use only paths inside the project '
          'folder and no network.';
    }
    return switch (tool) {
      AgentTool.write || AgentTool.edit => _fileObservation(result, tool),
      AgentTool.read => result.ok
          ? clip(result.text, maxChars)
          : 'Could not read ${result.path}: ${result.text}',
      AgentTool.list => result.ok
          ? clip(result.text, maxChars)
          : 'Could not list ${result.path.isEmpty ? 'the folder' : result.path}'
              ': ${result.text}',
      AgentTool.bash => _bashObservation(result, maxChars),
    };
  }

  static String _fileObservation(ToolResult result, AgentTool tool) {
    if (!result.ok) {
      return 'Could not ${tool == AgentTool.edit ? 'edit' : 'write'} '
          '${result.path}: ${result.text}';
    }
    // Saying so is what breaks a small model's write-the-same-file-again loop.
    if (result.previous != null && result.previous == result.after) {
      return '${result.path} already had exactly this content. Nothing changed.';
    }
    final verb = tool == AgentTool.edit ? 'Edited' : 'Wrote';
    return '$verb ${result.path} (${result.after.length} characters).';
  }

  static String _bashObservation(ToolResult result, int maxChars) {
    if (result.timedOut) return 'The command timed out and was stopped.';
    final buffer =
        StringBuffer('Result (exit code ${result.exitCode ?? 0}):\n');
    final output = result.text.trim();
    buffer.write(output.isEmpty ? '(no output)' : clip(output, maxChars));
    if (result.truncated) buffer.write('\n(output was cut short)');
    return buffer.toString();
  }

  static String _denial(ToolResult result) => switch (result.denied) {
        PolicyReason.blockedProgram =>
          '"${result.deniedDetail}" is not allowed.',
        PolicyReason.network => 'network commands are off.',
        PolicyReason.outsideWorkspace =>
          '"${result.deniedDetail}" is outside the project folder.',
        PolicyReason.parentPath => '".." is not allowed in paths.',
        PolicyReason.obfuscated => 'that command is not allowed.',
        PolicyReason.tooLong => 'the command is too long.',
        PolicyReason.empty => 'the command is empty.',
        null => 'that was refused.',
      };

  /// Keeps the head and the tail of [text] when longer than [max]: the start
  /// says what it is, the end says how it finished.
  static String clip(String text, int max) {
    if (text.length <= max) return text;
    final head = (max * 0.6).floor();
    final tail = max - head;
    final omitted = text.length - head - tail;
    return '${text.substring(0, head)}\n… $omitted characters omitted …\n'
        '${text.substring(text.length - tail)}';
  }

  // ------------------------------------------------------------ the replay

  static const String taskReminder =
      'Reply with exactly one action block. When the task is fully done, reply '
      'with ```answer and a short summary instead.';
  static const String resultReminder =
      'If the task is finished, reply with ```answer and a short summary. '
      'Otherwise reply with the next action.';

  /// The conversation the model sees for [messages]: each request, each of the
  /// agent's own actions with its result, and a repair note after a malformed
  /// reply. Append-only from one step to the next, which is what lets the
  /// engine keep reusing its cached prefix. [remind] adds the small model's
  /// nudge to each turn the model must answer.
  static List<CodeTurn> buildTurns(
    List<CodeMessage> messages, {
    required bool remind,
    int observationChars = 1600,
  }) {
    final turns = <CodeTurn>[];
    for (final message in messages) {
      if (message.isUser) {
        final body = message.context.isEmpty
            ? message.text
            : '${message.text}\n\n${message.context}';
        turns.add(CodeTurn.user(remind ? '$body\n\n$taskReminder' : body));
        continue;
      }
      final action = message.action;
      if (action != null && !action.open) {
        turns.add(CodeTurn.assistant(_actionBlock(action)));
        final observation = observationFor(
          toolResultOf(action),
          tool: _toolOf(action.kind),
          maxChars: observationChars,
        );
        turns.add(CodeTurn.user(
            remind ? '$observation\n\n$resultReminder' : observation));
      } else if (message.errorCode == CodeErrorCode.cutOff) {
        turns.add(CodeTurn.assistant(
            message.text.isEmpty ? '…' : message.text.trim()));
        turns.add(const CodeTurn.user(AgentProtocol.cutOffNotice));
      } else if (message.errorCode == CodeErrorCode.malformed) {
        turns.add(CodeTurn.assistant(
            message.text.isEmpty ? '…' : message.text.trim()));
        turns.add(const CodeTurn.user(AgentProtocol.malformedNotice));
      } else if (message.text.trim().isNotEmpty) {
        turns.add(CodeTurn.assistant(message.text.trim()));
      }
    }
    return turns;
  }

  static AgentTool _toolOf(CodeActionKind kind) => switch (kind) {
        CodeActionKind.shell => AgentTool.bash,
        CodeActionKind.writeFile => AgentTool.write,
        CodeActionKind.editFile => AgentTool.edit,
        CodeActionKind.readFile => AgentTool.read,
        CodeActionKind.listDir => AgentTool.list,
      };

  static ToolResult toolResultOf(CodeAction action) => ToolResult(
        ok: action.status == CodeActionStatus.done,
        path: action.path,
        text: action.output,
        exitCode: action.exitCode,
        truncated: action.truncated,
        timedOut: action.timedOut,
        denied: action.deniedReason,
        deniedDetail: action.deniedDetail,
        previous: action.previous,
        after: action.isEdit ? action.after : action.content,
      );

  /// The observation a stored [action] becomes, for replay and for the UI.
  static String observationForAction(CodeAction action) => observationFor(
        toolResultOf(action),
        tool: _toolOf(action.kind),
      );

  static String _actionBlock(CodeAction action) => switch (action.kind) {
        CodeActionKind.shell => '```sh\n${action.command}\n```',
        CodeActionKind.writeFile =>
          _fence('write ${action.path}', action.content),
        CodeActionKind.editFile =>
          _fence('edit ${action.path}', action.content),
        CodeActionKind.readFile => '```read ${action.path}\n```',
        CodeActionKind.listDir =>
          action.path.isEmpty ? '```list\n```' : '```list ${action.path}\n```',
      };

  static String _fence(String header, String content) {
    final fence = content.contains('```') ? '````' : '```';
    return '$fence$header\n$content\n$fence';
  }
}
