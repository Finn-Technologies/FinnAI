import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_prompts.dart';
import 'package:finn_ai/src/features/creations/json_salvage.dart';
import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/spec_validator.dart';
import 'package:finn_ai/src/features/creations/spec/widget_spec.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/prompt_intent.dart';

/// Where a creation job currently is, for the progress bubble.
enum CreationStage { designing, writing, validating, repairing }

/// A finished generation: the artifact plus the metadata the tile needs.
@immutable
class CreationOutcome {
  const CreationOutcome({
    required this.title,
    required this.summary,
    required this.artifact,
  });

  final String title;
  final String summary;
  final CreationArtifact artifact;
}

abstract interface class CreationGenerator {
  Future<CreationOutcome> generate({
    required String prompt,
    required CreationKind kind,
    required void Function(CreationStage stage) onStage,
  });
}

abstract interface class CancelableCreationGenerator {
  Future<void> cancel();
}

/// Raised when the user cancels a creation mid-flight.
///
/// Distinct from a failure: the controller turns this into a quiet "stopped"
/// turn rather than an error, and the attempt loop stops instead of starting
/// the repair round the user just cancelled.
class CreationCancelled implements Exception {
  const CreationCancelled();
}

/// Raised when the model could not produce a valid creation, even after a
/// repair round. The page shows a retry; nothing generic is substituted.
class CreationUnusable implements Exception {
  const CreationUnusable(this.reason);

  /// Why the last attempt was rejected, for the debug log only.
  final String reason;

  @override
  String toString() => 'CreationUnusable: $reason';
}

/// Produces the raw model text for one creation request.
///
/// Injected so the parse → validate → repair pipeline can be tested without a
/// native engine, which is where the reliability of the feature lives.
typedef CreationCompletion = Future<String> Function(String request);

