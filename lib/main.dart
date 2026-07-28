import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/flux_app.dart';
import 'src/inference/bonsai_inference.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('FINN_BENCHMARK')) {
    await BonsaiInference.instance.initialize();
    if (const String.fromEnvironment('FINN_BENCH_TIER') == 'lite') {
      BonsaiInference.instance.select(BonsaiTier.lite);
    }
    await _runDeviceBenchmark();
  }
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF9F9F8),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const FinnBootstrap());
}

/// Compile-time gated device harness. It is absent from normal release builds
/// and lets performance changes be verified through ADB without UI timing
/// noise or synthetic native binaries.
Future<void> _runDeviceBenchmark() async {
  final inference = BonsaiInference.instance;
  final wasInstalled = await inference.isInstalled(inference.selected);
  await inference.prewarm();
  const firstPrompt =
      'Write exactly 100 words about local AI with no introduction.';
  final firstAnswer = StringBuffer();
  await for (final token in inference.generateReply(
    firstPrompt,
    conversationId: 'device-benchmark',
  )) {
    firstAnswer.write(token);
  }
  await inference
      .generateReply(
        'Summarize that in one short sentence.',
        conversationId: 'device-benchmark',
        history: [
          const LocalChatTurn(role: 'user', content: firstPrompt),
          LocalChatTurn(role: 'assistant', content: firstAnswer.toString()),
        ],
      )
      .drain<void>();
  await inference.releaseMemory();
  if (!wasInstalled) await inference.remove(inference.selected);
}
