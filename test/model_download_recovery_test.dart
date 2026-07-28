import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:finn_ai/src/inference/bonsai_inference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a complete verified partial model is promoted without redownload',
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
        expectedSha256: sha256.convert(bytes).toString(),
      );

      expect(promoted, isTrue);
      expect(await partial.exists(), isFalse);
      expect(await target.readAsBytes(), bytes);
    },
  );

  test('a corrupt complete partial is removed before retry', () async {
    final directory = await Directory.systemTemp.createTemp(
      'finn-model-corrupt-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final partial = File('${directory.path}/model.gguf.part');
    final target = File('${directory.path}/model.gguf');
    await partial.writeAsBytes(<int>[1, 2, 3, 4]);

    final promoted = await promoteVerifiedModelPartial(
      partial: partial,
      target: target,
      expectedBytes: 4,
      expectedSha256: sha256.convert(<int>[9, 9, 9, 9]).toString(),
    );

    expect(promoted, isFalse);
    expect(await partial.exists(), isFalse);
    expect(await target.exists(), isFalse);
  });
}
