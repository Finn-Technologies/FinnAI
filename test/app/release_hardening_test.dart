import 'dart:io';

import 'package:finn_ai/src/inference/model_catalog.dart';
import 'package:finn_ai/src/shared/widgets/safe_markdown_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production model artifacts use immutable revisions and SHA-256 digests',
    () {
      for (final model in finnModels) {
        expect(model.downloadUrl, matches(RegExp(r'/resolve/[0-9a-f]{40}/')));
        expect(model.sha256Digest, matches(RegExp(r'^[0-9a-f]{64}$')));
      }
      expect(
        finnMmproj.downloadUrl,
        matches(RegExp(r'/resolve/[0-9a-f]{40}/')),
      );
      expect(finnMmproj.sha256Digest, matches(RegExp(r'^[0-9a-f]{64}$')));
    },
  );

  test('release configuration does not use mutable model URLs', () async {
    final source = await File(
      'lib/src/engine/catalog/model_catalog.dart',
    ).readAsString();
    expect(source, isNot(contains('/resolve/main/')));
  });

  test('safe markdown strips unsafe links and HTML', () {
    expect(
      SafeMarkdownText.sanitize(
        '[unsafe](javascript:alert(1)) <script>x</script>',
      ),
      isNot(contains('javascript:')),
    );
    expect(
      SafeMarkdownText.sanitize('[safe](https://example.com)'),
      contains('https://example.com'),
    );
  });
}
