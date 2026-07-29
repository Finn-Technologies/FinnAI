import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/flux_app.dart';
import 'src/inference/bonsai_inference.dart';
import 'src/inference/evaluation.dart';
import 'src/inference/prompt_intent.dart';
import 'src/inference/ttft_metrics.dart';

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
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
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
  const scenario = String.fromEnvironment(
    'FINN_BENCH_SCENARIO',
    defaultValue: 'model_warm',
  );
  const runs = int.fromEnvironment('FINN_BENCH_RUNS', defaultValue: 5);
  const prewarm = String.fromEnvironment(
    'FINN_BENCH_PREWARM',
    defaultValue: 'selected',
  );
  const promptOverride = String.fromEnvironment('FINN_BENCH_PROMPT');
  final prompt = promptOverride.isNotEmpty
      ? promptOverride
      : switch (scenario) {
          'direct_plus' => 'Write five short sentences about Rome.',
          'ambiguous' => 'Tell me something useful for today.',
          _ => 'Reply with exactly one word: ready.',
        };

  if (scenario != 'true_cold') {
    if (prewarm == 'lite' || prewarm == 'both') {
      await inference.prewarmTier(BonsaiTier.lite);
    }
    if (prewarm == 'plus' || prewarm == 'both') {
      await inference.prewarmTier(BonsaiTier.plus);
    }
    if (prewarm == 'selected') await inference.prewarm();
  }

  final ttftValues = <int>[];
  final conversationHistory = <LocalChatTurn>[];
  const warmConversationId = 'benchmark-conversation';
  if (scenario == 'conversation_warm') {
    final warmup = StringBuffer();
    await for (final token in inference.generateReply(
      prompt,
      conversationId: warmConversationId,
    )) {
      warmup.write(token);
    }
    conversationHistory
      ..add(LocalChatTurn(role: 'user', content: prompt))
      ..add(LocalChatTurn(role: 'assistant', content: warmup.toString()));
  }
  for (var run = 0; run < runs; run++) {
    if (scenario == 'true_cold') {
      await inference.releaseMemory();
    } else if (scenario == 'model_warm' ||
        scenario == 'prefix_warm' ||
        scenario == 'direct_plus' ||
        scenario == 'ambiguous') {
      await inference.releaseConversationSessions();
    }
    final conversationId = scenario == 'conversation_warm'
        ? warmConversationId
        : 'benchmark-$scenario-$run';
    final trace = TtftTrace(
      generationId: 'benchmark-$scenario-$run',
      conversationId: conversationId,
    );
    var first = '';
    final answer = StringBuffer();
    await for (final token in inference.generateReply(
      prompt,
      conversationId: conversationId,
      history: conversationHistory,
      trace: trace,
    )) {
      if (first.isEmpty && token.isNotEmpty) {
        first = token;
        trace
          ..mark(TtftPhase.uiPaintScheduled)
          ..mark(TtftPhase.uiPaintCompleted);
      }
      answer.write(token);
    }
    if (scenario == 'conversation_warm') {
      conversationHistory
        ..add(LocalChatTurn(role: 'user', content: prompt))
        ..add(LocalChatTurn(role: 'assistant', content: answer.toString()));
    }
    final metrics = trace.toJson();
    final total = metrics['total_ttft_ms'];
    if (total is int) ttftValues.add(total);
    debugPrint(
      'FINN_BENCH ${jsonEncode({'scenario': scenario, 'run': run, 'first_visible_characters': first.length, ...metrics})}',
    );
  }
  if (ttftValues.isNotEmpty) {
    ttftValues.sort();
    int percentile(double fraction) {
      final index = ((ttftValues.length - 1) * fraction).ceil();
      return ttftValues[index.clamp(0, ttftValues.length - 1)];
    }

    debugPrint(
      'FINN_BENCH_SUMMARY ${jsonEncode({'scenario': scenario, 'runs': ttftValues.length, 'min_ms': ttftValues.first, 'p50_ms': percentile(.50), 'p90_ms': percentile(.90), 'p95_ms': percentile(.95), 'max_ms': ttftValues.last})}',
    );
  }
  await inference.releaseMemory();
}
