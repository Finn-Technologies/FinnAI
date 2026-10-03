import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/code/agent/agent_protocol.dart';
import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';

CodeMessage user(String text, [String id = 'u']) => CodeMessage(
      id: id,
      role: CodeRole.user,
      createdAt: DateTime(2026),
      text: text,
    );

CodeMessage assistant(
  String id, {
  String text = '',
  CodeAction? action,
  String? errorCode,
}) =>
    CodeMessage(
      id: id,
      role: CodeRole.assistant,
      createdAt: DateTime(2026),
      text: text,
      action: action,
      errorCode: errorCode,
    );

void main() {
  group('parse', () {
    test('plain text is all prose and has no action', () {
      final reply = AgentProtocol.parse('All done. The file is ready.');
      expect(reply.prose, 'All done. The file is ready.');
      expect(reply.action, isNull);
      expect(reply.cutOff, isFalse);
    });

    test('a shell block becomes a command, prose before it is kept', () {
      final reply = AgentProtocol.parse('Let me look.\n```sh\nls -la\n```');
      expect(reply.prose, 'Let me look.');
      expect(reply.action!.kind, CodeActionKind.shell);
      expect(reply.action!.command, 'ls -la');
      expect(reply.action!.status, CodeActionStatus.proposed);
    });

    test('shell tags and prompts are tolerated', () {
      for (final tag in ['sh', 'bash', 'shell', 'zsh', 'console', 'SH']) {
        final reply = AgentProtocol.parse('```$tag\n\$ echo hi\n```');
        expect(reply.action?.command, 'echo hi', reason: tag);
      }
    });

    test('a file block carries its path and whole content', () {
      final reply = AgentProtocol.parse(
        'Creating it.\n```file src/hello.py\nprint("hi")\n\nprint("bye")\n```',
      );
      expect(reply.action!.kind, CodeActionKind.writeFile);
      expect(reply.action!.path, 'src/hello.py');
      expect(reply.action!.content, 'print("hi")\n\nprint("bye")');
    });

    test('path spellings models actually produce', () {
      for (final info in [
        'file hello.sh',
        'file: hello.sh',
        'file "hello.sh"',
        'file path=hello.sh',
        'write hello.sh',
        'create hello.sh',
        'save hello.sh',
      ]) {
        final reply = AgentProtocol.parse('```$info\necho\n```');
        expect(reply.action?.path, 'hello.sh', reason: info);
      }
    });

    test('a file block with no path is not an action', () {
      expect(AgentProtocol.parse('```file\nx\n```').action, isNull);
      expect(AgentProtocol.parse('```sh\n\n```').action, isNull);
    });

    test('code in another language is explanation, not an action', () {
      final reply = AgentProtocol.parse(
        'Here is how it works:\n```python\nprint(1)\n```\nThat is all.',
      );
      expect(reply.action, isNull);
      expect(reply.prose, contains('print(1)'));
      expect(reply.prose, contains('That is all.'));
    });

    test('an untagged block is not an action', () {
      expect(AgentProtocol.parse('```\nrm -rf x\n```').action, isNull);
    });

    test('only the first action counts and what follows it is dropped', () {
      final reply = AgentProtocol.parse(
        '```sh\nls\n```\nThe output is:\nfoo.txt\n```sh\ncat foo.txt\n```',
      );
      expect(reply.action!.command, 'ls');
      expect(reply.ignoredActions, 1);
      expect(reply.prose, isEmpty);
    });

    test('an unfinished action is cut off and never returned', () {
      final shell = AgentProtocol.parse('```sh\nrm -rf build');
      expect(shell.cutOff, isTrue);
      expect(shell.action, isNull);

      final file = AgentProtocol.parse('Writing.\n```file a.txt\nhalf a fi');
      expect(file.cutOff, isTrue);
      expect(file.action, isNull);
      expect(file.prose, 'Writing.');
    });

    test('a longer fence lets a file contain triple backticks', () {
      final reply = AgentProtocol.parse(
        '````file README.md\n# Title\n```sh\nls\n```\nend\n````',
      );
      expect(reply.action!.path, 'README.md');
      expect(reply.action!.content, '# Title\n```sh\nls\n```\nend');
    });

    test('a block tagged as an action but unusable is flagged', () {
      final noName = AgentProtocol.parse('```file\nHello\n```');
      expect(noName.action, isNull);
      expect(noName.malformed, isTrue);
      expect(noName.cutOff, isFalse);

      expect(AgentProtocol.parse('```sh\n\n```').malformed, isTrue);
      // An ordinary code block, or a good action, is not malformed.
      expect(
          AgentProtocol.parse('```python\nprint(1)\n```').malformed, isFalse);
      expect(AgentProtocol.parse('```file a.txt\nx\n```').malformed, isFalse);
      expect(AgentProtocol.parse('plain').malformed, isFalse);
      // A good action wins over a later bad one.
      expect(
        AgentProtocol.parse('```sh\nls\n```\n```file\nx\n```').malformed,
        isFalse,
      );
    });

    test('the reminders show the path form the model must copy', () {
      expect(AgentProtocol.taskReminder(shell: true), contains('<path>'));
      expect(AgentProtocol.taskReminder(shell: false), contains('<path>'));
      expect(
          AgentProtocol.taskReminder(shell: false), isNot(contains('```sh')));
    });

    test('reasoning tags are removed, whole, stray or unterminated', () {
      expect(AgentProtocol.clean('<think>\n\n</think>\n\nHello'), 'Hello');
      expect(
        AgentProtocol.clean(
          'All set.\n\n${AgentProtocol.resultReminder}\n\nDone.',
        ),
        'All set.\n\n\n\nDone.',
      );
      expect(
        AgentProtocol.clean(AgentProtocol.taskReminder(shell: true)),
        '',
      );
      expect(AgentProtocol.clean('Hello\n</think>'), 'Hello');
      expect(AgentProtocol.clean('<think>plan</think>Done<think>more'), 'Done');
      expect(
        AgentProtocol.clean('<think></think><think></think><think></think>'),
        isEmpty,
      );
      expect(AgentProtocol.parse('<think>x</think>\n```sh\nls\n```').action,
          isNotNull);
      expect(AgentProtocol.parse('<think>\n\n</think>').prose, isEmpty);
    });

    test('hasCompleteAction only turns true when the block closes', () {
      expect(AgentProtocol.hasCompleteAction('```sh\nls'), isFalse);
      expect(AgentProtocol.hasCompleteAction('```sh\nls\n``'), isFalse);
      expect(AgentProtocol.hasCompleteAction('```sh\nls\n```'), isTrue);
      expect(AgentProtocol.hasCompleteAction('no fences here'), isFalse);
    });
  });

  group('observation', () {
    test('a command result carries exit code and output', () {
      const action = CodeAction(
        kind: CodeActionKind.shell,
        command: 'ls',
        status: CodeActionStatus.done,
        output: 'a.txt\nb.txt\n',
        exitCode: 0,
      );
      expect(
        AgentProtocol.observation(action, maxChars: 500),
        'Result (exit code 0):\na.txt\nb.txt',
      );
    });

    test('a failing command reports its code, empty output says so', () {
      const failed = CodeAction(
        kind: CodeActionKind.shell,
        command: 'false',
        status: CodeActionStatus.failed,
        exitCode: 1,
      );
      expect(
        AgentProtocol.observation(failed, maxChars: 500),
        'Result (exit code 1):\n(no output)',
      );
    });

    test('a timeout and a cut-short output are called out', () {
      const timedOut = CodeAction(
        kind: CodeActionKind.shell,
        command: 'sleep 100',
        status: CodeActionStatus.failed,
        timedOut: true,
        exitCode: 124,
      );
      expect(AgentProtocol.observation(timedOut, maxChars: 500),
          startsWith('The command timed out'));

      const long = CodeAction(
        kind: CodeActionKind.shell,
        command: 'yes',
        status: CodeActionStatus.done,
        output: 'y',
        exitCode: 0,
        truncated: true,
      );
      expect(AgentProtocol.observation(long, maxChars: 500),
          endsWith('(output was cut short)'));
    });

    test('long output keeps its head and its tail', () {
      final text = 'HEAD${'x' * 2000}TAIL';
      final clipped = AgentProtocol.clip(text, 100);
      expect(clipped.length, lessThan(160));
      expect(clipped, startsWith('HEAD'));
      expect(clipped, endsWith('TAIL'));
      expect(clipped, contains('characters omitted'));
      expect(AgentProtocol.clip('short', 100), 'short');
    });

    test('file results, skips and denials are explained to the model', () {
      expect(
        AgentProtocol.observation(
          const CodeAction(
            kind: CodeActionKind.writeFile,
            path: 'a.txt',
            content: 'hello',
            status: CodeActionStatus.done,
          ),
          maxChars: 500,
        ),
        'Wrote a.txt (5 characters).',
      );
      expect(
        AgentProtocol.observation(
          const CodeAction.shell('rm x')
              .copyWith(status: CodeActionStatus.skipped),
          maxChars: 500,
        ),
        contains('chose not to run'),
      );
      final denied = AgentProtocol.observation(
        const CodeAction.shell('cat /etc/hosts').copyWith(
          status: CodeActionStatus.denied,
          deniedReason: PolicyReason.outsideWorkspace,
          deniedDetail: '/etc/hosts',
        ),
        maxChars: 500,
      );
      expect(denied, contains('/etc/hosts'));
      expect(denied, contains('outside the project folder'));
    });
  });

  group('system prompt', () {
    test('describes both actions when commands can run', () {
      final prompt = AgentProtocol.systemPrompt(shell: true);
      expect(prompt, contains('```sh'));
      expect(prompt, contains('```file hello.sh'));
      expect(prompt, contains('no python'));
    });

    test('offers only files where commands cannot run', () {
      final prompt = AgentProtocol.systemPrompt(shell: false);
      expect(prompt, isNot(contains('```sh')));
      expect(prompt, contains('cannot run commands'));
    });

    test('stays short enough for a small model', () {
      // About 4 characters a token: well under 400 tokens.
      expect(AgentProtocol.systemPrompt(shell: true).length, lessThan(1500));
    });
  });

  group('exampleTurns', () {
    test('alternate, open with the user, and use the real format', () {
      for (final shell in [true, false]) {
        final turns = AgentProtocol.exampleTurns(shell: shell);
        expect(turns.first.role, 'user');
        expect(turns.last.role, 'assistant');
        for (var i = 1; i < turns.length; i++) {
          expect(turns[i].role, isNot(turns[i - 1].role));
        }
        // Every assistant step the example shows must parse as itself.
        final actions = [
          for (final t in turns.where((t) => t.role == 'assistant'))
            AgentProtocol.parse(t.content).action,
        ];
        // The example's user turns carry the reminders the real ones do.
        expect(turns.first.content,
            endsWith(AgentProtocol.taskReminder(shell: shell)));
        expect(turns[2].content, endsWith(AgentProtocol.resultReminder));
        expect(actions.first!.path, 'hello.txt');
        expect(actions.first!.content, 'hi');
        expect(actions.last, isNull, reason: 'the example ends in plain text');
      }
    });

    test('without commands the example never shows one', () {
      final text = AgentProtocol.exampleTurns(shell: false)
          .map((t) => t.content)
          .join('\n');
      expect(text, isNot(contains('```sh')));
      expect(
          AgentProtocol.exampleTurns(shell: true).map((t) => t.content).join(),
          contains('```sh'));
    });

    test('a reminder goes on a request or on a result, and says so', () {
      final request = AgentProtocol.reminded(
        const CodeTurn.user('do it'),
        afterReply: false,
        shell: true,
      );
      final result = AgentProtocol.reminded(
        const CodeTurn.user('Result'),
        afterReply: true,
        shell: true,
      );
      expect(
        request.content,
        'do it\n\n${AgentProtocol.taskReminder(shell: true)}',
      );
      expect(result.content, 'Result\n\n${AgentProtocol.resultReminder}');
      expect(request.role, 'user');
    });

    test('the on-device budget asks for the example, a cloud one does not', () {
      expect(CodeBudget.onDevice.examples, isTrue);
      expect(CodeBudget.cloud.examples, isFalse);
    });
  });

  group('turnsFor', () {
    const budget = CodeBudget(
      observationChars: 100,
      historyChars: 100000,
      maxSteps: 8,
    );

    test('replays user turns, replies and a result after each action', () {
      final turns = AgentProtocol.turnsFor([
        user('list files'),
        assistant(
          'a1',
          text: 'Looking.',
          action: const CodeAction(
            kind: CodeActionKind.shell,
            command: 'ls',
            status: CodeActionStatus.done,
            output: 'a.txt',
            exitCode: 0,
          ),
        ),
        assistant('a2', text: 'There is one file.'),
        user('thanks', 'u2'),
      ], budget: budget);

      expect(turns.map((t) => t.role), [
        'user',
        'assistant',
        'user',
        'assistant',
        'user',
      ]);
      expect(turns[1].content, 'Looking.\n\n```sh\nls\n```');
      expect(turns[2].content, 'Result (exit code 0):\na.txt');
      expect(turns[3].content, 'There is one file.');
    });

    test('an action still waiting has no result yet', () {
      final turns = AgentProtocol.turnsFor([
        user('go'),
        assistant('a1', action: const CodeAction.shell('ls')),
      ], budget: budget);
      expect(turns.map((t) => t.role), ['user', 'assistant']);
    });

    test('older file writes are shortened, the newest is kept whole', () {
      final big = 'line\n' * 100;
      final turns = AgentProtocol.turnsFor([
        user('go'),
        assistant('a1',
            action: CodeAction.write('one.txt', big)
                .copyWith(status: CodeActionStatus.done)),
        assistant('a2',
            action: CodeAction.write('two.txt', big)
                .copyWith(status: CodeActionStatus.done)),
      ], budget: budget);

      expect(turns[1].content, contains('one.txt'));
      expect(turns[1].content, contains('lines …'));
      expect(turns[1].content.length, lessThan(100));
      final newest = turns.lastWhere((t) => t.role == 'assistant');
      expect(newest.content, contains(big.trim()));
    });

    test('a file that contains backticks is fenced with four', () {
      final text = AgentProtocol.actionText(
        CodeAction.write('r.md', '```sh\nls\n```'),
        compact: false,
      );
      expect(text, startsWith('````file r.md'));
      expect(text, endsWith('````'));
      expect(AgentProtocol.parse(text).action!.content, '```sh\nls\n```');
    });

    test('a cut-off reply is followed by the notice, even with no prose', () {
      final turns = AgentProtocol.turnsFor([
        user('go'),
        assistant('a1', errorCode: CodeErrorCode.cutOff),
      ], budget: budget);
      expect(turns.last.content, AgentProtocol.cutOffNotice);
      expect(turns[1].role, 'assistant');
    });

    test('an unusable action is followed by the correction', () {
      final turns = AgentProtocol.turnsFor([
        user('go'),
        assistant('a1',
            text: '```file\nHello\n```', errorCode: CodeErrorCode.malformed),
      ], budget: budget);
      expect(turns.last.content, AgentProtocol.malformedNotice);
      expect(turns[1].role, 'assistant');
    });

    test('results are clipped to the observation budget', () {
      final turns = AgentProtocol.turnsFor([
        user('go'),
        assistant(
          'a1',
          action: CodeAction(
            kind: CodeActionKind.shell,
            command: 'cat big',
            status: CodeActionStatus.done,
            output: 'z' * 5000,
            exitCode: 0,
          ),
        ),
      ], budget: budget);
      expect(turns.last.content.length, lessThan(220));
    });

    test('the oldest turns go first when the history is too long', () {
      final turns = AgentProtocol.turnsFor([
        user('first ${'a' * 500}', 'u1'),
        assistant('a1', text: 'reply ${'b' * 500}'),
        user('second ${'c' * 500}', 'u2'),
        assistant('a2', text: 'reply ${'d' * 500}'),
        user('latest question', 'u3'),
      ],
          budget: const CodeBudget(
            observationChars: 100,
            historyChars: 1300,
            maxSteps: 8,
          ));

      expect(turns.last.content, 'latest question');
      expect(turns.first.role, 'user');
      expect(turns.any((t) => t.content.startsWith('first')), isFalse);
      expect(turns.length, lessThan(5));
    });
  });
}
