import 'dart:io';

import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn-artifacts-');
  });
  tearDown(() => directory.delete(recursive: true));

  String path(String name) => '${directory.path}/$name';

  test('the suffix list covers the model, its partial, and its repack cache',
      () {
    expect(
      FinnAccelerator.modelFileSuffixes,
      containsAll(<String>['', '.part', '.finn_repack']),
    );
  });

  test('removal takes the repack cache with it', () async {
    // The bug this exists for: `.finn_repack` (~693MB on the 1.6B) was never
    // deleted, so "Delete All Local Data" left it behind.
    final model = File(path('model.gguf'))..writeAsBytesSync([1, 2, 3]);
    final repack = File(path('model.gguf.finn_repack'))
      ..writeAsBytesSync(List.filled(1024, 7));

    expect(await repack.exists(), isTrue);
    final removed = await removeModelArtifactFiles(model);

    expect(await model.exists(), isFalse);
    expect(await repack.exists(), isFalse);
    expect(removed, hasLength(2));
    expect(
      removed.where((entry) => entry.endsWith('.finn_repack')),
      hasLength(1),
      reason: 'the repack cache must be reported as removed',
    );
    expect(
      removed.where((entry) => entry.endsWith('model.gguf')),
      hasLength(1),
    );
  });

  test('removal takes an interrupted partial and its range side-files',
      () async {
    final model = File(path('model.gguf'))..writeAsBytesSync([1]);
    final partial = File(path('model.gguf.part'))..writeAsBytesSync([1, 2]);
    final range = File(path('model.gguf.part.r0'))..writeAsBytesSync([3]);

    await removeModelArtifactFiles(model);

    expect(await model.exists(), isFalse);
    expect(await partial.exists(), isFalse);
    expect(await range.exists(), isFalse);
  });

  test('removal on a file that was never installed is a no-op', () async {
    final removed = await removeModelArtifactFiles(File(path('absent.gguf')));
    expect(removed, isEmpty);
  });

  test('one undeletable artifact does not strand the others', () async {
    final model = File(path('model.gguf'))..writeAsBytesSync([1]);
    final partial = File(path('model.gguf.part'))..writeAsBytesSync([1, 2]);
    // A directory where a file is expected cannot be deleted with File.delete.
    await Directory(path('model.gguf.finn_repack')).create();

    final removed = await removeModelArtifactFiles(model);

    expect(await model.exists(), isFalse);
    expect(await partial.exists(), isFalse);
    expect(removed, isNotEmpty);
  });
}
