import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/providers/code_gateway.dart';

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
}
