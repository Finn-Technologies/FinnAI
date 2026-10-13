import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/code/agent/agent_tools.dart';
import 'package:finn_ai/src/features/code/agent/code_tool_runner.dart';
import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/sandbox/workspace.dart';

import 'code_fakes.dart';

void main() {
  late Directory temp;
  late CodeSessionStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('finn_code_runner_');
    store = CodeSessionStore(directoryProvider: () async => temp);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<CodeWorkspace> write(String path, String content) async {
    final ws = await store.workspaceOf('s');
    await ws.writeFile(path, content);
    return ws;
  }

  test('read returns the file contents', () async {
    await write('data.txt', 'hello world');
    final runner =
        WorkspaceCodeToolRunner(sessions: store, actions: FakeRunner());
    final result = await runner.run('s', const AgentCall.read('data.txt'));
    expect(result.ok, isTrue);
    expect(result.path, 'data.txt');
    expect(result.text, 'hello world');
  });

  test('read of a missing file is not ok', () async {
    final runner =
        WorkspaceCodeToolRunner(sessions: store, actions: FakeRunner());
    final result = await runner.run('s', const AgentCall.read('nope.txt'));
    expect(result.ok, isFalse);
  });

  test('list returns the entries', () async {
    await write('a.txt', 'a');
    await write('b.txt', 'b');
    final runner =
        WorkspaceCodeToolRunner(sessions: store, actions: FakeRunner());
    final result = await runner.run('s', const AgentCall.list(''));
    expect(result.ok, isTrue);
    expect(result.text, contains('a.txt'));
    expect(result.text, contains('b.txt'));
  });

  test('write maps to a writeFile action and carries the new content',
      () async {
    final fake = FakeRunner();
    final runner = WorkspaceCodeToolRunner(sessions: store, actions: fake);
    final result =
        await runner.run('s', const AgentCall.write('out.txt', 'hi\nthere'));
    expect(fake.ran.single.kind, CodeActionKind.writeFile);
    expect(fake.ran.single.path, 'out.txt');
    expect(result.ok, isTrue);
    expect(result.after, 'hi\nthere');
  });

  test('edit maps to an editFile action with the blocks', () async {
    final fake = FakeRunner(
      results: [
        CodeAction.edit('a.txt', 'x').copyWith(
          status: CodeActionStatus.done,
          after: 'changed',
        ),
      ],
    );
    final runner = WorkspaceCodeToolRunner(sessions: store, actions: fake);
    final result = await runner.run(
        's', const AgentCall.edit('a.txt', '<<<<<<< SEARCH\na\n=======\nb'));
    expect(fake.ran.single.kind, CodeActionKind.editFile);
    expect(result.after, 'changed');
  });

  test('a denied command keeps its policy reason', () async {
    final fake = FakeRunner(
      results: [
        const CodeAction.shell('cat ../x').copyWith(
          status: CodeActionStatus.denied,
          deniedReason: PolicyReason.outsideWorkspace,
          deniedDetail: '../x',
        ),
      ],
    );
    final runner = WorkspaceCodeToolRunner(sessions: store, actions: fake);
    final result = await runner.run('s', const AgentCall.bash('cat ../x'));
    expect(result.ok, isFalse);
    expect(result.denied, PolicyReason.outsideWorkspace);
  });

  test('bash where commands cannot run reports it without touching the shell',
      () async {
    final fake = FakeRunner(canRun: false);
    final runner = WorkspaceCodeToolRunner(sessions: store, actions: fake);
    final result = await runner.run('s', const AgentCall.bash('ls'));
    expect(result.ok, isFalse);
    expect(result.text.toLowerCase(), contains('cannot run'));
    expect(fake.ran, isEmpty);
  });
}
