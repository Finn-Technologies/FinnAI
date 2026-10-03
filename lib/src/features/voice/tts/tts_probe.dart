import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/voice/tts/local_tts_backend.dart';

/// Speaks a few sentences in several languages and prints how long each took
/// (`FINN_TTS …` lines), so the on-device voice can be checked on a real phone
/// without a conversation. Run with `--dart-define=FINN_TTS_PROBE=true`.
Future<void> runTtsProbe() async {
  final backend = LocalTtsBackend();
  var completed = 0;
  final done = Completer<void>();
  const lines = <(String, String)>[
    ('en', 'Hello! This is the new on-device voice. How does it sound to you?'),
    ('it', 'Ciao, questa è la nuova voce che funziona sul telefono.'),
    ('de', 'Guten Tag, das ist die neue Stimme auf dem Gerät.'),
    ('es', 'Hola, esta es la nueva voz que funciona en el teléfono.'),
    ('fr', 'Bonjour, voici la nouvelle voix qui fonctionne sur le téléphone.'),
    ('ru', 'Привет, это новый голос на устройстве.'),
  ];
  await backend.initialize(
    onComplete: () {
      completed++;
      debugPrint('FINN_TTS_PROBE completed=$completed/${lines.length}');
      if (completed == lines.length && !done.isCompleted) done.complete();
    },
    onError: (Object? error) {
      debugPrint('FINN_TTS_PROBE error=$error');
      if (!done.isCompleted) done.complete();
    },
  );
  final watch = Stopwatch()..start();
  for (final (language, text) in lines) {
    await backend.setLanguage(language);
    await backend.speak(text);
  }
  await done.future.timeout(
    const Duration(minutes: 3),
    onTimeout: () => debugPrint('FINN_TTS_PROBE timeout'),
  );
  debugPrint('FINN_TTS_PROBE total_ms=${watch.elapsedMilliseconds}');
  await backend.release();
}
