import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/agent/agent_protocol.dart';
import 'package:finn_ai/src/features/code/agent/edit_blocks.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';

const _edit = '<<<<<<< SEARCH\n'
    'echo hello\n'
    '=======\n'
    'echo hello world\n'
    '>>>>>>> REPLACE';

void main() {
  group('EditBlocks', () {
    test('applies a block, and an empty search appends', () {
      final pairs = EditBlocks.parse(_edit)!;
      expect(EditBlocks.apply('#!/bin/sh\necho hello\n', pairs),
          '#!/bin/sh\necho hello world\n');
      expect(
        EditBlocks.apply('a\n',
            EditBlocks.parse('<<<<<<< SEARCH\n=======\nb\n>>>>>>> REPLACE')!),
        'a\nb\n',
      );
    });

    test('tolerates trailing spaces, refuses text that is not there', () {
      final pairs = EditBlocks.parse(_edit)!;
      final spaced = EditBlocks.parse(
          '<<<<<<< SEARCH\necho hello  \n=======\necho hi\n>>>>>>> REPLACE')!;
      expect(EditBlocks.apply('echo hello\n', spaced), 'echo hi\n');
      expect(() => EditBlocks.apply('echo bye\n', pairs),
          throwsA(isA<EditMismatch>()));
    });

    test('an unfinished block is no edit at all', () {
      expect(EditBlocks.parse('<<<<<<< SEARCH\nx\n=======\ny'), isNull);
      expect(EditBlocks.parse('just text'), isNull);
    });

    test('the protocol reads an edit block as an edit action', () {
      final reply = AgentProtocol.parse('```edit run.sh\n$_edit\n```');
      expect(reply.action!.isEdit, isTrue);
      expect(reply.action!.path, 'run.sh');
    });
  });

  group('runner', () {
    late Directory temp;
    late CodeSessionStore sessions;
    late WorkspaceActionRunner runner;
    late String id;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('finn_edit');
      sessions = CodeSessionStore(directoryProvider: () async => temp);
      runner = WorkspaceActionRunner(
        sessions: sessions,
        settings: CodeSettingsStore(directoryProvider: () async => temp),
        shellSupported: false,
      );
      id = sessions.create().id;
    });

    tearDown(() async {
      sessions.dispose();
      await temp.delete(recursive: true);
    });

    test('a write records what the file was before it', () async {
      final first =
          await runner.run(id, const CodeAction.write('a.sh', 'echo hello\n'));
      expect(first.previous, isNull);
      final second =
          await runner.run(id, const CodeAction.write('a.sh', 'x\n'));
      expect(second.previous, 'echo hello\n');
      expect(AgentProtocol.observation(second, maxChars: 700),
          contains('To run it: sh a.sh'));
    });

    test('rewriting a file with the same text says nothing changed', () async {
      await runner.run(id, const CodeAction.write('a.txt', 'same'));
      final again =
          await runner.run(id, const CodeAction.write('a.txt', 'same'));
      expect(AgentProtocol.observation(again, maxChars: 700),
          contains('Nothing changed'));
    });

    test('an edit changes only its part and keeps both sides', () async {
      await runner.run(
          id, const CodeAction.write('run.sh', '#!/bin/sh\necho hello\n'));
      final edit = await runner.run(id, const CodeAction.edit('run.sh', _edit));
      expect(edit.status, CodeActionStatus.done);
      expect(edit.previous, '#!/bin/sh\necho hello\n');
      expect(edit.after, '#!/bin/sh\necho hello world\n');
      final workspace = await sessions.workspaceOf(id);
      expect(await workspace.readFile('run.sh'), edit.after);
    });

    test('an edit whose search is missing fails and leaves the file', () async {
      await runner.run(id, const CodeAction.write('run.sh', 'echo bye\n'));
      final edit = await runner.run(id, const CodeAction.edit('run.sh', _edit));
      expect(edit.status, CodeActionStatus.failed);
      expect(edit.output, contains('echo hello'));
      final workspace = await sessions.workspaceOf(id);
      expect(await workspace.readFile('run.sh'), 'echo bye\n');
    });
  });
}
