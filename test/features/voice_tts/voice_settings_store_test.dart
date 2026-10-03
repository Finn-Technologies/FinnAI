import 'dart:io';

import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';
import 'package:finn_ai/src/features/voice/voice_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('voice-settings');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  VoiceSettingsStore store() =>
      VoiceSettingsStore(directoryProvider: () async => dir);

  test('the default speaking style is the default voice', () {
    expect(const VoiceSettings().ttsStyle, defaultTtsStyle);
  });

  test('a chosen style round-trips through the file', () async {
    final first = store();
    await first.initialize();
    expect(await first.setTtsStyle('M1'), isTrue);

    final second = store();
    await second.initialize();
    expect(second.ttsStyle, 'M1');
  });

  test('an unknown stored style falls back to the default', () async {
    final file = File('${dir.path}/voice_settings.json');
    await file.writeAsString('{"version":3,"ttsStyle":"X9"}');

    final second = store();
    await second.initialize();
    expect(second.ttsStyle, defaultTtsStyle);
  });

  test('setTtsStyle stores the default for an unknown style', () async {
    final s = store();
    await s.initialize();
    await s.setTtsStyle('X9');
    expect(s.ttsStyle, defaultTtsStyle);
  });
}
