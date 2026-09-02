import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'src/flux_app.dart';
import 'src/inference/device_profile.dart';
import 'src/inference/finn_inference.dart';
import 'src/inference/evaluation.dart';
import 'src/inference/prompt_intent.dart';
import 'src/inference/ttft_metrics.dart';
import 'src/legal/licenses.dart';
import 'src/openharmony/openharmony_path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OpenHarmonyPathProvider.registerIfNeeded();
  registerModelLicenses();
  final benchmark = const bool.fromEnvironment('FINN_BENCHMARK');
  final evaluation = const bool.fromEnvironment('FINN_EVALUATION');
  if (benchmark || evaluation) {
    // ignore: avoid_print
    print('FINN_MAIN start');
    await FinnInference.instance.initialize();
    // ignore: avoid_print
    print('FINN_MAIN initialized');
    if (const String.fromEnvironment('FINN_BENCH_TIER') == 'lite') {
      FinnInference.instance.select(FinnModelTier.standard);
    }
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

  // The benchmark/eval harness must run AFTER the first frame: Android puts
  // an app whose activity is never visible into the background cgroup, where
  // MIUI throttles the big CPU cluster to ~700 MHz (measured: A78 cores at
  // 691 MHz while A55s run at 1.8 GHz), collapsing decode ~45x. A visible
  // activity keeps the process in top-app with full CPU, matching real use.
  final bare = benchmark || evaluation;
  if (benchmark || evaluation) {
    // ignore: avoid_print
    print('FINN_MAIN runApp');
  }
  runApp(bare ? const _BareBenchmarkApp() : const FinnBootstrap());
  if (benchmark) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: avoid_print
      print('FINN_MAIN postFrame');
      unawaited(_runDeviceBenchmark());
    });
  } else if (evaluation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runModelEvaluation());
    });
  }
}

/// Minimal visible shell for the device/eval harnesses. Keeping the real app
/// out of the picture avoids double prewarm and UI contention during runs;
/// a visible surface is what keeps the process out of the background cgroup.
class _BareBenchmarkApp extends StatelessWidget {
  const _BareBenchmarkApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Scaffold(body: Center(child: Text('benchmark'))),
    );
  }
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
    'Come fare una torta salata con zucchine per 3 persone?',
    'Come fare una torta salata con prosciutto per 4 persone?',
    'Come fare una torta di mele?',
    'Come fare una torta di fragole?',
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
    'How does the routing in Bridgetown work?',
    'How do living ants know that an ant has died?',
  ];
  const caseSelection = String.fromEnvironment('FINN_EVAL_CASES');
  final selectedCases = caseSelection.trim().isEmpty
      ? List<int>.generate(prompts.length, (index) => index)
      : caseSelection
          .split(',')
          .map((value) => int.tryParse(value.trim()))
          .whereType<int>()
          .where((index) => index >= 0 && index < prompts.length)
          .toSet()
          .toList(growable: false);
  for (final entry in specification.split(';')) {
    final separator = entry.indexOf('=');
    if (separator <= 0) continue;
    final label = entry.substring(0, separator).trim();
    final path = entry.substring(separator + 1).trim();
    for (final index in selectedCases) {
      final prompt = prompts[index];
      final answer = StringBuffer();
      await for (final token in FinnInference.instance.generateEvaluationReply(
        prompt,
        path: path,
        modelLabel: label,
        tier: FinnModelTier.standard,
        conversationId: 'eval-$label-$index',
      )) {
        answer.write(token);
      }
      final analysis = const PromptIntentClassifier().classify(prompt);
      final report = FinnInference.instance.lastGenerationReport;
      final response = answer.toString();
      debugPrint(
        'FINN_EVAL ${jsonEncode({
              'selectedModel': label,
              'intent': analysis.intent.name,
              'route': report?.route.name,
              'outputBudget': report?.outputBudget,
              'finishReason': report?.finishReason.name,
              'firstTokenLatencyMs': report?.firstTokenLatency?.inMilliseconds,
              'totalGenerationTimeMs':
                  report?.totalGenerationTime.inMilliseconds,
              'outputTokens': report?.outputTokens,
              'tokensPerSecond': report?.tokensPerSecond,
              if (prompt == 'Come fare una torta di ricotta e fragole?')
                'recipeAcceptance':
                    assessRicottaStrawberryCake(response).toJson(),
              if (prompt ==
                  'Can you tell me how to upgrade the RAM in my laptop?')
                'hardwareAcceptance':
                    assessLaptopRamGuidance(response).toJson(),
              if (prompt == 'How does the routing in Bridgetown work?')
                'bridgetownAcceptance':
                    assessBridgetownRouting(response).toJson(),
              if (prompt == 'How do living ants know that an ant has died?')
                'antNecrophoresisAcceptance':
                    assessAntNecrophoresis(response).toJson(),
              'response': response
            })}',
      );
    }
    await FinnInference.instance.releaseMemory();
  }
}

