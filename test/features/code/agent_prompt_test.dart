import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/agent/agent_tools.dart';
import 'package:finn_ai/src/features/code/agent/agent_prompt.dart';
import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';

void main() {
  group('AgentPrompt.systemPrompt', () {
    test('stays within the 1500-character budget', () {
      for (final env in CommandEnvironment.values) {
        final prompt = AgentPrompt.systemPrompt(
          env: env,
          allowShell: env != CommandEnvironment.none,
          allowEdit: false,
        );
        expect(prompt.length, lessThanOrEqualTo(1500),
            reason: 'env=${env.name} length=${prompt.length}');
      }
    });

    test('names the file, read, list and answer actions', () {
      final prompt = AgentPrompt.systemPrompt(
        env: CommandEnvironment.none,
        allowShell: false,
        allowEdit: false,
      );
      expect(prompt, contains('```write'));
      expect(prompt, contains('```read'));
      expect(prompt, contains('```list'));
      expect(prompt, contains('```answer'));
    });

    test('shell action only appears when commands can run', () {
      final withShell = AgentPrompt.systemPrompt(
        env: CommandEnvironment.linux,
        allowShell: true,
        allowEdit: false,
      );
      expect(withShell, contains('```sh'));

      final withoutShell = AgentPrompt.systemPrompt(
        env: CommandEnvironment.none,
        allowShell: false,
        allowEdit: false,
      );
      expect(withoutShell, isNot(contains('```sh')));
    });

    test('edit only appears when edits are allowed', () {
      final withEdit = AgentPrompt.systemPrompt(
        env: CommandEnvironment.linux,
        allowShell: true,
        allowEdit: true,
      );
      expect(withEdit, contains('```edit'));

      final withoutEdit = AgentPrompt.systemPrompt(
        env: CommandEnvironment.linux,
        allowShell: true,
        allowEdit: false,
      );
      expect(withoutEdit, isNot(contains('```edit')));
    });

    test('environment line reflects where commands run', () {
      expect(
        AgentPrompt.systemPrompt(
                env: CommandEnvironment.linux,
                allowShell: true,
                allowEdit: false)
            .toLowerCase(),
        contains('alpine'),
      );
      expect(
        AgentPrompt.systemPrompt(
                env: CommandEnvironment.device,
                allowShell: true,
                allowEdit: false)
            .toLowerCase(),
        contains('no python'),
      );
      expect(
        AgentPrompt.systemPrompt(
                env: CommandEnvironment.none,
                allowShell: false,
                allowEdit: false)
            .toLowerCase(),
        contains('cannot run commands'),
      );
    });
  });

  group('AgentPrompt.exampleTurns', () {
    test('goes ask -> act -> observe -> answer, write first', () {
      final turns = AgentPrompt.exampleTurns(allowShell: true);
      expect(turns.first.role, 'user');
      expect(turns.last.role, 'assistant');
      // The closing turn is plain prose (the answer), not another action.
      expect(turns.last.content, isNot(contains('```')));
      // A write action appears early so the model copies the shape.
      expect(turns.any((t) => t.content.contains('```write')), isTrue);
    });

    test('includes a bash step only when shell is available', () {
      expect(
        AgentPrompt.exampleTurns(allowShell: true)
            .any((t) => t.content.contains('```sh')),
        isTrue,
      );
      expect(
        AgentPrompt.exampleTurns(allowShell: false)
            .any((t) => t.content.contains('```sh')),
        isFalse,
      );
    });

    test('every example action decodes to a call or an answer', () {
      final turns = AgentPrompt.exampleTurns(allowShell: true);
      for (final turn in turns.where((t) => t.role == 'assistant')) {
        final reply = AgentProtocol.decode(turn.content,
            allowShell: true, allowEdit: true);
        expect(reply.hasCall || reply.answer, isTrue,
            reason: 'example assistant turn did not decode: ${turn.content}');
      }
    });
  });

  group('AgentPrompt.observationFor', () {
    String obs(ToolResult r, AgentTool tool, {int? maxChars}) =>
        AgentPrompt.observationFor(r, tool: tool, maxChars: maxChars ?? 1600);

    test('write reports the path and byte count', () {
      final message = obs(
        const ToolResult(ok: true, path: 'a.txt', after: 'hi'),
        AgentTool.write,
      );
      expect(message, contains('Wrote a.txt'));
      expect(message, contains('2 characters'));
    });

    test('write that failed says it could not write and why', () {
      final message = obs(
        const ToolResult(ok: false, path: 'a.txt', text: 'disk full'),
        AgentTool.write,
      );
      expect(message, contains('Could not write a.txt'));
      expect(message, contains('disk full'));
    });

    test('read returns the file contents', () {
      final message = obs(
        const ToolResult(ok: true, path: 'd.txt', text: 'file contents'),
        AgentTool.read,
      );
      expect(message, contains('file contents'));
    });

    test('read of a missing file says it could not read', () {
      final message = obs(
        const ToolResult(ok: false, path: 'd.txt', text: 'No such file'),
        AgentTool.read,
      );
      expect(message, contains('Could not read d.txt'));
    });

    test('bash reports exit code and stdout', () {
      final message = obs(
        const ToolResult(ok: true, exitCode: 0, text: 'hello'),
        AgentTool.bash,
      );
      expect(message, contains('exit code 0'));
      expect(message, contains('hello'));
    });

    test('bash non-zero exit is reported as the result', () {
      final message = obs(
        const ToolResult(ok: false, exitCode: 1, text: 'boom'),
        AgentTool.bash,
      );
      expect(message, contains('exit code 1'));
      expect(message, contains('boom'));
    });

    test('bash timeout is called out', () {
      final message = obs(
        const ToolResult(ok: false, timedOut: true, text: 'partial'),
        AgentTool.bash,
      );
      expect(message.toLowerCase(), contains('timed out'));
    });

    test('denied command names the policy reason', () {
      final message = obs(
        const ToolResult(
          ok: false,
          denied: PolicyReason.outsideWorkspace,
          deniedDetail: '../x',
        ),
        AgentTool.bash,
      );
      expect(message.toLowerCase(), contains('outside the project'));
    });

    test('long command output is clipped head and tail', () {
      final message = obs(
        ToolResult(
          ok: true,
          exitCode: 0,
          text: List.filled(10000, 'x').join(),
        ),
        AgentTool.bash,
        maxChars: 200,
      );
      expect(message.length, lessThan(400));
      expect(message, contains('omitted'));
    });
  });
}
