import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/agent/agent_protocol.dart';
import 'package:finn_ai/src/features/code/container/container_host.dart';
import 'package:finn_ai/src/features/code/container/container_image.dart';
import 'package:finn_ai/src/features/code/container/container_installer.dart';
import 'package:finn_ai/src/features/code/container/container_protocol.dart';
import 'package:finn_ai/src/features/code/container/container_shell.dart';
import 'package:finn_ai/src/features/code/container/workspace_sync.dart';
import 'package:finn_ai/src/features/code/sandbox/workspace.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';

/// Serial bytes as the page relays them: one code unit per byte.
String serial(String text) => latin1.decode(utf8.encode(text));

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('finn_container_');
    temp = Directory(await temp.resolveSymbolicLinks());
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('SerialCapture', () {
    test('reads output between the markers and the exit code', () {
      final capture = SerialCapture('n1', maxOutputBytes: 1024)
        ..add('sh /mnt/.finn/run.sh n1\r\n')
        ..add('\r\n<<FINN:n1:B>>\r\nhello\r\nwor')
        ..add('ld\r\n\r\n<<FINN:n1:E:3>>\r\n')
        ..scan();
      expect(capture.finished, isTrue);
      expect(capture.exitCode, 3);
      expect(capture.synced, isFalse);
      expect(capture.output().output, 'hello\nworld\n');
      capture
        ..add('<<FINN:n1:S>>\r\n')
        ..scan();
      expect(capture.synced, isTrue);
    });

    test('output without a final newline keeps none', () {
      final capture = SerialCapture('x', maxOutputBytes: 1024)
        ..add('<<FINN:x:B>>\nabc\n<<FINN:x:E:0>>\n')
        ..scan();
      expect(capture.output().output, 'abc');
      expect(capture.exitCode, 0);
    });

    test('ignores markers with another nonce', () {
      final capture = SerialCapture('mine', maxOutputBytes: 1024)
        ..add('<<FINN:mine:B>>\n<<FINN:other:E:0>>\n')
        ..scan();
      expect(capture.finished, isFalse);
    });

    test('decodes UTF-8 split across chunks', () {
      final bytes = serial('<<FINN:u:B>>\nü€\n<<FINN:u:E:0>>\n');
      final capture = SerialCapture('u', maxOutputBytes: 1024);
      for (final unit in bytes.split('')) {
        capture.add(unit);
      }
      capture.scan();
      expect(capture.output().output, 'ü€');
    });

    test('truncates at the cap and survives an endless writer', () {
      final capture = SerialCapture('t', maxOutputBytes: 10)
        ..add('<<FINN:t:B>>\n');
      for (var i = 0; i < 2000; i++) {
        capture.add('y\n');
      }
      capture
        ..add('\n<<FINN:t:E:130>>\n<<FINN:t:S>>\n')
        ..scan();
      final (:output, :truncated) = capture.output();
      expect(truncated, isTrue);
      expect(output.length, 10);
      expect(capture.exitCode, 130);
      expect(capture.synced, isTrue);
    });

    test('a prompt is recognised at the end of the console', () {
      expect(ContainerProtocol.looksLikePrompt('booting\r\n~% '), isTrue);
      expect(ContainerProtocol.looksLikePrompt('/ # '), isTrue);
      expect(ContainerProtocol.looksLikePrompt('Loading kernel'), isFalse);
    });

    test('the console echo of a command line never contains a marker', () {
      // Markers are printed with printf and an argument, so the text typed
      // into the console never contains a whole one.
      for (final line in [
        ContainerProtocol.initLine('abc'),
        ContainerProtocol.runLine('abc'),
        ContainerProtocol.pullLine('abc'),
        ContainerProtocol.runScriptBody,
        ContainerProtocol.pullScriptBody,
      ]) {
        expect(line.contains('<<FINN:abc:'), isFalse, reason: line);
      }
    });
  });

  group('UstarWriter', () {
    test('writes headers busybox accepts: ustar magic and a valid checksum',
        () {
      final tar = (UstarWriter()
            ..directory('src')
            ..file('src/main.sh', utf8.encode('echo hi\n'), mode: 0x1ed))
          .finish();
      expect(ascii.decode(tar.sublist(257, 262)), 'ustar');
      var sum = 0;
      for (var i = 0; i < 512; i++) {
        sum += (i >= 148 && i < 156) ? 0x20 : tar[i];
      }
      final stored = int.parse(
          ascii.decode(tar.sublist(148, 154)).replaceAll('\u0000', ''),
          radix: 8);
      expect(stored, sum);

      final archive = TarDecoder().decodeBytes(tar);
      final file = archive.findFile('src/main.sh')!;
      expect(utf8.decode(file.readBytes()!), 'echo hi\n');
      expect(file.mode & 0x1ff, 0x1ed);
    });

    test('splits a long path into prefix and name', () {
      final long = '${List.filled(30, 'folder').join('/')}/file.txt';
      expect(long.length, greaterThan(100));
      final tar = (UstarWriter()..file(long, [1, 2, 3])).finish();
      final archive = TarDecoder().decodeBytes(tar);
      expect(archive.files.single.name, long);
    });

    test('leaves out a path ustar cannot carry', () {
      final writer = UstarWriter()..file('${'x' * 300}.txt', [1]);
      expect(writer.skipped, 1);
    });
  });

  group('WorkspaceSync', () {
    late CodeWorkspace workspace;
    late WorkspaceSync sync;

    setUp(() async {
      workspace = CodeWorkspace(Directory('${temp.path}/project'));
      await workspace.writeFile('a.txt', 'a');
      await workspace.writeFile('src/b.sh', 'echo b');
      sync = WorkspaceSync(workspace);
    });

    Uint8List containerSays(Map<String, (String, int)> files,
        {List<String> dirs = const []}) {
      final writer = UstarWriter();
      for (final dir in dirs) {
        writer.directory(dir);
      }
      for (final MapEntry(key: path, value: (content, mode)) in files.entries) {
        writer.file(path, utf8.encode(content), mode: mode);
      }
      return writer.finish();
    }

    test('packs the folder but not its scratch space', () async {
      await File('${workspace.root.path}/.tmp/secret').writeAsString('x');
      final archive = TarDecoder().decodeBytes(await sync.pack());
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, containsAll(['a.txt', 'src/', 'src/b.sh']));
      expect(names.any((n) => n.contains('.tmp')), isFalse);
    });

    test('applies changes, additions and deletions back', () async {
      final report = await sync.apply(containerSays({
        'src/b.sh': ('echo changed', 0x1ed),
        'new/c.txt': ('c', 0x1a4),
      }, dirs: [
        'src',
        'new'
      ]));
      expect(await workspace.readFile('src/b.sh'), 'echo changed');
      expect(await workspace.readFile('new/c.txt'), 'c');
      expect(File('${workspace.root.path}/a.txt').existsSync(), isFalse);
      expect(report.written, 2);
      expect(report.deleted, 1);
      // Scratch space is the app's, not the container's.
      expect(Directory('${workspace.root.path}/.tmp').existsSync(), isTrue);
    });

    test('an unchanged file is not rewritten', () async {
      final report = await sync.apply(containerSays({
        'a.txt': ('a', 0x1a4),
        'src/b.sh': ('echo b', 0x1a4),
      }, dirs: [
        'src'
      ]));
      expect(report.written, 0);
      expect(report.deleted, 0);
    });

    test('an executable bit survives the round trip', () async {
      await sync.apply(containerSays({
        'a.txt': ('a', 0x1a4),
        'src/b.sh': ('echo b', 0x1ed),
      }, dirs: [
        'src'
      ]));
      // Even where the device file system drops it, the next push restores it.
      final archive = TarDecoder().decodeBytes(await sync.pack());
      expect(archive.findFile('src/b.sh')!.mode & 0x49, isNot(0));
      expect(archive.findFile('a.txt')!.mode & 0x49, 0);
    });

    test('never brings back a link or a path out of the folder', () async {
      final archive = Archive()
        ..add(ArchiveFile.bytes('a.txt', utf8.encode('a')))
        ..add(ArchiveFile.bytes('../escape.txt', utf8.encode('x')))
        ..add(ArchiveFile.bytes('.tmp/x', utf8.encode('x')))
        ..add(ArchiveFile.symlink('link', '/etc/passwd'));
      final report = await sync.apply(TarEncoder().encodeBytes(archive));
      expect(File('${temp.path}/escape.txt').existsSync(), isFalse);
      expect(
        FileSystemEntity.typeSync('${workspace.root.path}/link',
            followLinks: false),
        FileSystemEntityType.notFound,
      );
      expect(report.skipped, 3);
    });

    test('refuses a project over the limit', () async {
      final small = WorkspaceSync(workspace, maxBytes: 4);
      expect(small.pack(), throwsA(isA<WorkspaceTooLarge>()));
    });
  });

  group('ContainerInstaller', () {
    final good = utf8.encode('linux kernel');
    final artifact = ContainerArtifact(
      fileName: 'bzimage.bin',
      url: 'https://example.test/bzimage.bin',
      bytes: good.length,
      sha256: sha256.convert(good).toString(),
    );

    ContainerInstaller installer(MockClient client) => ContainerInstaller(
          directoryProvider: () async => temp,
          clientFactory: () => client,
          artifacts: [artifact],
        );

    test('downloads, verifies and reports installed', () async {
      final subject = installer(MockClient((_) async => http.Response.bytes(
            good,
            200,
          )));
      await subject.refresh();
      expect(subject.state, ContainerInstallState.missing);
      expect(await subject.install(), isTrue);
      expect(subject.installed, isTrue);
      final file = File('${temp.path}/code/container/bzimage.bin');
      expect(await file.readAsBytes(), good);
      await subject.refresh();
      expect(subject.installed, isTrue);
    });

    test('discards a download whose digest does not match', () async {
      final bad = utf8.encode('linux kerneX');
      final subject =
          installer(MockClient((_) async => http.Response.bytes(bad, 200)));
      expect(await subject.install(), isFalse);
      expect(subject.error, ContainerInstallError.verification);
      expect(
          Directory('${temp.path}/code/container').listSync().whereType<File>(),
          isEmpty);
    });

    test('a download longer than pinned is refused', () async {
      final subject = installer(MockClient(
          (_) async => http.Response.bytes([...good, ...good], 200)));
      expect(await subject.install(), isFalse);
      expect(subject.error, ContainerInstallError.verification);
    });

    test('an HTTP error is a network failure', () async {
      final subject =
          installer(MockClient((_) async => http.Response('gone', 404)));
      expect(await subject.install(), isFalse);
      expect(subject.error, ContainerInstallError.network);
    });

    test('removing it leaves it missing', () async {
      final subject =
          installer(MockClient((_) async => http.Response.bytes(good, 200)));
      await subject.install();
      expect(await subject.deleteStorage(), isEmpty);
      expect(subject.state, ContainerInstallState.missing);
    });

    test('the pinned image is the one the emulator was built for', () {
      expect(ContainerImage.artifacts, hasLength(3));
      for (final pinned in ContainerImage.artifacts) {
        expect(pinned.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(pinned.url, startsWith('https://'));
      }
      expect(ContainerImage.downloadBytes, 10068480 + 131072 + 36352);
    });
  });

  group('ContainerHost', () {
    test('answers only under its token, and only with its own files', () async {
      final host = ContainerHost(
        loadAsset: (name) async => utf8.encode('asset:$name'),
        imageDirectory: () async => temp,
        bootTimeout: const Duration(seconds: 5),
      );
      final booting = host.start();
      while (host.viewUrl == null) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final url = host.viewUrl!;
      expect(url.host, '127.0.0.1');
      final client = HttpClient();
      Future<(int, String)> get(Uri uri) async {
        final response = await (await client.getUrl(uri)).close();
        return (response.statusCode, await utf8.decodeStream(response));
      }

      final token = url.pathSegments.first;
      expect(await get(url), (200, 'asset:runtime.html'));
      expect((await get(url.replace(path: '/wrong/runtime.html'))).$1, 404);
      expect((await get(url.replace(path: '/$token/../etc/passwd'))).$1, 404);
      expect((await get(url.replace(path: '/$token/secrets.json'))).$1, 404);
      client.close(force: true);
      await host.stop();
      await expectLater(booting, throwsA(anything));
    });
  });

  group('runner routing', () {
    late CodeSessionStore sessions;
    late CodeSettingsStore settings;

    setUp(() {
      sessions = CodeSessionStore(directoryProvider: () async => temp);
      settings = CodeSettingsStore(directoryProvider: () async => temp);
    });

    tearDown(() => sessions.dispose());

    ContainerShell shell({required bool installed, bool supported = true}) {
      final installer = _FixedInstaller(installed);
      return ContainerShell(
        installer: installer,
        platformSupported: supported,
        host: ContainerHost(
          loadAsset: (_) async => const [],
          imageDirectory: () async => temp,
        ),
      );
    }

    test('commands go to the container once it is installed', () {
      final runner = WorkspaceActionRunner(
        sessions: sessions,
        settings: settings,
        container: shell(installed: true),
        shellSupported: true,
      );
      expect(runner.environment, CommandEnvironment.container);
    });

    test('the device shell until then, or when switched off', () async {
      expect(
        WorkspaceActionRunner(
          sessions: sessions,
          settings: settings,
          container: shell(installed: false),
          shellSupported: true,
        ).environment,
        CommandEnvironment.device,
      );
      await settings.update((s) => s.copyWith(useContainer: false));
      expect(
        WorkspaceActionRunner(
          sessions: sessions,
          settings: settings,
          container: shell(installed: true),
          shellSupported: true,
        ).environment,
        CommandEnvironment.device,
      );
    });

    test('the container gives commands to a device with no shell', () {
      final runner = WorkspaceActionRunner(
        sessions: sessions,
        settings: settings,
        container: shell(installed: true),
        shellSupported: false,
      );
      expect(runner.canRunCommands, isTrue);
      expect(
        WorkspaceActionRunner(
          sessions: sessions,
          settings: settings,
          container: shell(installed: true, supported: false),
          shellSupported: false,
        ).environment,
        CommandEnvironment.none,
      );
    });

    test('the setting persists and defaults to on', () {
      expect(const CodeSettings().useContainer, isTrue);
      expect(CodeSettings.fromJson(const {}).useContainer, isTrue);
      expect(
        CodeSettings.fromJson(const {'container': false}).useContainer,
        isFalse,
      );
    });
  });

  test('the container prompt names its tools and stays short', () {
    final prompt = AgentProtocol.systemPrompt(shell: true, container: true);
    expect(prompt, contains('busybox'));
    expect(prompt, contains('chmod +x'));
    expect(prompt.length, lessThan(1500));
  });
}

class _FixedInstaller extends ContainerInstaller {
  _FixedInstaller(this._installed) : super(artifacts: const []);

  final bool _installed;

  @override
  bool get installed => _installed;
}