/// Compile-time gated device harness. It is absent from normal release builds
/// and lets performance changes be verified through ADB without UI timing
/// noise or synthetic native binaries.
///
/// Scenario, runs, prompt, prewarm, and search-decision overrides can be
/// supplied either as compile-time dart-defines (the defaults) or as Android
/// intent extras via `adb shell am start --es/--ei/--ez` so one benchmark APK
/// can sweep every scenario and engine config without rebuilding.
Future<void> _runDeviceBenchmark() async {
  // ignore: avoid_print
  print('FINN_HARNESS begin');
  final inference = FinnInference.instance;
  Map<Object?, Object?> runtimeOverrides = const {};
  try {
    runtimeOverrides = await const MethodChannel(
          'finn_ai/benchmark',
        ).invokeMapMethod<Object?, Object?>('getOverrides') ??
        const {};
  } catch (_) {
    // Non-Android hosts have no intent extras; dart-defines apply.
  }
  // Surface llama.cpp's native logs (engine init, graph, perf) to a file the
  // host can tail via `run-as` — Android's stderr is not connected to logcat.
  // Routed through the engine facade: main.dart never imports the FFI
  // package directly (engine seam rule, see analysis_options.yaml).
  final supportDir = await getApplicationSupportDirectory();
  setLlamaNativeLogCapturePath(
    '${supportDir.path}${Platform.pathSeparator}llama_native.log',
  );
  // Benchmark builds: also mirror the native log to the app's own external
  // files dir so an adb shell can read it without run-as (release builds are
  // not debuggable). The benchmark model lives on /data/local/tmp, which
  // SELinux keeps read-only for the app, so the repacked-weight cache is
  // redirected into the same app-writable dir.
  if (const bool.fromEnvironment('FINN_BENCHMARK')) {
    setLlamaNativeLogCapturePath(
      '/sdcard/Android/data/com.abhiflex.finnai/files/llama_native.log',
    );
    setLlamaRepackCacheDir('/sdcard/Android/data/com.abhiflex.finnai/files');
  }
  Object? override(String name) => runtimeOverrides[name];
  const scenario = String.fromEnvironment(
    'FINN_BENCH_SCENARIO',
    defaultValue: 'model_warm',
  );
  final scenarioValue = override('scenario') is String &&
          (override('scenario') as String).isNotEmpty
      ? override('scenario') as String
      : scenario;
  const runs = int.fromEnvironment('FINN_BENCH_RUNS', defaultValue: 5);
  final runsValue =
      override('runs') is int ? (override('runs') as int).clamp(1, 25) : runs;
  const prewarm = String.fromEnvironment(
    'FINN_BENCH_PREWARM',
    defaultValue: 'selected',
  );
  final prewarmValue = override('prewarm') is String &&
          (override('prewarm') as String).isNotEmpty
      ? override('prewarm') as String
      : prewarm;
  const noSearchDefine = bool.fromEnvironment('FINN_BENCH_NO_SEARCH');
  final noSearch = override('noSearch') == true || noSearchDefine;
  if (override('noPrefixCache') == true ||
      const bool.fromEnvironment('FINN_BENCH_NO_PREFIX')) {
    FinnInference.debugDisablePrefixCache = true;
  }
  if (override('cpu') == true || const bool.fromEnvironment('FINN_BENCH_CPU')) {
    FinnInference.debugForceCpu = true;
  }
  if (override('noSha') == true ||
      const bool.fromEnvironment('FINN_BENCH_NO_SHA')) {
    FinnInference.debugSkipSha256 = true;
  }
  debugPrint(
    'FINN_HARNESS overrides=${jsonEncode(runtimeOverrides)} '
    'forceCpu=${FinnInference.debugForceCpu} '
    'nRsSeq=${DeviceProfiler.lookaheadSnapshots(await DeviceProfiler.read())}',
  );
  // Engine-config sweep overrides (intent extras): threads / batch threads /
  // batch / ubatch / KV type / flash attention, applied to the heuristic plan.
  DeviceProfiler.planOverrides = PlanOverrides(
    threads: override('threads') is int ? (override('threads') as int) : null,
    batchThreads: override('batchThreads') is int
        ? (override('batchThreads') as int)
        : null,
    batchSize: override('batch') is int ? (override('batch') as int) : null,
    microBatchSize:
        override('ubatch') is int ? (override('ubatch') as int) : null,
    compactKv: override('f16Kv') == true ? false : null,
    flashAttention: override('flashOff') == true ? false : null,
    nRsSeq: override('nrs') is int ? (override('nrs') as int) : null,
  );
  const candidatePath = String.fromEnvironment('FINN_BENCH_MODEL_PATH');
  const candidateLabel = String.fromEnvironment(
    'FINN_BENCH_MODEL_LABEL',
    defaultValue: 'benchmark-candidate',
  );
  const promptOverride = String.fromEnvironment('FINN_BENCH_PROMPT');
  final promptExtra =
      override('prompt') is String ? (override('prompt') as String).trim() : '';
  final prompt = promptExtra.isNotEmpty
      ? promptExtra
      : promptOverride.isNotEmpty
          ? promptOverride
          : switch (scenarioValue) {
              'direct_plus' => 'Write five short sentences about Rome.',
              'ambiguous' => 'Tell me something useful for today.',
              _ => 'Reply with exactly one word: ready.',
            };

  if (scenarioValue != 'true_cold') {
    if (prewarmValue == 'lite' || prewarmValue == 'both') {
      await inference.prewarmTier(FinnModelTier.standard);
    }
    if (prewarmValue == 'plus' || prewarmValue == 'both') {
      await inference.prewarmTier(FinnModelTier.standard);
    }
    if (prewarmValue == 'selected') await inference.prewarm();
  }

  final ttftValues = <int>[];
  final conversationHistory = <LocalChatTurn>[];
  const warmConversationId = 'benchmark-conversation';
  Stream<String> generate(
    String input, {
    required String conversationId,
    List<LocalChatTurn> history = const [],
    TtftTrace? trace,
  }) =>
      candidatePath.isEmpty
          ? inference.generateReply(
              input,
              conversationId: conversationId,
              history: history,
              trace: trace,
              enableSearchDecision: !noSearch,
            )
          : inference.generateEvaluationReply(
              input,
              path: candidatePath,
              modelLabel: candidateLabel,
              tier: FinnModelTier.standard,
              conversationId: conversationId,
              history: history,
              trace: trace,
            );
  if (scenarioValue == 'conversation_warm') {
    final warmup = StringBuffer();
    await for (final token in generate(
      prompt,
      conversationId: warmConversationId,
    )) {
      warmup.write(token);
    }
    conversationHistory
      ..add(LocalChatTurn(role: 'user', content: prompt))
      ..add(LocalChatTurn(role: 'assistant', content: warmup.toString()));
  }
  for (var run = 0; run < runsValue; run++) {
    if (scenarioValue == 'true_cold') {
      await inference.releaseMemory();
    } else if (scenarioValue == 'model_warm' ||
        scenarioValue == 'prefix_warm' ||
        scenarioValue == 'direct_plus' ||
        scenarioValue == 'ambiguous') {
      await inference.releaseConversationSessions();
    }
    final conversationId = scenarioValue == 'conversation_warm'
        ? warmConversationId
        : 'benchmark-$scenarioValue-$run';
    final trace = TtftTrace(
      generationId: 'benchmark-$scenarioValue-$run',
      conversationId: conversationId,
    );
    var first = '';
    final answer = StringBuffer();
    await for (final token in generate(
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
    if (scenarioValue == 'conversation_warm') {
      conversationHistory
        ..add(LocalChatTurn(role: 'user', content: prompt))
        ..add(LocalChatTurn(role: 'assistant', content: answer.toString()));
    }
    final metrics = trace.toJson();
    final total = metrics['total_ttft_ms'];
    if (total is int) ttftValues.add(total);
    debugPrint(
      'FINN_BENCH ${jsonEncode({
            'scenario': scenarioValue,
            'run': run,
            'first_visible_characters': first.length,
            ...metrics
          })}',
    );
  }
  if (ttftValues.isNotEmpty) {
    ttftValues.sort();
    int percentile(double fraction) {
      final index = ((ttftValues.length - 1) * fraction).ceil();
      return ttftValues[index.clamp(0, ttftValues.length - 1)];
    }

    debugPrint(
      'FINN_BENCH_SUMMARY ${jsonEncode({
            'scenario': scenarioValue,
            'runs': ttftValues.length,
            'min_ms': ttftValues.first,
            'p50_ms': percentile(.50),
            'p90_ms': percentile(.90),
            'p95_ms': percentile(.95),
            'max_ms': ttftValues.last
          })}',
    );
  }
  await inference.releaseMemory();
}
