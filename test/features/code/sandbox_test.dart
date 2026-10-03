import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';
import 'package:finn_ai/src/features/code/sandbox/shell_sandbox.dart';
import 'package:finn_ai/src/features/code/sandbox/workspace.dart';

void main() {
  late Directory temp;
  late CodeWorkspace workspace;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('finn_code_ws_');
    // Resolve /var -> /private/var on macOS so path comparisons are exact.
    workspace = CodeWorkspace(
      Directory('${await temp.resolveSymbolicLinks()}/project'),
    );
    await workspace.ensureCreated();
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('CodeWorkspace.normalize', () {
    test('keeps ordinary relative paths', () {
      expect(CodeWorkspace.normalize('a/b.txt'), 'a/b.txt');
      expect(CodeWorkspace.normalize('./a//b/./c.py'), 'a/b/c.py');
      expect(CodeWorkspace.normalize('a/../b.txt'), 'b.txt');
    });

    test('refuses anything that leaves the folder', () {
      for (final bad in [
        '/etc/passwd',
        '../x',
        'a/../../x',
        '~/x',
        r'a\b',
        '',
        '   ',
        '.',
        '.tmp/x',
        'a\u0000b',
      ]) {
        expect(
          () => CodeWorkspace.normalize(bad),
          throwsA(isA<WorkspaceEscape>()),
          reason: bad,
        );
      }
    });
  });

  group('CodeWorkspace files', () {
    test('writes, reads, lists and deletes', () async {
      await workspace.writeFile('src/hello.py', 'print("hi")\n');
      await workspace.writeFile('README.md', '# x');

      expect(await workspace.readFile('src/hello.py'), 'print("hi")\n');
      final root = await workspace.list();
      expect(root.map((e) => e.path), ['src', 'README.md']);
      expect(root.first.isDirectory, isTrue);
      expect(await workspace.allFiles(), ['src/hello.py', 'README.md']);

      await workspace.delete('src');
      expect((await workspace.list()).map((e) => e.path), ['README.md']);
    });

    test('hides the scratch folder the shell uses', () async {
      await File('${workspace.root.path}/.tmp/x').writeAsString('1');
      expect(await workspace.list(), isEmpty);
    });

    test('refuses a file that is too large', () async {
      expect(
        () => workspace.writeFile(
          'big.txt',
          'x' * (CodeWorkspace.maxFileBytes + 1),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('refuses to write through a link that points outside', () async {
      final outside = Directory('${temp.path}/outside')..createSync();
      Link('${workspace.root.path}/out').createSync(outside.path);

      await expectLater(
        workspace.writeFile('out/stolen.txt', 'x'),
        throwsA(isA<WorkspaceEscape>()),
      );
      expect(File('${outside.path}/stolen.txt').existsSync(), isFalse);
      await expectLater(
        workspace.list(directory: 'out'),
        throwsA(isA<WorkspaceEscape>()),
      );
    });

    test('measures and clears the folder', () async {
      await workspace.writeFile('a.txt', '12345');
      expect(await workspace.sizeBytes(), 5);
      await workspace.deleteAll();
      expect(workspace.root.existsSync(), isFalse);
    });
  });

  group('CommandPolicy', () {
    const policy = CommandPolicy();
    PolicyVerdict check(String command) =>
        policy.check(command, workspaceRoot: '/data/ws');

    test('allows everyday project commands', () {
      for (final ok in [
        'ls -la',
        'cat src/main.py | grep def',
        'mkdir -p a/b && echo hi > a/b/c.txt',
        'sed -i s/a/b/ notes.txt',
        'find . -name "*.dart" | wc -l',
        'cat /data/ws/notes.txt',
        'echo done > /dev/null',
        '/system/bin/ls',
        'FOO=1 ls',
        'for f in *.txt; do cat "\$f"; done',
      ]) {
        expect(check(ok).allowed, isTrue, reason: ok);
      }
    });

    test('blocks programs that act on the device', () {
      for (final bad in [
        'su -c id',
        'rm x; reboot',
        'am start -a android.intent.action.VIEW',
        'pm uninstall com.x',
        'kill -9 -1',
        'ls | xargs kill',
        'echo \$(settings put global x 1)',
        'ln -s /data x',
        'env FOO=1 reboot',
        'eval "\$X"',
        'true && sudo ls',
      ]) {
        final verdict = check(bad);
        expect(verdict.allowed, isFalse, reason: bad);
        expect(verdict.reason, PolicyReason.blockedProgram, reason: bad);
      }
    });

    test('blocks the network unless it is switched on', () {
      expect(check('curl https://example.com').reason, PolicyReason.network);
      expect(check('ls; wget http://x').reason, PolicyReason.network);
      expect(
        const CommandPolicy(allowNetwork: true)
            .check('curl https://example.com')
            .allowed,
        isTrue,
      );
    });

    test('blocks paths outside the project folder', () {
      for (final bad in [
        'cat /etc/passwd',
        'rm -rf /',
        'cd / && ls',
        'echo x>/data/data/com.abhiflex.finnai/x',
        'cat ~/x',
        'ls /sdcard',
        'cat /data/wsx/other',
      ]) {
        expect(check(bad).reason, PolicyReason.outsideWorkspace, reason: bad);
      }
    });

    test('blocks parent traversal', () {
      expect(check('cat ../secret').reason, PolicyReason.parentPath);
      expect(check('cd ..; ls').reason, PolicyReason.parentPath);
      expect(check('ls a/../../b').reason, PolicyReason.parentPath);
    });

    test('rejects empty, huge and fork-bomb input', () {
      expect(check('   ').reason, PolicyReason.empty);
      expect(check('a' * 5000).reason, PolicyReason.tooLong);
      expect(check(':(){ :|:& };:').reason, PolicyReason.obfuscated);
    });
  });

  group('ShellSandbox', () {
    ShellSandbox sandbox({
      Duration timeout = const Duration(seconds: 10),
      int maxOutputBytes = 32 * 1024,
      CommandPolicy policy = const CommandPolicy(),
    }) =>
        ShellSandbox(
          workspace: workspace,
          timeout: timeout,
          maxOutputBytes: maxOutputBytes,
          policy: policy,
        );

    test('runs in the project folder with HOME set to it', () async {
      final result = await sandbox().run('pwd; echo "\$HOME"');

      expect(result.ok, isTrue);
      final lines = result.output.trim().split('\n');
      expect(lines, [workspace.root.path, workspace.root.path]);
    });

    test('sees only the sandbox environment', () async {
      final result = await sandbox().run('env');
      final names = result.output
          .trim()
          .split('\n')
          .map((line) => line.split('=').first)
          .toSet();

      expect(names, containsAll(['HOME', 'PATH', 'TMPDIR']));
      expect(names, isNot(contains('USER')));
      expect(names, isNot(contains('SSH_AUTH_SOCK')));
    });

    test('returns output, exit code and merges stderr', () async {
      final ok = await sandbox().run('echo out; echo err >&2');
      expect(ok.exitCode, 0);
      expect(ok.output, contains('out'));
      expect(ok.output, contains('err'));

      final failed = await sandbox().run('echo bad; exit 3');
      expect(failed.exitCode, 3);
      expect(failed.ok, isFalse);
    });

    test('files written by a command are in the workspace', () async {
      await sandbox().run('echo hello > greeting.txt');
      expect(await workspace.readFile('greeting.txt'), 'hello\n');
    });

    test('kills a command that runs too long', () async {
      final result = await sandbox(timeout: const Duration(milliseconds: 400))
          .run('sleep 5');

      expect(result.timedOut, isTrue);
      expect(result.exitCode, 124);
      expect(result.ok, isFalse);
      expect(result.duration, lessThan(const Duration(seconds: 4)));
    });

    test('caps what comes back', () async {
      final result = await sandbox(maxOutputBytes: 100).run(
          'i=0; while [ \$i -lt 500 ]; do echo line-\$i; i=\$((i+1)); done');

      expect(result.truncated, isTrue);
      expect(result.output.length, lessThanOrEqualTo(100));
      expect(result.output, startsWith('line-0'));
    });

    test('does not hang on a command that reads input', () async {
      final result = await sandbox().run('cat');
      expect(result.exitCode, 0);
      expect(result.output, isEmpty);
    });

    test('refuses a denied command without starting a process', () async {
      final result = await sandbox().run('cat /etc/hosts');

      expect(result.denied, PolicyReason.outsideWorkspace);
      expect(result.deniedDetail, '/etc/hosts');
      expect(result.output, isEmpty);
      expect(result.ok, isFalse);
    });
  });
}
