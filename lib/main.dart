import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/flow_background.dart' show flowBackgroundMain;
import 'package:finn_ai/src/app/bootstrap.dart';
import 'package:finn_ai/src/engine/eval/benchmark.dart';
import 'package:finn_ai/src/engine/eval/harness.dart';
import 'package:finn_ai/src/features/search/search_turn.dart';
import 'package:finn_ai/src/features/voice/tts/tts_probe.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/shared/config/licenses.dart';
import 'package:finn_ai/src/platform/openharmony_path_provider.dart';

/// The screenless entry point `FlowBackgroundRunner.kt` starts by name. Naming it
/// here is what keeps it in the compiled app: a library nothing imports is not
/// part of it, and the engine would fail to find the function.
// ignore: unused_element
final _flowBackgroundEntry = flowBackgroundMain;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OpenHarmonyPathProvider.registerIfNeeded();
  registerModelLicenses();
  if (const bool.fromEnvironment('FINN_TTS_PROBE')) {
    runApp(const _BareBenchmarkApp());
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(runTtsProbe()));
    return;
  }
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
      unawaited(runDeviceBenchmark());
    });
  } else if (evaluation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final candidateRun =
          const String.fromEnvironment('FINN_EVAL_MODELS').trim().isNotEmpty;
      unawaited(
        candidateRun
            ? runCandidateModelEvaluation()
            : runEvalHarness(grounder: _groundEvalTurn),
      );
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

final _evalSearch = SearchTurn();

/// The app's own search step, applied to an eval prompt, so the harness
/// measures the path a user's message takes and not the engine alone.
Future<EvalGrounding> _groundEvalTurn(
  String prompt,
  List<LocalChatTurn> history, {
  required bool hasAttachment,
}) async {
  final plan = const SearchPlanner().plan(prompt, hasAttachment: hasAttachment);
  if (!plan.search) return EvalGrounding.none;
  final result = await _evalSearch.run(plan);
  return EvalGrounding(
    groundedContext: result.groundedContext,
    sources: result.sources,
    searched: result.searched,
  );
}
