import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/agent/agent_prompt.dart';
import 'package:finn_ai/src/features/code/linux/linux_installer.dart';
import 'package:finn_ai/src/features/code/linux/linux_sandbox.dart';

void main() {
  test('the sandbox mounts only the project and the kernel views', () {
    final args = LinuxSandbox.arguments(
      rootfs: '/data/app/rootfs',
      projectRoot: '/data/app/ws/s1',
      command: 'ls',
    );
    final binds = [
      for (var i = 0; i < args.length - 1; i++)
        if (args[i] == '-b') args[i + 1],
    ];
    expect(binds, ['/dev', '/proc', '/sys', '/data/app/ws/s1:/workspace']);
    expect(args, containsAllInOrder(['-r', '/data/app/rootfs']));
    expect(args, containsAllInOrder(['-w', '/workspace']));
    // Nothing of the app's own environment reaches the command.
    expect(args, containsAllInOrder(['/usr/bin/env', '-i']));
    expect(args.sublist(args.length - 3), ['/bin/sh', '-c', 'ls']);
    expect(
      LinuxSandbox.guestEnvironment.keys,
      isNot(contains(anyOf('ANDROID_DATA', 'LD_LIBRARY_PATH', 'PROOT_LOADER'))),
    );
  });

  test('the image is pinned like the model', () {
    expect(LinuxImage.url, startsWith('https://dl-cdn.alpinelinux.org/'));
    expect(LinuxImage.url, contains(LinuxImage.version));
    expect(LinuxImage.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(LinuxImage.bytes, greaterThan(1000000));
  });

  test('installs and builds get ten minutes in Linux, not elsewhere', () {
    const short = Duration(seconds: 20);
    expect(WorkspaceActionRunner.timeoutFor('apk add python3', 20, linux: true),
        const Duration(minutes: 10));
    expect(WorkspaceActionRunner.timeoutFor('git clone x', 20, linux: true),
        const Duration(minutes: 10));
    expect(WorkspaceActionRunner.timeoutFor('ls', 20, linux: true), short);
    expect(WorkspaceActionRunner.timeoutFor('pip install x', 20, linux: false),
        short);
  });

  test('the Linux prompt names how to install, and stays short', () {
    final prompt = AgentPrompt.systemPrompt(
      env: CommandEnvironment.linux,
      allowShell: true,
      allowEdit: false,
    );
    expect(prompt, contains('apk add'));
    expect(prompt, contains('internet'));
    expect(prompt.length, lessThan(1500));
  });

  test('apt maps onto apk', () async {
    final temp = await Directory.systemTemp.createTemp('finn_apt');
    final bin = Directory('${temp.path}/bin')..createSync();
    File('${bin.path}/apk')
      ..writeAsStringSync('#!/bin/sh\necho "apk \$*"\n')
      ..createSync();
    await Process.run('chmod', ['755', '${bin.path}/apk']);
    final shim = File('${temp.path}/apt')
      ..writeAsStringSync(LinuxSetup.aptShim);
    Future<String> apt(List<String> args) async => (await Process.run(
          '/bin/sh',
          [shim.path, ...args],
          environment: {'PATH': '${bin.path}:/usr/bin:/bin'},
        ))
            .stdout
            .toString()
            .trim();
    expect(await apt(['install', '-y', 'python3', 'build-essential']),
        'apk add python3 build-base');
    expect(await apt(['update']), 'apk update');
    expect(await apt(['remove', 'git']), 'apk del git');
    await temp.delete(recursive: true);
  });

  test('sudo just runs the command', () async {
    final temp = await Directory.systemTemp.createTemp('finn_sudo');
    final shim = File('${temp.path}/sudo')
      ..writeAsStringSync(LinuxSetup.sudoShim);
    final result =
        await Process.run('/bin/sh', [shim.path, '-E', 'echo', 'root ok']);
    expect(result.stdout.toString().trim(), 'root ok');
    await temp.delete(recursive: true);
  });

  test('a download with the wrong checksum is refused', () async {
    final temp = await Directory.systemTemp.createTemp('finn_linux');
    final installer = LinuxInstaller(
      directoryProvider: () async => temp,
      clientFactory: () => MockClient.streaming((request, body) async =>
          http.StreamedResponse(
              Stream.value(List.filled(LinuxImage.bytes, 0)), 200)),
    );
    expect(await installer.install(), isFalse);
    expect(installer.state, LinuxInstallState.failed);
    expect(installer.error, LinuxInstallError.verification);
    expect(Directory('${temp.path}/code/linux/rootfs').existsSync(), isFalse);
    await temp.delete(recursive: true);
  });
}
