import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A `.tar.bz2` shaped like the sherpa-onnx voice archives.
List<int> voiceArchive(String id, {bool withModel = true}) {
  final archive = Archive()
    ..addFile(ArchiveFile.bytes('$id/', const []))
    ..addFile(ArchiveFile.string('$id/tokens.txt', '_ 0\na 1\n'))
    ..addFile(ArchiveFile.string('$id/MODEL_CARD', 'not needed'))
    ..addFile(ArchiveFile.string('$id/espeak-ng-data/phontab', 'phonemes'))
    ..addFile(ArchiveFile.string('$id/espeak-ng-data/lang/en/x', 'lang'));
  if (withModel) {
    archive.addFile(ArchiveFile.bytes('$id/model.onnx', List.filled(300, 7)));
  }
  return BZip2Encoder().encode(TarEncoder().encode(archive));
}

TtsVoice voiceFor(String id, String language, List<int> bytes) => TtsVoice(
      language: language,
      id: id,
      bytes: bytes.length,
      sha256Digest: sha256.convert(bytes).toString(),
    );

void main() {
  late Directory root;
  late HttpServer server;
  late Map<String, List<int>> bodies;
  var requests = 0;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tts_store_test');
    bodies = {};
    requests = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(server.forEach((request) async {
      requests++;
      final body = bodies[request.uri.path];
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

  test('installs a voice: model and tokens in place, data shared', () async {
    final bytes = voiceArchive('v-en');
    final voice = voiceFor('v-en', 'en', bytes);
    bodies['/${voice.id}.tar.bz2'] = bytes;
    final store = _LocalStore(root, server.port);

    expect(await store.isInstalled(voice), isFalse);
    await store.install(voice);

    expect(await store.isInstalled(voice), isTrue);
    final paths = (await store.paths(voice))!;
    expect(File(paths.model).existsSync(), isTrue);
    expect(paths.model, endsWith('.onnx'));
    expect(File(paths.tokens).readAsStringSync(), contains('a 1'));
    expect(File('${paths.dataDir}/phontab').existsSync(), isTrue);
    expect(File('${paths.dataDir}/lang/en/x').existsSync(), isTrue);
    // Only what is used is kept.
    expect(File('${root.path}/voices/v-en/MODEL_CARD').existsSync(), isFalse);
    // The archive is not kept: it would double the disk cost.
    expect(Directory('${root.path}/archives').listSync(), isEmpty);
  });

  test('a second voice reuses the shared espeak data', () async {
    final a = voiceArchive('v-en');
    final b = voiceArchive('v-de');
    final en = voiceFor('v-en', 'en', a);
    final de = voiceFor('v-de', 'de', b);
    bodies['/v-en.tar.bz2'] = a;
    bodies['/v-de.tar.bz2'] = b;
    final store = _LocalStore(root, server.port);

    await store.install(en);
    final marker = File('${root.path}/espeak-ng-data/phontab')
      ..writeAsStringSync('first copy wins');
    await store.install(de);

    expect(await store.isInstalled(en), isTrue);
    expect(await store.isInstalled(de), isTrue);
    expect(marker.readAsStringSync(), 'first copy wins',
        reason: 'the shared data is unpacked once, not once per voice');
  });

  test('installing twice downloads once', () async {
    final bytes = voiceArchive('v-en');
    final voice = voiceFor('v-en', 'en', bytes);
    bodies['/v-en.tar.bz2'] = bytes;
    final store = _LocalStore(root, server.port);

    await Future.wait([store.install(voice), store.install(voice)]);
    final after = requests;
    await store.install(voice);

    expect(after, 1);
    expect(requests, 1, reason: 'an installed voice is not fetched again');
  });

  test('progress is reported while downloading', () async {
    final bytes = voiceArchive('v-en');
    final voice = voiceFor('v-en', 'en', bytes);
    bodies['/v-en.tar.bz2'] = bytes;
    final store = _LocalStore(root, server.port);
    final seen = <int>[];

    await store.install(voice, onProgress: seen.add);

    expect(seen, isNotEmpty);
    expect(seen.last, bytes.length);
  });

  test('a download that fails verification installs nothing', () async {
    final bytes = voiceArchive('v-en');
    final voice = TtsVoice(
      language: 'en',
      id: 'v-en',
      bytes: bytes.length,
      sha256Digest: sha256.convert([1, 2, 3]).toString(),
    );
    bodies['/v-en.tar.bz2'] = bytes;
    final store = _LocalStore(root, server.port);

    await expectLater(store.install(voice), throwsA(isA<HttpException>()));

    expect(await store.isInstalled(voice), isFalse);
  });

  test('an archive without a model is refused, not half-installed', () async {
    final bytes = voiceArchive('v-en', withModel: false);
    final voice = voiceFor('v-en', 'en', bytes);
    bodies['/v-en.tar.bz2'] = bytes;
    final store = _LocalStore(root, server.port);

    await expectLater(store.install(voice), throwsA(isA<StateError>()));

    expect(await store.isInstalled(voice), isFalse);
  });

  test('a missing file reports the status', () async {
    final voice = voiceFor('absent', 'en', [1]);
    final store = _LocalStore(root, server.port);

    await expectLater(
      store.install(voice),
      throwsA(predicate((e) => '$e'.contains('404'))),
    );
  });

  test('a voice that is no longer in the catalog is pruned', () async {
    final store = _LocalStore(root, server.port);
    Directory('${root.path}/voices/old-voice').createSync(recursive: true);
    Directory('${root.path}/voices/kept-voice').createSync(recursive: true);
    File('${root.path}/voices/stray.txt').createSync();

    await store.pruneRetired(keep: {'kept-voice'});

    expect(Directory('${root.path}/voices/old-voice').existsSync(), isFalse);
    expect(Directory('${root.path}/voices/kept-voice').existsSync(), isTrue);
    expect(File('${root.path}/voices/stray.txt').existsSync(), isTrue,
        reason: 'only voice folders are touched');
  });

  test('the failed marker is set, cleared by deleteAll', () async {
    final store = _LocalStore(root, server.port);
    expect(await store.installFailedBefore(), isFalse);

    await store.markInstallFailed();
    expect(await store.installFailedBefore(), isTrue);

    await store.clearInstallFailed();
    expect(await store.installFailedBefore(), isFalse);

    await store.markInstallFailed();
    await store.deleteAll();
    expect(await store.installFailedBefore(), isFalse);
  });

  test('deleteAll removes voices and shared data', () async {
    final bytes = voiceArchive('v-en');
    final voice = voiceFor('v-en', 'en', bytes);
    bodies['/v-en.tar.bz2'] = bytes;
    final store = _LocalStore(root, server.port);
    await store.install(voice);

    await store.deleteAll();

    expect(await root.exists(), isFalse);
    expect(await store.isInstalled(voice), isFalse);
  });

  test('the real extractor unpacks on another isolate', () async {
    final bytes = voiceArchive('v-en');
    final file = File('${root.path}/a.tar.bz2')..writeAsBytesSync(bytes);

    await extractTtsArchive(
      file.path,
      '${root.path}/out/voice',
      '${root.path}/out/data',
    );

    expect(File('${root.path}/out/voice/model.onnx').existsSync(), isTrue);
    expect(File('${root.path}/out/data/phontab').existsSync(), isTrue);
    expect(Directory('${root.path}/out/voice.tmp').existsSync(), isFalse);
    expect(Directory('${root.path}/out/data.tmp').existsSync(), isFalse);
  });
}

/// A [TtsVoiceStore] that fetches from a local server, whatever the voice's
/// URL says.
class _LocalStore extends TtsVoiceStore {
  _LocalStore(Directory root, int port)
      : super(
          root: root,
          urlFor: (voice) => 'http://127.0.0.1:$port/${voice.id}.tar.bz2',
          // The test voices are not in the catalog and must not be pruned.
          pruneAfterInstall: false,
        );
}
