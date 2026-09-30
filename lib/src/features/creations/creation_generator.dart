import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/creations/creation_fallbacks.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_prompts.dart';
import 'package:finn_ai/src/features/creations/json_salvage.dart';
import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';
import 'package:finn_ai/src/features/creations/spec/spec_validator.dart';
import 'package:finn_ai/src/features/creations/templates/creation_template.dart';
import 'package:finn_ai/src/features/creations/templates/slot_prompt.dart';
import 'package:finn_ai/src/features/creations/templates/template_catalog.dart';
import 'package:finn_ai/src/features/creations/templates/template_slots.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/prompt_intent.dart';

/// Where a creation job currently is, for the progress bubble.
enum CreationStage {
  designing,
  writing,
  validating,
  repairing,
}

/// A finished generation: the artifact plus the metadata the tile needs.
@immutable
class CreationOutcome {
  const CreationOutcome({
    required this.title,
    required this.summary,
    required this.artifact,
    required this.usedFallback,
    this.template,
  });

  final String title;
  final String summary;
  final CreationArtifact artifact;

  /// The template and slot values behind [artifact], so it can be edited later
  /// without the model. Null for a presentation, which is free-form.
  final TemplateRef? template;

  /// True when the model could not produce a valid spec and a deterministic
  /// starter was substituted. Surfaced as a non-blocking note, not an error.
  final bool usedFallback;
}

