import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/engine/eval/eval_baseline.dart';
import 'package:finn_ai/src/engine/eval/eval_prompts.dart';
import 'package:finn_ai/src/engine/eval/evaluation.dart';
import 'package:finn_ai/src/engine/eval/harness.dart';
import 'package:finn_ai/src/engine/finn_accelerator.dart';
import 'package:finn_ai/src/engine/profiler/device_profile.dart';
import 'package:finn_ai/src/engine/prompt/prompt_intent.dart';

/// Entry point for the on-device quality run, driven by dart-defines and
/// driven from `tool/run_eval.sh`.
///
/// Deductions, in order of precedence:
/// - `FINN_EVAL_SUITES` selects suites (default: all).
/// - `FINN_EVAL_PROMPT_FILE` adds cases from a JSON file on the device, which
///   is the only way to run non-Latin prompts today.
/// - `FINN_EVAL_BASELINE` names a committed baseline to gate against.
/// - `FINN_EVAL_WRITE_BASELINE` writes the run out as a new baseline.
/// - `FINN_EVAL_MAX_CASES` caps the run, for a quick smoke pass.
/// - `FINN_EVAL_PASSES` runs the suite N times and gates on the median turn.
/// - `FINN_EVAL_RANDOM_SEEDS` turns off the per-turn fixed seeds.
Future<void> runEvalHarness({EvalGrounder? grounder}) async {
  const suiteSpec = String.fromEnvironment('FINN_EVAL_SUITES');
  const promptFile = String.fromEnvironment('FINN_EVAL_PROMPT_FILE');
  const baselinePath = String.fromEnvironment('FINN_EVAL_BASELINE');
  const writeBaseline = String.fromEnvironment('FINN_EVAL_WRITE_BASELINE');
  const maxCases = int.fromEnvironment('FINN_EVAL_MAX_CASES', defaultValue: 0);
  const imageFile = String.fromEnvironment('FINN_EVAL_IMAGE');
  // Whole passes over the suite, gated on the per-turn median (eval_passes).
  const passes = int.fromEnvironment('FINN_EVAL_PASSES', defaultValue: 1);
  // On by default: a run is only comparable with another if both sampled the
  // same tokens. `FINN_EVAL_RANDOM_SEEDS=true` restores the app's behaviour.
  const randomSeeds = bool.fromEnvironment('FINN_EVAL_RANDOM_SEEDS');

  final Set<EvalSuite> suites;
  try {
    suites = parseSuites(suiteSpec);
  } on FormatException catch (error) {
    // ignore: avoid_print
    print('FINN_EVAL_ERROR ${error.message}');
    return;
  }

  var cases = EvalPromptCatalog.forSuites(suites);
  if (promptFile.trim().isNotEmpty) {
    final file = File(promptFile);
    if (!file.existsSync()) {
      // ignore: avoid_print
      print('FINN_EVAL_ERROR prompt file not found: $promptFile');
      return;
    }
    try {
      cases = [...cases, ...EvalPromptCatalog.loadCasesFromFile(file)];
    } catch (error) {
      // ignore: avoid_print
      print('FINN_EVAL_ERROR prompt file rejected: $error');
      return;
    }
  }
  Uint8List? imageBytes;
  if (imageFile.trim().isNotEmpty) {
    final file = File(imageFile);
    if (file.existsSync()) {
      imageBytes = file.readAsBytesSync();
    } else {
      // ignore: avoid_print
      print('FINN_EVAL_WARN image not found: $imageFile');
    }
  }
  if (imageBytes == null) {
    cases = cases.where((c) => !c.withImage).toList(growable: false);
  }
  if (maxCases > 0 && cases.length > maxCases) {
    cases = cases.take(maxCases).toList(growable: false);
  }

  EvalBaseline? baseline;
  if (baselinePath.trim().isNotEmpty) {
    final file = File(baselinePath);
    if (file.existsSync()) {
      try {
        baseline = EvalBaseline.decode(file.readAsStringSync());
      } catch (error) {
        // ignore: avoid_print
        print('FINN_EVAL_ERROR baseline rejected: $error');
      }
    } else {
      // A gate run without its baseline still emits a passing-looking GATE
      // with only the absolute checks, so a missing file must be loud.
      // ignore: avoid_print
      print('FINN_EVAL_ERROR baseline not found: $baselinePath');
    }
  }

  final engine = FinnAccelerator.instance;
  final profile = await DeviceProfiler.read();
  // Warm the model first so the cold load lands outside the measured turns
  // instead of being charged to whichever case happens to run first. A device
  // that has not downloaded the model yet simply reports the cold number.
  try {
    await engine.prewarm();
  } catch (error) {
    // ignore: avoid_print
    print('FINN_EVAL_WARN prewarm failed, first turn carries the load: $error');
  }
  // The app grounds a turn before the engine sees it (ADR 0001), so the eval
  // must too: measuring the engine alone reported browse recall 0.0 for a run
  // in which the app would have searched.
  var searchedThisTurn = false;
  final harness = EvalHarness(
    generate: (
      prompt, {
      required conversationId,
      required history,
      trace,
    }) async* {
      final grounding = grounder == null
          ? EvalGrounding.none
          : await grounder(
              prompt,
              history,
              hasAttachment:
                  history.isNotEmpty && history.last.imageBytes != null,
            );
      searchedThisTurn = grounding.searched;
      yield* engine.generateReply(
        prompt,
        conversationId: conversationId,
        history: history,
        groundedContext: grounding.groundedContext,
        sources: grounding.sources,
        trace: trace,
      );
    },
    readEngine: () {
      final report = engine.lastGenerationReport;
      return EvalEngineView(
        searched: searchedThisTurn,
        intent: report?.intent.toString(),
        route: report?.route.name,
        finishReason: report?.finishReason.name,
        outputTokens: report?.outputTokens,
        tokensPerSecond: report?.tokensPerSecond,
      );
    },
    imageBytes: imageBytes,
    seedTurn:
        randomSeeds ? null : (seed) => FinnAccelerator.debugFixedSeed = seed,
    model: engine.lastGeneratingModel.name,
    contextTokens: engine.contextSize,
    device: '${profile.soc.isEmpty ? 'unknown-soc' : profile.soc}/'
        '${profile.cores}c/${(profile.totalRamBytes ?? 0) ~/ (1 << 30)}GiB',
  );
  await harness.run(
    cases,
    gates: baseline?.gates ?? const EvalGates(),
    baseline: baseline,
    writeBaselineTo: await _baselinePath(writeBaseline.trim()),
    passes: passes < 1 ? 1 : passes,
  );
  FinnAccelerator.debugFixedSeed = null;
  await engine.releaseMemory();
}

