import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/code/agent/agent_tools.dart';
import 'package:finn_ai/src/features/code/agent/code_agent.dart';
import 'package:finn_ai/src/features/code/agent/code_tool_runner.dart';
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

  WorkspaceCodeToolRunner toolRunner(FakeRunner actions) =>
      WorkspaceCodeToolRunner(sessions: sessions, actions: actions);

  CodeAgent agentFor(FakeGateway gateway, [FakeRunner? actions]) => CodeAgent(
        sessions: sessions,
        settings: settings,
        runner: toolRunner(actions ?? FakeRunner()),
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

  String? errorCode() => messages()
      .map((m) => m.errorCode)
      .whereType<String>()
      .firstOrNull;

  test('a plain answer is stored and ends the request', () async {
    final agent = agentFor(FakeGateway(['All set.']));
    await agent.send('hi');
    expect(messages().last.text, 'All set.');
    expect(messages().last.action, isNull);
    expect(agent.busy, isFalse);
    expect(errorCode(), isNull);
  });

  test('create then run then answer', () async {
    final actions = FakeRunner();
    final gateway = FakeGateway([
      '```write count.sh\necho hello\n```',
      '```answer\nDone.\n```',
    ]);
    final agent = agentFor(gateway, actions);

    await agent.send('create count.sh');

    final actionsWritten = actions.ran.where((a) => !a.isShell).toList();
    expect(actionsWritten.single.kind, CodeActionKind.writeFile);
    expect(actionsWritten.single.path, 'count.sh');
    expect(messages().last.text, 'Done.');
    expect(agent.busy, isFalse);
  });

  test('read observation reaches the model on the next step', () async {
    final session = sessions.create();
    final ws = await sessions.workspaceOf(session.id);
    await ws.writeFile('data.txt', 'x=1\ny=2');

    final gateway = FakeGateway([
      '```read data.txt\n```',
      '```write sum.txt\n3\n```',
      '```answer\nWrote sum.txt.\n```',
    ]);
    final agent = agentFor(gateway);

    await agent.send('sum the numbers');

    expect(gateway.requests.length, greaterThanOrEqualTo(2));
    final second = gateway.requests[1].turns.map((t) => t.content).join('\n');
    expect(second, contains('x=1'));
    expect(second, contains('y=2'));
  });

  test('a malformed action is repaired on the next step', () async {
    final gateway = FakeGateway([
      '```write\nbody with no name\n```',
      '```write a.txt\nhi\n```',
      '```answer\nDone.\n```',
    ]);
    final agent = agentFor(gateway);
    await agent.send('create a.txt');

    expect(gateway.requests.length, greaterThanOrEqualTo(2));
    final second = gateway.requests[1].turns.map((t) => t.content).join('\n');
    expect(second.toLowerCase(), contains('not usable'));
    expect(messages().last.text, 'Done.');
    expect(agent.busy, isFalse);
  });

  test('two consecutive malformed replies end the request', () async {
    final gateway = FakeGateway([
      '```write\nx\n```',
      '```write\ny\n```',
      '```write good.txt\nz\n```',
    ]);
    final agent = agentFor(gateway);
    await agent.send('create files');

    await until(() => !agent.busy);
    expect(gateway.requests.length, 2);
    expect(errorCode(), CodeErrorCode.malformed);
  });

  test('the same action three times ends as a repeat', () async {
    final actions = FakeRunner();
    final gateway = FakeGateway([
      '```write a.txt\nx\n```',
      '```write a.txt\nx\n```',
      '```write a.txt\nx\n```',
      '```answer\nDone.\n```',
    ]);
    final agent = agentFor(gateway, actions);
    await agent.send('write a.txt');
    await until(() => !agent.busy);
    expect(errorCode(), CodeErrorCode.repeating);
  });

  test('running out of steps ends as a step limit', () async {
    final actions = FakeRunner();
    final gateway = FakeGateway([
      for (var i = 0; i < 8; i++) '```write f$i.txt\n$i\n```',
    ]);
    final agent = agentFor(gateway, actions);
    await agent.send('write many');
    await until(() => !agent.busy);
    expect(errorCode(), CodeErrorCode.stepLimit);
  });

  test('a command waits for a tap, then runs on approve', () async {
    final actions = FakeRunner();
    final gateway = FakeGateway([
      '```sh\nls -la\n```',
      '```answer\nListed.\n```',
    ]);
    final agent = agentFor(gateway, actions);

    final future = agent.send('list files');
    await until(() => agent.phase == CodeAgentPhase.awaitingApproval);
    expect(agent.runningSessionId, isNotNull);
    agent.approve(agent.pendingMessageId!);
    await future;

    expect(actions.ran.where((a) => a.isShell).single.command, 'ls -la');
    expect(messages().last.text, 'Listed.');
    expect(agent.busy, isFalse);
  });

  test('skip records the action as skipped', () async {
    final actions = FakeRunner();
    final gateway = FakeGateway([
      '```sh\nrm -rf x\n```',
      '```answer\nOK, skipped.\n```',
    ]);
    final agent = agentFor(gateway, actions);

    final future = agent.send('remove x');
    await until(() => agent.phase == CodeAgentPhase.awaitingApproval);
    agent.skip(agent.pendingMessageId!);
    await future;

    expect(actions.ran.where((a) => a.isShell), isEmpty);
    final shell = messages().where((m) => m.action?.isShell ?? false).single;
    expect(shell.action!.status, CodeActionStatus.skipped);
  });

  test('allow in session runs a repeat command without asking again',
      () async {
    final actions = FakeRunner();
    final gateway = FakeGateway([
      '```sh\nls\n```',
      '```sh\nls\n```',
      '```answer\nDone.\n```',
    ]);
    final agent = agentFor(gateway, actions);

    final future = agent.send('list twice');
    await until(() => agent.phase == CodeAgentPhase.awaitingApproval);
    agent.approveForSession(agent.pendingMessageId!);
    await until(() => !agent.busy);
    await future;

    expect(actions.ran.where((a) => a.isShell).length, 2);
  });

  test('stop during the approval wait ends the request', () async {
    final actions = FakeRunner();
    final gateway = FakeGateway([
      '```sh\nsleep 999\n```',
      '```answer\nDone.\n```',
    ]);
    final agent = agentFor(gateway, actions);

    final future = agent.send('sleep');
    await until(() => agent.phase == CodeAgentPhase.awaitingApproval);
    await agent.stop();
    await future;

    expect(agent.busy, isFalse);
    expect(actions.ran.where((a) => a.isShell), isEmpty);
  });

  test('decode routes an edit call only when edits are allowed', () {
    final allowed = AgentProtocol.decode(
      '```edit a.txt\n<<<<<<< SEARCH\na\n=======\nb\n>>>>>>> REPLACE\n```',
      allowShell: true,
      allowEdit: true,
    );
    expect(allowed.call!.tool, AgentTool.edit);
    expect(allowed.call!.path, 'a.txt');

    final off = AgentProtocol.decode(
      '```edit a.txt\n<<<<<<< SEARCH\na\n=======\nb\n>>>>>>> REPLACE\n```',
      allowShell: true,
      allowEdit: false,
    );
    expect(off.hasCall, isFalse);
    expect(off.malformed, isTrue);
  });
}
