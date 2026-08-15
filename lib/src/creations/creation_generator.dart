import 'dart:convert';

import '../inference/qwen_inference.dart';
import 'creation_model.dart';

abstract interface class CreationGenerator {
  Future<CreationDraft> generate(String prompt, CreationKind kind);
}

abstract interface class CancelableCreationGenerator {
  Future<void> cancel();
}

class QwenCreationGenerator
    implements CreationGenerator, CancelableCreationGenerator {
  QwenCreationGenerator({QwenInference? inference})
    : _inference = inference ?? QwenInference.instance;

  final QwenInference _inference;

  @override
  Future<CreationDraft> generate(String prompt, CreationKind kind) async {
    final output = StringBuffer();
    final request =
        '''
Create a concise, useful ${kind.label.toLowerCase()} concept from this brief:
"$prompt"

Return only valid JSON in this exact shape:
{"title":"short name","summary":"one sentence","sections":[{"heading":"...","body":"..."}]}
Use exactly 3 compact sections with one sentence per body. For apps and widgets cover experience, behavior and implementation. For presentations provide slide groups and key talking points. Keep the complete JSON under 140 words. Do not use markdown fences.
''';
    await for (final token in _inference.generateReply(
      request,
      conversationId:
          'creation-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
    )) {
      output.write(token);
    }
    return parseCreationDraft(output.toString(), prompt);
  }

  @override
  Future<void> cancel() => _inference.stopGeneration();
}

CreationDraft parseCreationDraft(String response, String fallbackPrompt) {
  final cleaned = response
      .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
      .replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
      .replaceAll('```', '')
      .trim();
  final start = cleaned.indexOf('{');
  final end = cleaned.lastIndexOf('}');
  if (start >= 0 && end > start) {
    try {
      final decoded = jsonDecode(cleaned.substring(start, end + 1));
      if (decoded is Map) {
        final map = Map<String, Object?>.from(decoded);
        final title = (map['title'] as String?)?.trim() ?? '';
        final summary = (map['summary'] as String?)?.trim() ?? '';
        final rawSections = map['sections'];
        final sections = rawSections is List
            ? rawSections
                  .whereType<Map>()
                  .map(
                    (item) => CreationSection.fromJson(
                      Map<String, Object?>.from(item),
                    ),
                  )
                  .where(
                    (section) =>
                        section.heading.isNotEmpty && section.body.isNotEmpty,
                  )
                  .take(6)
                  .toList(growable: false)
            : <CreationSection>[];
        if (title.isNotEmpty && (summary.isNotEmpty || sections.isNotEmpty)) {
          return CreationDraft(
            title: title,
            summary: summary,
            sections: sections,
          );
        }
      }
    } on FormatException {
      // Fall through to a useful text document if a small model missed JSON.
    }
  }

  // Small local models can hit their output budget immediately before the
  // final braces. Preserve any complete structured fields instead of exposing
  // raw, half-finished JSON in the UI.
  final recoveredTitle = _jsonStringField(cleaned, 'title');
  final recoveredSummary = _jsonStringField(cleaned, 'summary');
  final recoveredSections = _completeJsonSections(cleaned);
  if (recoveredTitle.isNotEmpty &&
      (recoveredSummary.isNotEmpty || recoveredSections.isNotEmpty)) {
    return CreationDraft(
      title: recoveredTitle,
      summary: recoveredSummary,
      sections: recoveredSections,
    );
  }

  final fallbackTitle = fallbackPrompt
      .trim()
      .split(RegExp(r'\s+'))
      .take(6)
      .join(' ');
  return CreationDraft(
    title: fallbackTitle.isEmpty ? 'Untitled creation' : fallbackTitle,
    summary: cleaned.isEmpty
        ? 'A local creation based on your brief.'
        : cleaned,
    sections: const [],
  );
}

String _jsonStringField(String source, String field) {
  final match = RegExp(
    '"${RegExp.escape(field)}"\\s*:\\s*("(?:\\\\.|[^"\\\\])*")',
  ).firstMatch(source);
  if (match == null) return '';
  try {
    return (jsonDecode(match.group(1)!) as String).trim();
  } on Object {
    return '';
  }
}

List<CreationSection> _completeJsonSections(String source) =>
    RegExp(
          r'\{\s*"heading"\s*:\s*("(?:\\.|[^"\\])*")\s*,\s*"body"\s*:\s*("(?:\\.|[^"\\])*")\s*\}',
        )
        .allMatches(source)
        .map((match) {
          try {
            return CreationSection(
              heading: (jsonDecode(match.group(1)!) as String).trim(),
              body: (jsonDecode(match.group(2)!) as String).trim(),
            );
          } on Object {
            return const CreationSection(heading: '', body: '');
          }
        })
        .where((section) {
          return section.heading.isNotEmpty && section.body.isNotEmpty;
        })
        .take(6)
        .toList(growable: false);
