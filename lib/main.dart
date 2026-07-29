import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/flux_app.dart';
import 'src/inference/bonsai_inference.dart';
import 'src/inference/evaluation.dart';
import 'src/inference/prompt_intent.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('FINN_BENCHMARK')) {
    await BonsaiInference.instance.initialize();
    if (const String.fromEnvironment('FINN_BENCH_TIER') == 'lite') {
      BonsaiInference.instance.select(BonsaiTier.lite);
    }
    await _runDeviceBenchmark();
  }
  if (const bool.fromEnvironment('FINN_EVALUATION')) {
    await BonsaiInference.instance.initialize();
    await _runModelEvaluation();
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

/// Runs the multilingual quality suite against semicolon-delimited
/// `label=absolute/path/to/model.gguf` entries supplied through
/// `FINN_EVAL_MODELS`. Results are emitted as one JSON object per prompt.
Future<void> _runModelEvaluation() async {
  const specification = String.fromEnvironment('FINN_EVAL_MODELS');
  if (specification.trim().isEmpty) {
    debugPrint('FINN_EVAL_ERROR FINN_EVAL_MODELS is empty');
    return;
  }
  const prompts = [
    'Come fare una torta di ricotta e fragole?',
    'Come preparare una pizza margherita?',
    'Spiegami come cambiare una lampadina.',
    'Scrivi un messaggio per prenotare una visita.',
    'Confronta iPhone 14 e Redmi Note 12.',
    'Translate this sentence into Italian: The train leaves at six.',
    'Hello',
    'Ciao',
    'Can you tell me how to upgrade the RAM in my laptop?',
    'How do I replace my laptop SSD?',
    'How do I replace my phone battery?',
    'Come posso aggiornare la RAM del portatile?',
    'Come posso sostituire l’SSD del portatile?',
    'Come posso sostituire la batteria del telefono?',
  ];
  for (final entry in specification.split(';')) {
    final separator = entry.indexOf('=');
    if (separator <= 0) continue;
    final label = entry.substring(0, separator).trim();
    final path = entry.substring(separator + 1).trim();
    for (var index = 0; index < prompts.length; index++) {
      final prompt = prompts[index];
      final answer = StringBuffer();
      await for (final token
          in BonsaiInference.instance.generateEvaluationReply(
            prompt,
            path: path,
            modelLabel: label,
            tier: BonsaiTier.lite,
            conversationId: 'eval-$label-$index',
          )) {
        answer.write(token);
      }
      final analysis = const PromptIntentClassifier().classify(prompt);
      final report = BonsaiInference.instance.lastGenerationReport;
      final response = answer.toString();
      debugPrint(
        'FINN_EVAL ${jsonEncode({'selectedModel': label, 'intent': analysis.intent.name, 'route': report?.route.name, 'outputBudget': report?.outputBudget, 'finishReason': report?.finishReason.name, 'firstTokenLatencyMs': report?.firstTokenLatency?.inMilliseconds, 'totalGenerationTimeMs': report?.totalGenerationTime.inMilliseconds, 'outputTokens': report?.outputTokens, 'tokensPerSecond': report?.tokensPerSecond, if (index == 0) 'recipeAcceptance': assessRicottaStrawberryCake(response).toJson(), if (prompt == 'Can you tell me how to upgrade the RAM in my laptop?') 'hardwareAcceptance': assessLaptopRamGuidance(response).toJson(), 'response': response})}',
      );
    }
    await BonsaiInference.instance.releaseMemory();
  }
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
