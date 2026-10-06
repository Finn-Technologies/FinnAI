import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/code/agent/agent_protocol.dart';
import 'package:finn_ai/src/features/code/agent/code_agent.dart';
import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/providers/provider_errors.dart';
import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';

import 'code_fakes.dart';

void main() {
  late Directory temp;
  late CodeSessionStore sessions;
  late CodeSettingsStore settings;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('finn_code_agent_');
    sessions = CodeSessionStore(
      directoryProvider: () async => temp,
      saveDelay: const Duration(milliseconds: 1),
    );
    settings = CodeSettingsStore(directoryProvider: () async => temp);
  });

  tearDown(() async {
    await sessions.flush();
    sessions.dispose();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  CodeAgent agentFor(FakeGateway gateway, [FakeRunner? runner]) => CodeAgent(
        sessions: sessions,
        settings: settings,
        runner: runner ?? FakeRunner(),
        gatewayFactory: () async => gateway,
        streamUpdateInterval: const Duration(milliseconds: 1),
      );

  List<CodeMessage> messages() => sessions.active!.messages;

  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 400 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition was never met');
  }

  group('a plain answer', () {
    test('is stored under the user message and ends the request', () async {
      final gateway = FakeGateway(['Hello there.']);
      final agent = agentFor(gateway);

      await agent.send('  hi  ');

      expect(
          messages().map((m) => m.role), [CodeRole.user, CodeRole.assistant]);
      expect(messages().first.text, 'hi');
      expect(messages().last.text, 'Hello there.');
      expect(messages().last.modelLabel, 'Fake');
      expect(messages().last.failed, isFalse);
      expect(agent.busy, isFalse);
      expect(sessions.active!.title, 'hi');
    });

    test('sends the protocol as the system prompt', () async {
      final gateway = FakeGateway(['ok']);
      await agentFor(gateway).send('hi');

      final request = gateway.requests.single;
      expect(
        request.system,
        AgentProtocol.systemPrompt(shell: true, edits: true),
      );
      expect(request.turns.single, const CodeTurn.user('hi'));
      expect(request.conversationId, 'code-${sessions.active!.id}');
    });

    test('a blank message or a reply with no text does nothing / errors',
        () async {
      final agent = agentFor(FakeGateway(['']));
      await agent.send('   ');
      expect(sessions.sessions, isEmpty);

      await agent.send('hi');
      expect(messages().last.errorCode, CodeErrorCode.empty);
    });
  });

  group('attachments', () {
    test('are copied into the project and named in the request', () async {
      final source = File('${temp.path}/data.csv')
        ..writeAsStringSync('a,b\n1,2\n');
      final agent = agentFor(FakeGateway(['Got it.']));

      final failed = await agent.send('sum b', attachments: [source]);

      expect(failed, isEmpty);
      expect(messages().first.text, 'Attached: data.csv\n\nsum b');
      expect(sessions.active!.title, 'sum b');
      final workspace = await sessions.workspaceOf(sessions.active!.id);
      expect(await workspace.readFile('data.csv'), 'a,b\n1,2\n');
    });

    test('a file alone is a request, and a taken name is not overwritten',
        () async {
      final source = File('${temp.path}/notes.txt')..writeAsStringSync('new');
      final agent = agentFor(FakeGateway(['ok', 'ok']));
      await agent.send('start');
      final workspace = await sessions.workspaceOf(sessions.active!.id);
      await workspace.writeFile('notes.txt', 'old');

      await agent.send('', attachments: [source]);

      expect(messages()[2].text, 'Attached: notes (2).txt');
      expect(await workspace.readFile('notes.txt'), 'old');
      expect(await workspace.readFile('notes (2).txt'), 'new');
    });

    test('a file that cannot be read is reported, the rest still go', () async {
      final good = File('${temp.path}/ok.txt')..writeAsStringSync('ok');
      final agent = agentFor(FakeGateway(['ok']));

      final failed = await agent
          .send('look', attachments: [File('${temp.path}/missing.txt'), good]);

      expect(failed, ['missing.txt']);
      expect(messages().first.text, 'Attached: ok.txt\n\nlook');
    });
  });

  test('a small model is shown a worked example before the conversation',
      () async {
    final gateway = FakeGateway(
      ['Done.'],
      budget: CodeBudget.onDevice,
    );
    await agentFor(gateway).send('make a file');

    final turns = gateway.requests.single.turns;
    expect(turns.length, greaterThan(2));
    expect(turns.first.content, contains('hello.txt'));
    expect(turns.last.role, 'user');
    expect(turns.last.content, startsWith('make a file'));
    expect(
        turns.last.content, endsWith(AgentProtocol.taskReminder(shell: true)));
    for (var i = 1; i < turns.length; i++) {
      expect(turns[i].role, isNot(turns[i - 1].role));
    }
  });

  group('actions', () {
    test('a file write runs without asking and is shown to the model',
        () async {
      final gateway = FakeGateway([
        'I will create it.\n```file a.txt\nhi\n```',
        'Created a.txt.',
      ]);
      final runner = FakeRunner();
      final agent = agentFor(gateway, runner);

      await agent.send('make a.txt');

      expect(runner.ran.single.path, 'a.txt');
      final withAction = messages()[1];
      expect(withAction.text, 'I will create it.');
      expect(withAction.action!.status, CodeActionStatus.done);
      expect(messages().last.text, 'Created a.txt.');
      // The second request carries the result of the first action.
      expect(gateway.requests[1].turns.last.content,
          'Wrote a.txt (2 characters).');
      expect(gateway.requests[1].turns[1].role, 'assistant');
    });

    test('a command waits for a tap, then runs on approval', () async {
      final gateway = FakeGateway(['```sh\nls\n```', 'Done.']);
      final runner = FakeRunner();
      final agent = agentFor(gateway, runner);

      final request = agent.send('list');
      await until(() => agent.phase == CodeAgentPhase.awaitingApproval);

      expect(runner.ran, isEmpty);
      final pending = agent.pendingMessageId!;
      expect(messages().last.id, pending);
      expect(messages().last.action!.status, CodeActionStatus.proposed);

      agent.approve(pending);
      await request;

      expect(runner.ran.single.command, 'ls');
      expect(messages()[1].action!.status, CodeActionStatus.done);
      expect(messages().last.text, 'Done.');
      expect(
          gateway.requests[1].turns.last.content, 'Result (exit code 0):\nok');
    });

    test('skipping tells the model the user declined', () async {
      final gateway = FakeGateway(['```sh\nrm x\n```', 'Understood.']);
      final runner = FakeRunner();
      final agent = agentFor(gateway, runner);

      final request = agent.send('clean');
      await until(() => agent.phase == CodeAgentPhase.awaitingApproval);
      agent.skip(agent.pendingMessageId!);
      await request;

      expect(runner.ran, isEmpty);
      expect(messages()[1].action!.status, CodeActionStatus.skipped);
      expect(gateway.requests[1].turns.last.content, contains('chose not to'));
    });

    test('approving the wrong message does nothing', () async {
      final gateway = FakeGateway(['```sh\nls\n```', 'ok']);
      final agent = agentFor(gateway);
      final request = agent.send('list');
      await until(() => agent.phase == CodeAgentPhase.awaitingApproval);

      agent.approve('some-other-message');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(agent.phase, CodeAgentPhase.awaitingApproval);

      agent.skip(agent.pendingMessageId!);
      await request;
    });

    test('permission modes decide what asks', () async {
      Future<int> asks(CodePermissionMode mode, String reply) async {
        await settings.update((s) => s.copyWith(permissionMode: mode));
        sessions.clearActive();
        final agent = agentFor(FakeGateway([reply, 'done']));
        final request = agent.send('go');
        var asked = 0;
        for (var i = 0; i < 40; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          if (agent.phase == CodeAgentPhase.awaitingApproval) {
            asked = 1;
            agent.approve(agent.pendingMessageId!);
            break;
          }
        }
        await request;
        return asked;
      }

      const file = '```file a.txt\nx\n```';
      const shell = '```sh\nls\n```';
      expect(await asks(CodePermissionMode.askEveryTime, file), 1);
      expect(await asks(CodePermissionMode.acceptEdits, file), 0);
      expect(await asks(CodePermissionMode.acceptEdits, shell), 1);
      expect(await asks(CodePermissionMode.autoRun, shell), 0);
    });

    test('a refused command is explained and the model carries on', () async {
      await settings.update(
          (s) => s.copyWith(permissionMode: CodePermissionMode.autoRun));
      final gateway = FakeGateway(['```sh\ncat /etc/hosts\n```', 'I see.']);
      final runner = FakeRunner(results: [
        const CodeAction.shell('cat /etc/hosts').copyWith(
          status: CodeActionStatus.denied,
          deniedReason: PolicyReason.outsideWorkspace,
          deniedDetail: '/etc/hosts',
        ),
      ]);

      await agentFor(gateway, runner).send('read hosts');

      expect(messages()[1].action!.status, CodeActionStatus.denied);
      expect(gateway.requests[1].turns.last.content, contains('/etc/hosts'));
    });

    test('commands are not offered where the platform cannot run them',
        () async {
      final gateway = FakeGateway(['ok']);
      await agentFor(gateway, FakeRunner(canRun: false)).send('hi');
      expect(gateway.requests.single.system, isNot(contains('```sh')));
    });
  });

  group('the model talking past its action', () {
    test('reading stops at the closing fence and the rest is not kept',
        () async {
      await settings.update(
          (s) => s.copyWith(permissionMode: CodePermissionMode.autoRun));
      final gateway = FakeGateway([
        '```sh\nls\n```\nThe result was: a.txt b.txt c.txt, all good.',
        'Finished.',
      ]);

      await agentFor(gateway).send('list');

      expect(gateway.cancels, greaterThan(0));
      final first = messages()[1];
      expect(first.action!.command, 'ls');
      expect(first.text, isNot(contains('The result was')));
    });
  });

  group('an unusable action', () {
    test('is explained to the model, which then gets it right', () async {
      final gateway = FakeGateway([
        '```file\nHello\n```',
        '```file hello.txt\nHello\n```',
        'Created hello.txt.',
      ]);
      final runner = FakeRunner();

      await agentFor(gateway, runner).send('make hello.txt');

      expect(runner.ran.single.path, 'hello.txt');
      expect(gateway.requests[1].turns.last.content,
          AgentProtocol.malformedNotice);
      expect(messages().last.text, 'Created hello.txt.');
      // The first reply is recorded as a retried one, not as the answer.
      expect(messages()[1].errorCode, CodeErrorCode.malformed);
    });

    test('twice in a row ends the request instead of looping', () async {
      final gateway = FakeGateway(['```file\nHello\n```']);
      final runner = FakeRunner();

      await agentFor(gateway, runner).send('make hello.txt');

      expect(runner.ran, isEmpty);
      expect(gateway.requests.length, 2);
      expect(
        messages().where((m) => m.errorCode == CodeErrorCode.malformed).length,
        2,
      );
    });
  });

  group('a model that only thinks', () {
    const spam = '<think>\n\n</think>\n\n<think>\n\n</think>\n\n'
        '<think>\n\n</think>\n\n<think>\n\n</think>\n\n';

    test('after finished work the request ends quietly, with no error',
        () async {
      final gateway = FakeGateway(['```file a.txt\nhi\n```', spam]);

      await agentFor(gateway).send('make a.txt');

      expect(
          messages().map((m) => m.role), [CodeRole.user, CodeRole.assistant]);
      expect(messages().last.action!.status, CodeActionStatus.done);
      expect(messages().any((m) => m.failed), isFalse);
      expect(agentFor(gateway).busy, isFalse);
    });

    test('with no work done it is reported as an empty reply', () async {
      await agentFor(FakeGateway([spam])).send('hi');
      expect(messages().last.errorCode, CodeErrorCode.empty);
      expect(messages().last.text, isEmpty);
    });

    test('reading stops once the rest is only tags', () async {
      final gateway = FakeGateway([spam * 20]);
      await agentFor(gateway).send('hi');
      expect(gateway.cancels, greaterThan(0));
    });

    test('tags never reach the transcript', () async {
      await agentFor(FakeGateway(['<think>\n\n</think>\n\nHello there.']))
          .send('hi');
      expect(messages().last.text, 'Hello there.');
    });
  });

  group('limits', () {
    test('the step limit ends a request that never finishes', () async {
      await settings.update((s) => s.copyWith(
            permissionMode: CodePermissionMode.autoRun,
            maxSteps: () => 3,
          ));
      var n = 0;
      final gateway = FakeGateway([
        for (var i = 0; i < 10; i++) '```file f$i.txt\n${n++}\n```',
      ]);
      final runner = FakeRunner();

      await agentFor(gateway, runner).send('go');

      expect(runner.ran.length, 3);
      expect(messages().last.errorCode, CodeErrorCode.stepLimit);
      expect(gateway.requests.length, 3);
    });

    test('the same action three times running is a loop', () async {
      await settings.update(
          (s) => s.copyWith(permissionMode: CodePermissionMode.autoRun));
      final gateway = FakeGateway(['```file a.txt\nx\n```']);
      final runner = FakeRunner();

      await agentFor(gateway, runner).send('go');

      expect(runner.ran.length, CodeAgent.repeatLimit);
      expect(messages().last.errorCode, CodeErrorCode.repeating);
    });

    test('a command that worked, run again with the same result, ends quietly',
        () async {
      await settings.update(
          (s) => s.copyWith(permissionMode: CodePermissionMode.autoRun));
      final gateway = FakeGateway(['```sh\nls\n```']);
      final runner = FakeRunner();

      await agentFor(gateway, runner).send('go');

      expect(runner.ran.length, 2);
      expect(messages().last.errorCode, isNull);
    });

    test('different actions are not a loop', () async {
      await settings.update(
          (s) => s.copyWith(permissionMode: CodePermissionMode.autoRun));
      final gateway = FakeGateway([
        '```sh\nls\n```',
        '```sh\npwd\n```',
        '```sh\nls\n```',
        'Done.',
      ]);
      await agentFor(gateway).send('go');
      expect(messages().last.text, 'Done.');
      expect(messages().last.failed, isFalse);
    });

    test('a reply cut off inside its action never runs, two stop the request',
        () async {
      final gateway = FakeGateway(['Working.\n```file big.txt\nhalf a fi']);
      final runner = FakeRunner();

      await agentFor(gateway, runner).send('go');

      expect(runner.ran, isEmpty);
      final cut = messages().where((m) => m.errorCode == CodeErrorCode.cutOff);
      expect(cut.length, 2);
      // The second request was told the first was cut off.
      expect(
          gateway.requests[1].turns.last.content, AgentProtocol.cutOffNotice);
    });

    test('resume continues after a step limit with a fresh budget', () async {
      await settings.update((s) => s.copyWith(
            permissionMode: CodePermissionMode.autoRun,
            maxSteps: () => 1,
          ));
      final gateway = FakeGateway(['```file a.txt\n1\n```', 'All done.']);
      final agent = agentFor(gateway);

      await agent.send('go');
      expect(messages().last.errorCode, CodeErrorCode.stepLimit);

      await agent.resume();
      expect(messages().last.text, 'All done.');
    });

    test('resume does nothing when the last message is an answer', () async {
      final gateway = FakeGateway(['Answer.']);
      final agent = agentFor(gateway);
      await agent.send('hi');
      await agent.resume();
      expect(gateway.requests.length, 1);
    });
  });

  group('failures', () {
    test('a provider error is recorded with its kind and detail', () async {
      final gateway = FakeGateway([
        const ProviderException(ProviderFailure.auth,
            statusCode: 401, detail: 'bad key'),
      ]);
      final agent = agentFor(gateway);

      await agent.send('hi');

      expect(messages().last.errorCode, 'provider:auth');
      expect(messages().last.errorDetail, 'bad key');
      expect(agent.busy, isFalse);
    });

    test('a provider error keeps what was already streamed', () async {
      final controller = StreamController<String>();
      final gateway = FakeGateway([controller.stream]);
      final agent = agentFor(gateway);

      final request = agent.send('hi');
      controller.add('Partial ans');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.addError(const ProviderException(ProviderFailure.network));
      await request;

      expect(messages().last.text, 'Partial ans');
      expect(messages().last.errorCode, 'provider:network');
      await controller.close();
    });

    test('any other error becomes an engine error', () async {
      final agent = agentFor(FakeGateway([StateError('boom')]));
      await agent.send('hi');
      expect(messages().last.errorCode, CodeErrorCode.engine);
      expect(agent.busy, isFalse);
    });

    test('a failing gateway factory is reported, not thrown', () async {
      final agent = CodeAgent(
        sessions: sessions,
        settings: settings,
        runner: FakeRunner(),
        gatewayFactory: () async => throw StateError('no model'),
      );
      await agent.send('hi');
      expect(messages().last.errorCode, CodeErrorCode.engine);
      expect(agent.busy, isFalse);
    });
  });

  group('stop', () {
    test('while the model is writing: partial text stays, agent is free',
        () async {
      final controller = StreamController<String>();
      final gateway = FakeGateway([controller.stream]);
      final agent = agentFor(gateway);

      final request = agent.send('hi');
      await until(() => agent.phase == CodeAgentPhase.thinking);
      controller.add('Working on');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await agent.stop();
      await request;

      expect(agent.busy, isFalse);
      expect(messages().last.text, 'Working on');
      expect(gateway.cancels, 1);
      await controller.close();
    });

    test('before anything was written: the empty reply is removed', () async {
      final controller = StreamController<String>();
      final agent = agentFor(FakeGateway([controller.stream]));

      final request = agent.send('hi');
      await until(() => agent.phase == CodeAgentPhase.thinking);
      await agent.stop();
      await request;

      expect(messages().map((m) => m.role), [CodeRole.user]);
      expect(agent.busy, isFalse);
      await controller.close();
    });

    test('while a command waits for a tap: it is skipped and never runs',
        () async {
      final runner = FakeRunner();
      final agent = agentFor(FakeGateway(['```sh\nrm -rf x\n```']), runner);

      final request = agent.send('go');
      await until(() => agent.phase == CodeAgentPhase.awaitingApproval);
      await agent.stop();
      await request;

      expect(runner.ran, isEmpty);
      expect(messages().last.action!.status, CodeActionStatus.skipped);
      expect(agent.busy, isFalse);
    });

    test('stopping when idle is harmless, and the agent can be used again',
        () async {
      final gateway = FakeGateway(['one', 'two']);
      final agent = agentFor(gateway);
      await agent.stop();
      await agent.send('a');
      await agent.stop();
      await agent.send('b');
      expect(messages().last.text, 'two');
    });

    test('a second message while busy is ignored', () async {
      final controller = StreamController<String>();
      final gateway = FakeGateway([controller.stream]);
      final agent = agentFor(gateway);

      final first = agent.send('one');
      await until(() => agent.phase == CodeAgentPhase.thinking);
      await agent.send('two');
      expect(messages().where((m) => m.isUser).length, 1);

      controller.add('done');
      await controller.close();
      await first;
    });
  });

  test('listeners hear every phase change', () async {
    final agent = agentFor(FakeGateway(['hello']));
    final phases = <CodeAgentPhase>[];
    agent.addListener(() => phases.add(agent.phase));

    await agent.send('hi');

    expect(phases.first, CodeAgentPhase.thinking);
    expect(phases.last, CodeAgentPhase.idle);
  });
}
