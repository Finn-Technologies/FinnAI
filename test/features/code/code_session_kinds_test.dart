import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/code/sessions/code_session.dart';

void main() {
  test('readFile action round-trips its path and result text', () {
    const action = CodeAction(
      kind: CodeActionKind.readFile,
      path: 'data.txt',
      output: 'line one\nline two',
    );
    final restored = CodeAction.fromJson(action.toJson())!;
    expect(restored.kind, CodeActionKind.readFile);
    expect(restored.path, 'data.txt');
    expect(restored.output, 'line one\nline two');
  });

  test('listDir action round-trips its listing', () {
    const action = CodeAction(
      kind: CodeActionKind.listDir,
      output: 'a.txt\nb.txt',
    );
    final restored = CodeAction.fromJson(action.toJson())!;
    expect(restored.kind, CodeActionKind.listDir);
    expect(restored.output, 'a.txt\nb.txt');
  });

  test('older shell/write/edit actions still load (backward compatible)', () {
    final shell =
        CodeAction.fromJson(const CodeAction.shell('ls -la').toJson())!;
    expect(shell.kind, CodeActionKind.shell);
    expect(shell.command, 'ls -la');

    final write = CodeAction.fromJson(
      const CodeAction.write('a.txt', 'hi').toJson(),
    )!;
    expect(write.kind, CodeActionKind.writeFile);
    expect(write.path, 'a.txt');
  });

  test('an action left waiting for a tap loads as skipped, new kinds too', () {
    const read = CodeAction(
      kind: CodeActionKind.readFile,
      status: CodeActionStatus.running,
      path: 'a.txt',
    );
    final restored = CodeAction.fromJson(read.toJson())!;
    expect(restored.status, CodeActionStatus.skipped);
  });

  test('a whole session with a readFile action round-trips', () {
    final session = CodeSession(
      id: 's1',
      title: 't',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      messages: [
        CodeMessage(
          id: 'u1',
          role: CodeRole.user,
          createdAt: DateTime(2026),
          text: 'read data.txt',
        ),
        CodeMessage(
          id: 'a1',
          role: CodeRole.assistant,
          createdAt: DateTime(2026),
          text: 'Here it is:',
          action: const CodeAction(
            kind: CodeActionKind.readFile,
            status: CodeActionStatus.done,
            path: 'data.txt',
            output: 'the file',
          ),
        ),
      ],
    );
    final restored = CodeSession.fromJson(jsonDecode(jsonEncode(
      session.toJson(),
    )))!;
    expect(restored.messages.length, 2);
    expect(restored.messages[1].action!.kind, CodeActionKind.readFile);
    expect(restored.messages[1].action!.output, 'the file');
  });
}
