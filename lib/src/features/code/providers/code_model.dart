import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/code/providers/code_provider.dart';

/// The request shapes a provider can speak. A model supports one or more.
enum CodeWire {
  /// `POST /chat/completions`, the OpenAI shape most providers copy.
  chatCompletions,

  /// `POST /messages`, the Anthropic shape.
  anthropicMessages,

  /// `POST /responses`, the newer OpenAI shape.
  responses;

  String get path => switch (this) {
        chatCompletions => '/chat/completions',
        anthropicMessages => '/messages',
        responses => '/responses',
      };

  static CodeWire? fromPath(String path) {
    for (final wire in values) {
      if (wire.path == path) return wire;
    }
    return null;
  }
}

/// One model a provider offers, as listed live by its `/models` endpoint.
@immutable
class CodeModel {
  const CodeModel({
    required this.provider,
    required this.id,
    required this.name,
    required this.wires,
    this.contextLength,
    this.free = false,
    this.promptPricePerMillion,
    this.completionPricePerMillion,
  });

  final CodeProvider provider;
  final String id;
  final String name;

  /// In the order to try them: the first that the provider accepts is used.
  final List<CodeWire> wires;
  final int? contextLength;

  /// Listed at no cost (OpenRouter `:free` models, OpenCode `-free` models).
  final bool free;

  /// US dollars per million tokens, when the provider publishes a price.
  final double? promptPricePerMillion;
  final double? completionPricePerMillion;

  CodeModelRef get ref => CodeModelRef(provider, id);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'wires': [for (final wire in wires) wire.name],
        if (contextLength != null) 'context': contextLength,
        if (free) 'free': true,
        if (promptPricePerMillion != null) 'in': promptPricePerMillion,
        if (completionPricePerMillion != null) 'out': completionPricePerMillion,
      };

  static CodeModel? fromJson(CodeProvider provider, Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final wires = <CodeWire>[
      for (final name in (json['wires'] as List?) ?? const [])
        for (final wire in CodeWire.values)
          if (wire.name == name) wire,
    ];
    return CodeModel(
      provider: provider,
      id: id,
      name: json['name'] is String ? json['name'] as String : id,
      wires: wires.isEmpty ? const [CodeWire.chatCompletions] : wires,
      contextLength: json['context'] is int ? json['context'] as int : null,
      free: json['free'] == true,
      promptPricePerMillion:
          json['in'] is num ? (json['in'] as num).toDouble() : null,
      completionPricePerMillion:
          json['out'] is num ? (json['out'] as num).toDouble() : null,
    );
  }
}

/// Turns each provider's `/models` response into [CodeModel]s.
///
/// The four listings differ: OpenRouter carries names, context and prices;
/// Command Code names the endpoints each model supports; OpenCode Zen and Go
/// list ids only. Parsers are pure so they are tested against recorded
/// responses.
abstract final class CodeModelParsers {
  /// OpenRouter: `data[].{id, name, context_length, pricing.{prompt,
  /// completion}}`, prices in dollars per token as strings.
  static List<CodeModel> openRouter(Object? body) => _list(body)
      .map((m) {
        final id = m['id'];
        if (id is! String) return null;
        final pricing = m['pricing'];
        double? perMillion(String key) {
          final raw = pricing is Map ? pricing[key] : null;
          final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
          return value == null || value < 0 ? null : value * 1e6;
        }

        final prompt = perMillion('prompt');
        final completion = perMillion('completion');
        return CodeModel(
          provider: CodeProvider.openRouter,
          id: id,
          name: _string(m['name']) ?? id,
          wires: const [CodeWire.chatCompletions],
          contextLength: m['context_length'] is int
              ? m['context_length'] as int
              : (m['context_length'] is num
                  ? (m['context_length'] as num).toInt()
                  : null),
          free: id.endsWith(':free') || (prompt == 0 && completion == 0),
          promptPricePerMillion: prompt,
          completionPricePerMillion: completion,
        );
      })
      .whereType<CodeModel>()
      .toList();

  /// Command Code: `data[].{id, name, context_length, supported_endpoints}`.
  /// The endpoints are authoritative, so no guessing is needed.
  static List<CodeModel> commandCode(Object? body) => _list(body)
      .map((m) {
        final id = m['id'];
        if (id is! String) return null;
        final wires = <CodeWire>[
          for (final path in (m['supported_endpoints'] as List?) ?? const [])
            if (path is String && CodeWire.fromPath(path) != null)
              CodeWire.fromPath(path)!,
        ];
        // Chat completions first: it is the shape the app streams best.
        wires.sort((a, b) => a.index.compareTo(b.index));
        return CodeModel(
          provider: CodeProvider.commandCode,
          id: id,
          name: _string(m['name']) ?? id,
          wires:
              wires.isEmpty ? guessWires(CodeProvider.commandCode, id) : wires,
          contextLength: m['context_length'] is num
              ? (m['context_length'] as num).toInt()
              : null,
        );
      })
      .whereType<CodeModel>()
      .toList();

  /// OpenCode Zen and Go list ids only, so the wire is inferred from the id.
  static List<CodeModel> openCode(CodeProvider provider, Object? body) =>
      _list(body)
          .map((m) {
            final id = m['id'];
            if (id is! String) return null;
            return CodeModel(
              provider: provider,
              id: id,
              name: id,
              wires: guessWires(provider, id),
              free: id.contains('-free') || id.endsWith('free'),
            );
          })
          .whereType<CodeModel>()
          .toList();

  /// A custom OpenAI-compatible server: `data[].id` over chat completions.
  static List<CodeModel> openAiCompatible(Object? body) => _list(body)
      .map((m) {
        final id = m['id'];
        if (id is! String) return null;
        return CodeModel(
          provider: CodeProvider.custom,
          id: id,
          name: id,
          wires: const [CodeWire.chatCompletions],
        );
      })
      .whereType<CodeModel>()
      .toList();

  /// Which request shape to try for a model whose listing does not say.
  ///
  /// OpenCode routes Claude models through `/messages` and GPT, Grok and Muse
  /// models through `/responses`; Qwen and (on Go) MiniMax also use
  /// `/messages`. Everything else is chat completions. The order is only the
  /// first guess: the gateway falls through to the next shape when a provider
  /// answers "wrong endpoint", so a wrong guess costs one rejected request.
  static List<CodeWire> guessWires(CodeProvider provider, String id) {
    final name = id.toLowerCase();
    if (name.startsWith('claude')) {
      return const [CodeWire.anthropicMessages, CodeWire.chatCompletions];
    }
    if (name.startsWith('gpt-') ||
        name.startsWith('grok') ||
        name.startsWith('muse') ||
        name.contains('codex')) {
      return const [CodeWire.responses, CodeWire.chatCompletions];
    }
    if (name.startsWith('qwen')) {
      final maxTier = name.contains('max');
      return maxTier && provider == CodeProvider.openCodeZen
          ? const [CodeWire.chatCompletions, CodeWire.anthropicMessages]
          : const [CodeWire.anthropicMessages, CodeWire.chatCompletions];
    }
    if (name.startsWith('minimax') && provider == CodeProvider.openCodeGo) {
      return const [CodeWire.anthropicMessages, CodeWire.chatCompletions];
    }
    return const [
      CodeWire.chatCompletions,
      CodeWire.anthropicMessages,
      CodeWire.responses,
    ];
  }

  static Iterable<Map<dynamic, dynamic>> _list(Object? body) {
    final data = body is Map ? body['data'] : body;
    if (data is! List) return const [];
    return data.whereType<Map<dynamic, dynamic>>();
  }

  static String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}