/// Has the on-device model design a creation, then validates it.
///
/// The model is the author. One call writes the whole artifact in the closed
/// vocabulary; [SpecValidator] decides whether it can run. A rejected reply
/// earns one repair round that quotes the exact problems back. If that also
/// fails the job throws [CreationUnusable] and the user is asked to try again.
/// Nothing is swapped for a generic stand-in.
class FinnCreationGenerator
    implements CreationGenerator, CancelableCreationGenerator {
  FinnCreationGenerator({
    FinnInference? inference,
    CreationCompletion? complete,
    this.maxRepairRounds = 1,
  })  : _inference = inference ?? FinnInference.instance,
        _overrideCompletion = complete;

  /// Creative enough to design something new, still steady enough to emit
  /// valid JSON. The earlier near-zero setting is why every creation came out
  /// alike: the model kept choosing the same most-likely content.
  static const IntentSamplerProfile sampler = IntentSamplerProfile(
    temperature: .7,
    topK: 40,
    topP: .92,
    minP: .05,
    repeatPenalty: 1.1,
    penaltyLastN: 256,
  );

  /// A repair round is about fixing a known problem, not inventing, so it runs
  /// cooler than the first pass and is more likely to emit exactly the shape
  /// the validator asked for.
  static const IntentSamplerProfile repairSampler = IntentSamplerProfile(
    temperature: .3,
    topK: 20,
    topP: .85,
    minP: .05,
    repeatPenalty: 1.05,
    penaltyLastN: 128,
  );

  final FinnInference _inference;
  final CreationCompletion? _overrideCompletion;

  /// How many times a rejected creation is re-prompted before giving up.
  final int maxRepairRounds;

  /// Set by [cancel] and read inside the attempt loop, so a cancel stops the
  /// job instead of letting it spend a second full generation on a repair.
  bool _cancelled = false;

  /// Stable for one job, so a repair attempt reuses the KV of the attempt it is
  /// repairing. A per-attempt id forced a cold prefill and evicted the user's
  /// chat session, because the session cache holds exactly one entry.
  String _conversationId = 'creation';

  @override
  Future<CreationOutcome> generate({
    required String prompt,
    required CreationKind kind,
    required void Function(CreationStage stage) onStage,
  }) async {
    _cancelled = false;
    _conversationId =
        'creation-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    var issues = '';
    for (var attempt = 0; attempt <= maxRepairRounds; attempt++) {
      if (_cancelled) throw const CreationCancelled();
      onStage(attempt == 0 ? CreationStage.designing : CreationStage.repairing);
      final request = CreationPrompts.build(
        kind: kind,
        brief: prompt,
        repairIssues: attempt == 0 ? null : issues,
      );
      if (_cancelled) throw const CreationCancelled();
      onStage(CreationStage.writing);
      final raw = await _complete(request, attempt == 0);
      if (_cancelled) throw const CreationCancelled();
      final decoded = extractJsonObject(raw);
      if (decoded == null) {
        issues = 'The reply was not a JSON object.';
        continue;
      }
      onStage(CreationStage.validating);
      final found = _validate(kind, decoded);
      if (found.isNotEmpty) {
        issues = SpecValidator.describeIssues(found);
        continue;
      }
      try {
        return _build(kind, decoded, prompt);
      } on Object catch (error) {
        issues = 'The JSON could not be read: $error';
      }
    }
    throw CreationUnusable(issues);
  }

  static List<SpecIssue> _validate(
    CreationKind kind,
    Map<String, Object?> json,
  ) =>
      switch (kind) {
        CreationKind.app => SpecValidator.validateMiniApp(json),
        CreationKind.widget => SpecValidator.validateHomeWidget(json),
        CreationKind.presentation => SpecValidator.validateDeck(json),
      };

  static CreationOutcome _build(
    CreationKind kind,
    Map<String, Object?> json,
    String prompt,
  ) {
    final title = _titleFrom(json, prompt);
    final summary = _summaryFrom(json);
    final artifact = switch (kind) {
      CreationKind.app => MiniAppArtifact(MiniAppSpec.fromJson(json)),
      CreationKind.widget => WidgetArtifact(HomeWidgetSpec.fromJson(json)),
      CreationKind.presentation => PresentationArtifact(
          DeckSpec.fromJson(json),
        ),
    };
    return CreationOutcome(title: title, summary: summary, artifact: artifact);
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await _inference.stopGeneration();
  }

  Future<String> _complete(String request, bool creative) =>
      _overrideCompletion?.call(request) ??
      _engineComplete(request, creative: creative);

  Future<String> _engineComplete(
    String request, {
    required bool creative,
  }) async {
    final output = StringBuffer();
    await for (final token in _inference.generateReplyQueued(
      request,
      // A dedicated conversation id keeps the creation prompt out of the user's
      // chat session. Queued rather than direct so a creation started while a
      // chat answer is streaming waits for the engine instead of failing.
      conversationId: _conversationId,
      samplerProfile: creative ? sampler : repairSampler,
    )) {
      output.write(token);
    }
    final raw = output.toString();
    if (!kReleaseMode) {
      // Debug/profile only: telling a bad prompt from a bad parse needs the
      // text the model produced, which must never reach a production log.
      debugPrint(
        'FINN_CREATION_RAW chars=${raw.length} '
        'head=${raw.length > 400 ? raw.substring(0, 400) : raw}',
      );
    }
    return raw;
  }
}

String _titleFrom(Map<String, Object?> json, String prompt) {
  final raw = json['title'];
  if (raw is String && raw.trim().isNotEmpty) {
    return _clampTitle(raw.trim());
  }
  return titleFromPrompt(prompt);
}

String _summaryFrom(Map<String, Object?> json) {
  final raw = json['summary'];
  if (raw is! String) return '';
  final trimmed = raw.trim();
  if (trimmed.length <= 160) return trimmed;
  return '${trimmed.substring(0, 160).trimRight()}…';
}

String _clampTitle(String title) =>
    title.length <= 60 ? title : '${title.substring(0, 60).trimRight()}…';

/// Derives a readable title from a brief when the model did not supply one.
String titleFromPrompt(String prompt) {
  final words = prompt
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(6)
      .toList(growable: false);
  if (words.isEmpty) return 'New creation';
  final joined = words.join(' ').replaceAll(RegExp(r'[.,;:!?]+$'), '');
  if (joined.isEmpty) return 'New creation';
  return _clampTitle('${joined[0].toUpperCase()}${joined.substring(1)}');
}
