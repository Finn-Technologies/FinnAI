import 'dart:io';

import 'package:finn_ai/src/features/voice/linux_speech.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('spd-say gets a relative rate and the text after --', () {
    expect(
      LinuxSpeech.arguments('spd-say', '-hello', rate: .45, languageCode: 'de'),
      ['--wait', '-r', '0', '-l', 'de', '--', '-hello'],
    );
    expect(
      LinuxSpeech.arguments('spd-say', 'x', rate: .6)[2],
      '49',
      reason: 'fast is faster than normal',
    );
    expect(LinuxSpeech.arguments('spd-say', 'x', rate: .32)[2], '-43');
  });

  test('espeak gets words per minute', () {
    expect(
      LinuxSpeech.arguments('espeak-ng', 'hi', rate: .45, languageCode: 'en'),
      ['-s', '175', '-l', 'en', '--', 'hi'],
    );
  });

  test('reports no synthesiser when none is installed', () async {
    final speech = LinuxSpeech(exists: (_) async => false);
    expect(await speech.engine(), isNull);
    expect(await speech.speak('hi', rate: .45), isFalse);
  });

  test('picks the first installed synthesiser in preference order', () async {
    final speech = LinuxSpeech(exists: (c) async => c != 'spd-say');
    expect(await speech.engine(), 'espeak-ng');
  });

  test('stop with nothing running is a no-op', () async {
    final speech = LinuxSpeech(
      start: (_, __) async => throw const ProcessException('x', []),
      exists: (_) async => true,
    );
    await speech.stop();
    expect(await speech.speak('hi', rate: .45), isFalse);
  });
}