/// A bare file name lands in the app's own files directory, which the app can
/// always write and `adb shell run-as` can always read; an absolute path is
/// used as given. External storage is not writable from a modern Android app.
Future<String?> _baselinePath(String requested) async {
  if (requested.isEmpty) return null;
  if (requested.startsWith('/')) return requested;
  final directory = await getApplicationSupportDirectory();
  return '${directory.path}/$requested';
}

/// The original candidate-model comparison kept from the pre-Phase-0 harness:
/// runs a fixed multilingual seed set against semicolon-delimited
/// `label=absolute/path/to/model.gguf` entries from `FINN_EVAL_MODELS`.
///
/// This is the one place a non-shipped GGUF can be measured. It never touches
/// the download catalog, and release builds refuse to load an unverified file.
Future<void> runCandidateModelEvaluation() async {
  const specification = String.fromEnvironment('FINN_EVAL_MODELS');
  if (specification.trim().isEmpty) {
    // ignore: avoid_print
    print('FINN_EVAL_ERROR FINN_EVAL_MODELS is empty');
    return;
  }
  const prompts = [
    'Come fare una torta salata con zucchine per 3 persone?',
    'Come fare una torta di mele?',
    'Come preparare una pizza margherita?',
    'Spiegami come cambiare una lampadina.',
    'Confronta iPhone 14 e Redmi Note 12.',
    'Translate this sentence into Italian: The train leaves at six.',
    'How can I upgrade the RAM in my laptop?',
    'How does the routing in Bridgetown work?',
    'How do living ants know that an ant has died?',
    'Come fare una torta di ricotta e fragole?',
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
  final engine = FinnAccelerator.instance;
  for (final entry in specification.split(';')) {
    final separator = entry.indexOf('=');
    if (separator <= 0) continue;
    final label = entry.substring(0, separator).trim();
    final path = entry.substring(separator + 1).trim();
    for (final index in selectedCases) {
      final prompt = prompts[index];
      final answer = StringBuffer();
      await for (final token in engine.generateEvaluationReply(
        prompt,
        path: path,
        modelLabel: label,
        tier: FinnModelTier.standard,
        conversationId: 'eval-$label-$index',
      )) {
        answer.write(token);
      }
      final analysis = const PromptIntentClassifier().classify(prompt);
      final report = engine.lastGenerationReport;
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
              if (prompt == 'How can I upgrade the RAM in my laptop?')
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
    await engine.releaseMemory();
  }
}
