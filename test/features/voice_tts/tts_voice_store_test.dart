import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_store.dart';
import 'package:flutter_test/flutter_test.dart';

TtsFile fileOf(String path, List<int> bytes) => TtsFile(
      path: path,
      bytes: bytes.length,
      sha256Digest: sha256.convert(bytes).toString(),
    );

/// A small voice shaped like the real one: a few files in two folders.
({TtsVoice voice, Map<String, List<int>> bodies}) smallVoice({
  String id = 'v-test',
}) {
  final bodies = <String, List<int>>{
    'onnx/a.onnx': List.filled(300, 1),
    'onnx/tts.json': List.filled(40, 2),
    'voice_styles/F1.json': List.filled(25, 3),
  };
  return (
    voice: TtsVoice(
      id: id,
      repository: 'owner/$id',
      files: [for (final e in bodies.entries) fileOf(e.key, e.value)],
    ),
    bodies: bodies,
  );
}

void main() {
  late Directory root;
  late HttpServer server;
  late Map<String, List<int>> served;
  var requests = 0;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tts_store_test');
    served = {};
    requests = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(server.forEach((request) async {
      requests++;
      final body = served[request.uri.path];
      if (body == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.add(body);
      }
      await request.response.close();
    }));
  });

  tearDown(() async {
    await server.close(force: true);
    if (await root.exists()) await root.delete(recursive: true);
  });

  _LocalStore store() => _LocalStore(root, server.port);

  test('installs a voice: every file in its folder, then the marker', () async {
    final v = smallVoice();
    served = {for (final e in v.bodies.entries) '/${e.key}': e.value};

    final s = store();
    expect(await s.isInstalled(v.voice), isFalse);
    await s.install(v.voice);

    expect(await s.isInstalled(v.voice), isTrue);
    final paths = (await s.paths(v.voice))!;
    expect(File('${paths.modelDirectory}/a.onnx').existsSync(), isTrue);
    expect(File(paths.config).existsSync(), isTrue);
    expect(File(paths.style('F1')).existsSync(), isTrue);
    expect(paths.modelDirectory, endsWith('/onnx'));
  });

  test('a voice with a missing file is not installed', () async {
    final v = smallVoice();
    served = {for (final e in v.bodies.entries) '/${e.key}': e.value};
    final s = store();
    await s.install(v.voice);

    File('${root.path}/voices/${v.voice.id}/onnx/a.onnx').deleteSync();

    expect(await s.isInstalled(v.voice), isFalse);
  });

  test('a file of the wrong size is not installed', () async {
    final v = smallVoice();
    served = {for (final e in v.bodies.entries) '/${e.key}': e.value};
    final s = store();
    await s.install(v.voice);

    File('${root.path}/voices/${v.voice.id}/onnx/a.onnx')
        .writeAsBytesSync([1, 2, 3]);

    expect(await s.isInstalled(v.voice), isFalse);
  });

  test('installing twice downloads once', () async {
    final v = smallVoice();
    served = {for (final e in v.bodies.entries) '/${e.key}': e.value};
    final s = store();

    await Future.wait([s.install(v.voice), s.install(v.voice)]);
    final after = requests;
    await s.install(v.voice);

    expect(after, v.voice.files.length);
    expect(requests, after, reason: 'an installed voice is not fetched again');
  });

  test('a file that is already there is not fetched again', () async {
    final v = smallVoice();
    served = {for (final e in v.bodies.entries) '/${e.key}': e.value};
    final s = store();
    // A first attempt that stopped before the last file.
    final dir = Directory('${root.path}/voices/${v.voice.id}/onnx')
      ..createSync(recursive: true);
    File('${dir.path}/a.onnx').writeAsBytesSync(v.bodies['onnx/a.onnx']!);

    await s.install(v.voice);

    expect(requests, v.voice.files.length - 1);
    expect(await s.isInstalled(v.voice), isTrue);
  });

  test('progress runs across all the files, to the total', () async {
    final v = smallVoice();
    served = {for (final e in v.bodies.entries) '/${e.key}': e.value};
    final seen = <int>[];

    await store().install(v.voice, onProgress: seen.add);

    expect(seen, isNotEmpty);
    expect(seen.last, v.voice.bytes);
    expect(seen, orderedEquals([...seen]..sort()), reason: 'never goes back');
  });

  test('a download that fails verification installs nothing', () async {
    final v = smallVoice();
    served = {for (final e in v.bodies.entries) '/${e.key}': e.value};
    final tampered = TtsVoice(
      id: v.voice.id,
      repository: v.voice.repository,
      files: [
        for (final f in v.voice.files)
          TtsFile(
            path: f.path,
            bytes: f.bytes,
            sha256Digest: f.path.endsWith('tts.json')
                ? sha256.convert([9, 9, 9]).toString()
                : f.sha256Digest,
          ),
      ],
    );
    final s = store();

    await expectLater(s.install(tampered), throwsA(isA<HttpException>()));

    expect(await s.isInstalled(tampered), isFalse);
  });

  test('a missing file reports the status', () async {
    final v = smallVoice();
    final s = store();

    await expectLater(
      s.install(v.voice),
      throwsA(predicate((e) => '$e'.contains('404'))),
    );
  });

  test('a voice that is no longer in the catalog is pruned', () async {
    final s = store();
    Directory('${root.path}/voices/old-voice').createSync(recursive: true);
    Directory('${root.path}/voices/kept-voice').createSync(recursive: true);
    File('${root.path}/voices/stray.txt').createSync();

    await s.pruneRetired(keep: {'kept-voice'});

    expect(Directory('${root.path}/voices/old-voice').existsSync(), isFalse);
    expect(Directory('${root.path}/voices/kept-voice').existsSync(), isTrue);
    expect(File('${root.path}/voices/stray.txt').existsSync(), isTrue,
        reason: 'only voice folders are touched');
  });

  test('the retired Piper data is cleaned from an upgraded phone', () async {
    final s = store();
    Directory('${root.path}/voices/vits-piper-en_US-ljspeech-medium-int8')
        .createSync(recursive: true);
    Directory('${root.path}/espeak-ng-data').createSync(recursive: true);
    File('${root.path}/espeak-ng-data/phontab').writeAsStringSync('gpl data');
    Directory('${root.path}/archives').createSync(recursive: true);

    await s.pruneRetired();

    expect(Directory('${root.path}/espeak-ng-data').existsSync(), isFalse,
        reason: 'GPL phoneme data must not stay on the device');
    expect(Directory('${root.path}/archives').existsSync(), isFalse);
    expect(
      Directory('${root.path}/voices/vits-piper-en_US-ljspeech-medium-int8')
          .existsSync(),
      isFalse,
    );
  });

  test('the failed marker is set, cleared by deleteAll', () async {
    final s = store();
    expect(await s.installFailedBefore(), isFalse);

    await s.markInstallFailed();
    expect(await s.installFailedBefore(), isTrue);

    await s.clearInstallFailed();
    expect(await s.installFailedBefore(), isFalse);

    await s.markInstallFailed();
    await s.deleteAll();
    expect(await s.installFailedBefore(), isFalse);
  });

  test('deleteAll removes the voice', () async {
    final v = smallVoice();
    served = {for (final e in v.bodies.entries) '/${e.key}': e.value};
    final s = store();
    await s.install(v.voice);

    await s.deleteAll();

    expect(await root.exists(), isFalse);
    expect(await s.isInstalled(v.voice), isFalse);
  });
}

/// A [TtsVoiceStore] that fetches from a local server, whatever the voice's
/// repository says.
class _LocalStore extends TtsVoiceStore {
  _LocalStore(Directory root, int port)
      : super(
          root: root,
          urlFor: (voice, file) => 'http://127.0.0.1:$port/${file.path}',
          // The test voices are not in the catalog and must not be pruned.
          pruneAfterInstall: false,
        );
}
