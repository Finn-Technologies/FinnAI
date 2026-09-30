import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/engine/finn_accelerator.dart';

void main() {
  bool retry({
    int retriesLeft = 1,
    int visibleTokens = 0,
    String trailingText = '',
    GenerationFinishReason finish = GenerationFinishReason.eos,
  }) =>
      shouldRetryEmptyReply(
        retriesLeft: retriesLeft,
        visibleTokens: visibleTokens,
        trailingText: trailingText,
        finish: finish,
      );

  test('an instantly finished, invisible reply is retried once', () {
    expect(retry(), isTrue);
  });

  test('a spent budget never retries, so an empty turn cannot loop', () {
    expect(retry(retriesLeft: 0), isFalse);
  });

  test('a reply with any visible text is never retried', () {
    expect(retry(visibleTokens: 1), isFalse);
    expect(retry(trailingText: 'ok'), isFalse);
  });

  test('only a natural end is retried', () {
    for (final finish in GenerationFinishReason.values) {
      if (finish == GenerationFinishReason.eos) continue;
      expect(retry(finish: finish), isFalse, reason: finish.name);
    }
  });
}
