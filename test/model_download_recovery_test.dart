import 'dart:io';

import 'package:finn_ai/src/inference/qwen_inference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a complete partial model is promoted without redownload',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'finn-model-recovery-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final partial = File('${directory.path}/model.gguf.part');
      final target = File('${directory.path}/model.gguf');
      final bytes = <int>[0x47, 0x47, 0x55, 0x46, 1, 2, 3, 4];
      await partial.writeAsBytes(bytes);

      final promoted = await promoteVerifiedModelPartial(
        partial: partial,
        target: target,
        expectedBytes: bytes.length,
      );

      expect(promoted, isTrue);
      expect(await partial.exists(), isFalse);
      expect(await target.readAsBytes(), bytes);
    },
  );

  test('a partial with the wrong size is not promoted', () async {
    final directory = await Directory.systemTemp.createTemp(
      'finn-model-incomplete-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final partial = File('${directory.path}/model.gguf.part');
    final target = File('${directory.path}/model.gguf');
    await partial.writeAsBytes(<int>[1, 2, 3, 4]);

    final promoted = await promoteVerifiedModelPartial(
      partial: partial,
      target: target,
      expectedBytes: 9,
    );

    expect(promoted, isFalse);
    expect(await partial.exists(), isTrue);
    expect(await target.exists(), isFalse);
  });
}
