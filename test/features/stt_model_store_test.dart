import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:finn_ai/src/features/voice/stt/speech_backend.dart';
import 'package:finn_ai/src/features/voice/stt/stt_model_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A local server that serves fixed bodies and honours `Range`.
class _Server {
  _Server(this.bodies);

  final Map<String, List<int>> bodies;
  late final HttpServer _server;
  final List<String?> rangeHeaders = [];
  int requests = 0;

  /// When set, the next response for [path] is cut short after this many bytes.
  final Map<String, int> truncateOnce = {};

  Uri url(String path) => Uri.parse('http://127.0.0.1:${_server.port}$path');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_server.forEach((request) async {
      requests++;
      final body = bodies[request.uri.path];
      if (body == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final range = request.headers.value(HttpHeaders.rangeHeader);
      rangeHeaders.add(range);
      var start = 0;
      if (range != null) {
        start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        request.response.statusCode = HttpStatus.partialContent;
      }
      var chunk = body.sublist(start);
      final cut = truncateOnce.remove(request.uri.path);
      if (cut != null) chunk = chunk.sublist(0, cut);
      request.response.add(chunk);
      await request.response.close();
    }));
  }

  Future<void> stop() => _server.close(force: true);
}

String _sha(List<int> bytes) => sha256.convert(bytes).toString();

void main() {
  late Directory root;
  late _Server server;
  late List<int> small;
  late List<int> large;
  late List<SttModelFile> files;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('stt_store_test');
    small = utf8.encode('tokens-file');
    large = List<int>.generate(5000, (i) => i % 251);
    server = _Server({'/small': small, '/large': large});
    await server.start();
    files = [
      SttModelFile(
        name: 'small.txt',
        url: server.url('/small').toString(),
        bytes: small.length,
        sha256Digest: _sha(small),
      ),
      SttModelFile(
        name: 'large.onnx',
        url: server.url('/large').toString(),
        bytes: large.length,
        sha256Digest: _sha(large),
      ),
    ];
  });

  tearDown(() async {
    await server.stop();
    if (await root.exists()) await root.delete(recursive: true);
  });

  SttModelStore makeStore() => SttModelStore(root: root, files: files);

  test('the pinned manifest names every file the recogniser needs', () {
    final names = sttModelFiles.map((f) => f.name).toSet();
    expect(
        names,
        containsAll([
          'base-encoder.int8.onnx',
          'base-decoder.int8.onnx',
          'base-tokens.txt',
          'silero_vad.onnx',
        ]));
    for (final file in sttModelFiles) {
      expect(file.sha256Digest, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(file.bytes, greaterThan(0));
      expect(file.url, startsWith('https://'));
    }
    expect(sttModelSizeLabel, matches(RegExp(r'^\d+ MB$')));
  });

  test('nothing is installed to begin with', () async {
    final store = makeStore();
    await store.refresh();
    expect(await store.isInstalled(), isFalse);
    expect(await store.paths(), isNull);
    expect(store.status.value, SpeechModelStatus.missing);
  });

  test('download installs every file and reports progress to ready', () async {
    final store = makeStore();
    final seen = <SpeechModelPhase>[];
    final progress = <double>[];
    store.status.addListener(() {
      seen.add(store.status.value.phase);
      progress.add(store.status.value.progress);
    });

    await store.download();

    expect(await store.isInstalled(), isTrue);
    expect(store.status.value, SpeechModelStatus.ready);
    expect(seen.first, SpeechModelPhase.downloading);
    expect(seen.last, SpeechModelPhase.ready);
    final downloading = [
      for (var i = 0; i < seen.length; i++)
        if (seen[i] == SpeechModelPhase.downloading) progress[i],
    ];
    expect(downloading, orderedEquals([...downloading]..sort()));
    expect(
      await File('${root.path}/large.onnx').readAsBytes(),
      large,
    );
    expect(
      root.listSync().whereType<File>().where((f) => f.path.endsWith('.part')),
      isEmpty,
    );
  });

  test('a second download of an installed model makes no requests', () async {
    final store = makeStore();
    await store.download();
    final before = server.requests;

    await store.download();

    expect(server.requests, before);
  });

  test('an interrupted download resumes with a Range request', () async {
    final store = makeStore();
    server.truncateOnce['/large'] = 1200;

    await expectLater(store.download(), throwsA(isA<Exception>()));
    expect(store.status.value.phase, SpeechModelPhase.failed);
    expect(await store.isInstalled(), isFalse);
    expect(await File('${root.path}/large.onnx.part').length(), 1200);

    await store.download();

    expect(server.rangeHeaders.last, 'bytes=1200-');
    expect(await store.isInstalled(), isTrue);
    expect(await File('${root.path}/large.onnx').readAsBytes(), large);
  });

  test('a file that fails verification is discarded, not installed', () async {
    files = [
      SttModelFile(
        name: 'large.onnx',
        url: server.url('/large').toString(),
        bytes: large.length,
        sha256Digest: _sha(utf8.encode('something else')),
      ),
    ];
    final store = makeStore();

    await expectLater(store.download(), throwsA(isA<HttpException>()));

    expect(await store.isInstalled(), isFalse);
    expect(await File('${root.path}/large.onnx').exists(), isFalse);
    // A bad file must not be left to resume from.
    expect(await File('${root.path}/large.onnx.part').exists(), isFalse);
    expect(store.status.value.phase, SpeechModelPhase.failed);
  });

  test('a missing file fails the download with the status code', () async {
    files = [
      SttModelFile(
        name: 'x.bin',
        url: server.url('/nope').toString(),
        bytes: 10,
        sha256Digest: _sha([1]),
      ),
    ];
    final store = makeStore();

    await expectLater(
      store.download(),
      throwsA(predicate((e) => '$e'.contains('404'))),
    );
    expect(store.status.value.phase, SpeechModelPhase.failed);
  });

  test('paths are only handed out for a complete install', () async {
    final store = SttModelStore(root: root, files: [
      for (final name in [
        'base-encoder.int8.onnx',
        'base-decoder.int8.onnx',
        'base-tokens.txt',
        'silero_vad.onnx',
      ])
        SttModelFile(
          name: name,
          url: server.url('/small').toString(),
          bytes: small.length,
          sha256Digest: _sha(small),
        ),
    ]);
    expect(await store.paths(), isNull);
    await store.download();

    final paths = await store.paths();
    expect(paths, isNotNull);
    expect(paths!.encoder, '${root.path}/base-encoder.int8.onnx');
    expect(paths.vad, '${root.path}/silero_vad.onnx');
  });

  test('a truncated file under its final name is not an install', () async {
    final store = makeStore();
    await store.download();
    await File('${root.path}/large.onnx').writeAsBytes([1, 2, 3]);

    expect(await store.isInstalled(), isFalse);
  });

  test('delete removes the model and its partial downloads', () async {
    final store = makeStore();
    await store.download();
    await File('${root.path}/large.onnx.part').writeAsBytes([1]);

    await store.delete();

    expect(await root.exists(), isFalse);
    expect(await store.isInstalled(), isFalse);
    expect(store.status.value, SpeechModelStatus.missing);
  });
}