abstract interface class CreationGenerator {
  Future<CreationOutcome> generate({
    required String prompt,
    required CreationKind kind,
    required void Function(CreationStage stage) onStage,
    String? templateId,
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

/// Produces the raw model text for one creation request.
///
/// Injected so the parse → validate → repair → fallback pipeline can be tested
/// exhaustively without a native engine, which is where the reliability of the
/// whole feature actually lives.
typedef CreationCompletion = Future<String> Function(String request);

/// Generates a creation spec with the on-device model, then validates and
/// repairs it.
///
/// The model writes the spec; the validator decides whether it is usable. That
/// split is what makes this safe to ship against a 1.6B model: a malformed spec
/// costs one repair round, and a second failure costs a deterministic starter
/// rather than an error.
class FinnCreationGenerator
    implements CreationGenerator, CancelableCreationGenerator {
  FinnCreationGenerator({
    FinnInference? inference,
    CreationCompletion? complete,
    this.maxRepairRounds = 1,
  })  : _inference = inference ?? FinnInference.instance,
        _overrideCompletion = complete;

  /// Near-deterministic decoding: the output has to parse as JSON, so there is
  /// nothing to gain from creative sampling and a lot to lose.
  static const IntentSamplerProfile sampler = IntentSamplerProfile(
    temperature: .15,
    topK: 20,
    topP: .85,
    minP: .05,
    repeatPenalty: 1.05,
    penaltyLastN: 128,
  );

  final FinnInference _inference;
  final CreationCompletion? _overrideCompletion;

  /// How many times a rejected spec is re-prompted before falling back.
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
    String? templateId,
  }) async {
    _cancelled = false;
    _conversationId =
        'creation-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    return kind == CreationKind.presentation
        ? _generateDeck(prompt, onStage)
        : _generateFromTemplate(prompt, kind, onStage, templateId);
  }

  /// Apps and widgets: the app chooses the template, the model fills its slots
  /// (ADR 0003). A reply can be wrong in content but never in structure, so the
  /// only failure is "nothing usable", which earns one more try and then a
  /// template filled from the brief instead of a generic starter.
  Future<CreationOutcome> _generateFromTemplate(
    String prompt,
    CreationKind kind,
    void Function(CreationStage stage) onStage,
    String? templateId,
  ) async {
    final requested = CreationTemplates.byId(templateId);
    final template = requested != null && requested.kind == kind
        ? requested
        : CreationTemplates.pick(kind, prompt);
    String? note;
    for (var attempt = 0; attempt <= maxRepairRounds; attempt++) {
      if (_cancelled) throw const CreationCancelled();
      onStage(attempt == 0 ? CreationStage.designing : CreationStage.repairing);
      final request = SlotPrompt.build(
        template: template,
        brief: prompt,
        repairNote: note,
      );
      if (_cancelled) throw const CreationCancelled();
      onStage(CreationStage.writing);
      final raw = await _complete(request);
      if (_cancelled) throw const CreationCancelled();
      final decoded = extractJsonObject(raw);
      if (decoded == null) {
        note = 'it was not a JSON object';
        continue;
      }
      onStage(CreationStage.validating);
      if (SlotSanitizer.usable(template.slots, decoded) == 0) {
        note = 'none of the keys had a usable value';
        continue;
      }
      return _fromSlots(template, decoded, prompt, usedFallback: false);
    }
    debugPrint(
      'FINN_CREATION fallback to template ${template.id} after '
      '$maxRepairRounds repair round(s): $note',
    );
    return _fromSlots(template, const {}, prompt, usedFallback: true);
  }

  CreationOutcome _fromSlots(
    CreationTemplate template,
    Map<String, Object?> raw,
    String prompt, {
    required bool usedFallback,
  }) {
    final withTitle = {
      ...raw,
      if (raw['title'] == null || '${raw['title']}'.trim().isEmpty)
        'title': titleFromPrompt(prompt),
    };
    final values = SlotSanitizer.sanitize(template.slots, withTitle);
    return CreationOutcome(
      title: template.titleFor(values),
      summary: template.summaryFor(values),
      artifact: template.build(values),
      usedFallback: usedFallback,
      template: TemplateRef(id: template.id, slots: values.toJson()),
    );
  }

  /// Presentations stay free-form (a deck is prose, not wiring): the model
  /// writes the slides, the validator decides, and one repair round follows.
  Future<CreationOutcome> _generateDeck(
    String prompt,
    void Function(CreationStage stage) onStage,
  ) async {
    var issues = const <SpecIssue>[];
    for (var attempt = 0; attempt <= maxRepairRounds; attempt++) {
      if (_cancelled) throw const CreationCancelled();
      onStage(attempt == 0 ? CreationStage.designing : CreationStage.repairing);
      final request = CreationPrompts.build(
        brief: prompt,
        repairIssues:
            attempt == 0 ? null : SpecValidator.describeIssues(issues),
      );
      if (_cancelled) throw const CreationCancelled();
      onStage(CreationStage.writing);
      final raw = await _complete(request);
      if (_cancelled) throw const CreationCancelled();
      final decoded = extractJsonObject(raw);
      if (decoded == null) {
        issues = const [SpecIssue('', 'the reply was not a JSON object')];
        continue;
      }
      onStage(CreationStage.validating);
      issues = SpecValidator.validateDeck(decoded);
      if (issues.isNotEmpty) continue;
      try {
        return CreationOutcome(
          title: _titleFrom(decoded, prompt),
          summary: _summaryFrom(decoded),
          artifact: PresentationArtifact(DeckSpec.fromJson(decoded)),
          usedFallback: false,
        );
      } on Object catch (error) {
        issues = [SpecIssue('', 'the JSON could not be read: $error')];
      }
    }
    debugPrint(
      'FINN_CREATION deck fallback after $maxRepairRounds repair round(s): '
      '${SpecValidator.describeIssues(issues)}',
    );
    return CreationOutcome(
      title: titleFromPrompt(prompt),
      summary: '',
      artifact: CreationFallbacks.starterDeck(),
      usedFallback: true,
    );
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await _inference.stopGeneration();
  }

  Future<String> _complete(String request) =>
      _overrideCompletion?.call(request) ?? _engineComplete(request);

  Future<String> _engineComplete(String request) async {
    final output = StringBuffer();
    await for (final token in _inference.generateReplyQueued(
      request,
      // A dedicated conversation id keeps the creation prompt out of the user's
      // chat session. Queued rather than direct so a creation started while a
      // chat answer is streaming waits for the engine instead of failing.
      conversationId: _conversationId,
      // The shared system prompt advertises browser tools; a creation turn must
      // never spend its budget on a search decision pass.
      samplerProfile: sampler,
    )) {
      output.write(token);
    }
    final raw = output.toString();
    if (!kReleaseMode) {
      // Debug/profile only. Telling a bad prompt apart from a bad parse needs
      // the text the model actually produced, and that must never reach a
      // production log.
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
