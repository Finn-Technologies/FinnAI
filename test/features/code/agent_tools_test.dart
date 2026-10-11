import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/code/agent/agent_tools.dart';

void main() {
  group('AgentProtocol.decode', () {
    test('write block becomes a write call with its path and body', () {
      final reply = AgentProtocol.decode(
        '```write a.txt\nhi\n```',
        allowShell: true,
        allowEdit: true,
      );
      expect(reply.hasCall, isTrue);
      expect(reply.call!.tool, AgentTool.write);
      expect(reply.call!.path, 'a.txt');
      expect(reply.call!.content, 'hi');
    });

    test('file/create/save tags are aliases of write', () {
      for (final tag in ['file', 'create', 'save']) {
        final reply = AgentProtocol.decode(
          '```$tag notes.md\nbody\n```',
          allowShell: false,
          allowEdit: false,
        );
        expect(reply.hasCall, isTrue, reason: tag);
        expect(reply.call!.tool, AgentTool.write);
        expect(reply.call!.path, 'notes.md');
      }
    });

    test('read block becomes a read call', () {
      final reply = AgentProtocol.decode(
        '```read data.txt\n```',
        allowShell: false,
        allowEdit: false,
      );
      expect(reply.call!.tool, AgentTool.read);
      expect(reply.call!.path, 'data.txt');
    });

    test('list block, with an optional directory', () {
      expect(
        AgentProtocol.decode('```list\n```',
                allowShell: false, allowEdit: false)
            .call,
        isA<AgentCall>()
            .having((c) => c.tool, 'tool', AgentTool.list)
            .having((c) => c.path, 'path', ''),
      );
      final withDir = AgentProtocol.decode(
        '```list src\n```',
        allowShell: false,
        allowEdit: false,
      );
      expect(withDir.call!.path, 'src');
    });

    test('sh/bash/shell/console blocks become bash calls', () {
      for (final tag in ['sh', 'bash', 'shell', 'console']) {
        final reply = AgentProtocol.decode(
          '```$tag\nls -la\n```',
          allowShell: true,
          allowEdit: false,
        );
        expect(reply.call!.tool, AgentTool.bash, reason: tag);
        expect(reply.call!.command, 'ls -la');
      }
    });

    test('edit block becomes an edit call when edits are allowed', () {
      final reply = AgentProtocol.decode(
        '```edit hello.sh\n<<<<<<< SEARCH\necho a\n=======\necho b\n>>>>>>> REPLACE\n```',
        allowShell: true,
        allowEdit: true,
      );
      expect(reply.call!.tool, AgentTool.edit);
      expect(reply.call!.path, 'hello.sh');
      expect(reply.call!.content, contains('<<<<<<< SEARCH'));
    });

    test('answer block ends the request with its summary as prose', () {
      final reply = AgentProtocol.decode(
        '```answer\nDone.\n```',
        allowShell: true,
        allowEdit: true,
      );
      expect(reply.answer, isTrue);
      expect(reply.hasCall, isFalse);
      expect(reply.prose, 'Done.');
    });

    test('a plain prose reply with no action is an answer', () {
      final reply = AgentProtocol.decode(
        'All set. count.sh prints 1..5.',
        allowShell: true,
        allowEdit: true,
      );
      expect(reply.answer, isTrue);
      expect(reply.hasCall, isFalse);
      expect(reply.prose, 'All set. count.sh prints 1..5.');
    });

    test('a cut-off block emits no call and is flagged malformed', () {
      final reply = AgentProtocol.decode(
        '```write a.txt\nthis never closes',
        allowShell: true,
        allowEdit: true,
      );
      expect(reply.hasCall, isFalse);
      expect(reply.answer, isFalse);
      expect(reply.malformed, isTrue);
    });

    test('a write with no path is malformed', () {
      final reply = AgentProtocol.decode(
        '```write\nbody with no name\n```',
        allowShell: true,
        allowEdit: true,
      );
      expect(reply.hasCall, isFalse);
      expect(reply.malformed, isTrue);
    });

    test('an edit block when edits are off is malformed and nudges write', () {
      final reply = AgentProtocol.decode(
        '```edit a.txt\n<<<<<<< SEARCH\nx\n=======\ny\n>>>>>>> REPLACE\n```',
        allowShell: true,
        allowEdit: false,
      );
      expect(reply.hasCall, isFalse);
      expect(reply.malformed, isTrue);
      expect(reply.notice, contains('write'));
    });

    test('a shell block when shell is off is malformed', () {
      final reply = AgentProtocol.decode(
        '```sh\nls\n```',
        allowShell: false,
        allowEdit: false,
      );
      expect(reply.hasCall, isFalse);
      expect(reply.malformed, isTrue);
    });

    test('content with backticks parses inside a four-backtick fence', () {
      final reply = AgentProtocol.decode(
        '````write notes.md\nLine with ``` inline\n````',
        allowShell: true,
        allowEdit: true,
      );
      expect(reply.call!.tool, AgentTool.write);
      expect(reply.call!.content, 'Line with ``` inline');
    });

    test('file header spellings: path=, quotes, colon', () {
      final a = AgentProtocol.decode('```file path=hello.py\nx\n```',
          allowShell: false, allowEdit: false);
      expect(a.call!.path, 'hello.py');
      final b = AgentProtocol.decode('```file "hi.py"\nx\n```',
          allowShell: false, allowEdit: false);
      expect(b.call!.path, 'hi.py');
      final c = AgentProtocol.decode('```file: colon.py\nx\n```',
          allowShell: false, allowEdit: false);
      expect(c.call!.path, 'colon.py');
    });

    test('prose before the action is kept; text after is dropped', () {
      final reply = AgentProtocol.decode(
        'I will create it.\n```write a.txt\nhi\n```\nThis is a hallucinated result.',
        allowShell: true,
        allowEdit: true,
      );
      expect(reply.call!.tool, AgentTool.write);
      expect(reply.prose, 'I will create it.');
    });
  });
}
