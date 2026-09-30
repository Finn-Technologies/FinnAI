import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/engine/finn_engine.dart';
import 'package:finn_ai/src/engine/metrics/ttft_metrics.dart';
import 'package:finn_ai/src/engine/profiler/device_profile.dart';

/// Compile-time gated device performance harness. It is absent from normal
/// release builds and lets performance changes be verified through ADB without
/// UI timing noise or synthetic native binaries.
///
/// Scenario, runs, prompt, prewarm, and search-decision overrides can be
/// supplied either as compile-time dart-defines (the defaults) or as Android
/// intent extras via `adb shell am start --es/--ei/--ez` so one benchmark APK
/// can sweep every scenario and engine config without rebuilding.
///
/// This lives in the engine rather than in `main.dart` so the production
/// entry point carries no benchmark code; `tool/run_eval.sh` drives it.
Future<void> runDeviceBenchmark() async {
  // ignore: avoid_print
  print('FINN_HARNESS begin');
  final inference = FinnAccelerator.instance;
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
  // The engine owns the native log sink; callers never import the FFI package
  // directly (engine seam rule, see tool/verify_engine_seam.sh).
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
  if (override('noPrefixCache') == true ||
      const bool.fromEnvironment('FINN_BENCH_NO_PREFIX')) {
    FinnAccelerator.debugDisablePrefixCache = true;
  }
  if (override('cpu') == true || const bool.fromEnvironment('FINN_BENCH_CPU')) {
    FinnAccelerator.debugForceCpu = true;
  }
  if (override('noSha') == true ||
      const bool.fromEnvironment('FINN_BENCH_NO_SHA')) {
    FinnAccelerator.debugSkipSha256 = true;
  }
  debugPrint(
    'FINN_HARNESS overrides=${jsonEncode(runtimeOverrides)} '
    'forceCpu=${FinnAccelerator.debugForceCpu} '
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
    compactKv: override('compactKv') == true
        ? true
        : override('f16Kv') == true
            ? false
            : null,
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
