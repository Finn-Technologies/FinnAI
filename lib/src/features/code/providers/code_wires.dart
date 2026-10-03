import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/providers/code_model.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/providers/provider_errors.dart';

/// Builds a streaming request for each request shape, and reads the stream
/// each one answers with. Pure, so both directions are tested against the
/// exact payloads providers send.
abstract final class CodeWires {
  static const String anthropicVersion = '2023-06-01';

  /// Joins consecutive turns from the same role. Anthropic rejects two user
  /// messages in a row and other providers treat them oddly; the agent loop
  /// never produces them, but a skipped action can leave a pair behind.
  static List<CodeTurn> alternating(List<CodeTurn> turns) {
    final merged = <CodeTurn>[];
    for (final turn in turns) {
      if (turn.content.trim().isEmpty) continue;
      if (merged.isNotEmpty && merged.last.role == turn.role) {
        merged[merged.length - 1] =
            CodeTurn(turn.role, '${merged.last.content}\n\n${turn.content}');
      } else {
        merged.add(turn);
      }
    }
    // Every shape wants the conversation to open with the user.
    while (merged.isNotEmpty && merged.first.role != 'user') {
      merged.removeAt(0);
    }
    return merged;
  }

  static http.Request buildRequest(
    CodeWire wire, {
    required CodeProvider provider,
    required String baseUrl,
    required String modelId,
    required CodeCompletion completion,
    String? apiKey,
  }) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final request = http.Request('POST', Uri.parse('$root${wire.path}'));
    final key = apiKey?.trim() ?? '';
    request.headers.addAll({
      'content-type': 'application/json',
      'accept': 'text/event-stream',
      if (key.isNotEmpty) 'authorization': 'Bearer $key',
      if (wire == CodeWire.anthropicMessages) ...{
        if (key.isNotEmpty) 'x-api-key': key,
        'anthropic-version': anthropicVersion,
      },
      if (provider == CodeProvider.openRouter) 'x-title': 'FinnAI Code',
    });
    final turns = alternating(completion.turns);
    final body = switch (wire) {
      CodeWire.chatCompletions => {
          'model': modelId,
          'stream': true,
          'max_tokens': completion.maxTokens,
          'messages': [
            {'role': 'system', 'content': completion.system},
            for (final turn in turns)
              {'role': turn.role, 'content': turn.content},
          ],
        },
      CodeWire.anthropicMessages => {
          'model': modelId,
          'stream': true,
          'max_tokens': completion.maxTokens,
          'system': completion.system,
          'messages': [
            for (final turn in turns)
              {'role': turn.role, 'content': turn.content},
          ],
        },
      CodeWire.responses => {
          'model': modelId,
          'stream': true,
          'max_output_tokens': completion.maxTokens,
          'instructions': completion.system,
          'input': [
            for (final turn in turns)
              {'role': turn.role, 'content': turn.content},
          ],
        },
    };
    request.body = jsonEncode(body);
    return request;
  }

  /// Splits a server-sent-events body into its events.
  static Stream<SseEvent> events(Stream<List<int>> bytes) async* {
    String? name;
    final data = <String>[];
    final lines = bytes
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (line.isEmpty) {
        if (data.isNotEmpty) yield SseEvent(name, data.join('\n'));
        name = null;
        data.clear();
      } else if (line.startsWith(':')) {
        continue;
      } else if (line.startsWith('event:')) {
        name = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        final value = line.substring(5);
        data.add(value.startsWith(' ') ? value.substring(1) : value);
      }
    }
    if (data.isNotEmpty) yield SseEvent(name, data.join('\n'));
  }

  /// The text fragments a streaming reply carries.
  ///
  /// Anything that is not text (reasoning, usage, pings) is skipped. An error
  /// event, which providers send in-band after a 200, is thrown.
  static Stream<String> text(CodeWire wire, Stream<List<int>> bytes) async* {
    await for (final event in events(bytes)) {
      final data = event.data.trim();
      if (data == '[DONE]') return;
      final Object? json;
      try {
        json = jsonDecode(data);
      } on FormatException {
        continue;
      }
      if (json is! Map) continue;
      final fragment = switch (wire) {
        CodeWire.chatCompletions => _chatDelta(json),
        CodeWire.anthropicMessages => _anthropicDelta(json, event.name),
        CodeWire.responses => _responsesDelta(json, event.name),
      };
      if (fragment != null && fragment.isNotEmpty) yield fragment;
      if (_isStop(wire, json, event.name)) return;
    }
  }

  static String? _chatDelta(Map<dynamic, dynamic> json) {
    _throwIfError(json);
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final delta = first['delta'];
    if (delta is Map && delta['content'] is String) {
      return delta['content'] as String;
    }
    return null;
  }

  static String? _anthropicDelta(Map<dynamic, dynamic> json, String? name) {
    final type = json['type'] ?? name;
    if (type == 'error') _throwIfError(json);
    if (type != 'content_block_delta') return null;
    final delta = json['delta'];
    if (delta is Map && delta['type'] == 'text_delta') {
      final text = delta['text'];
      if (text is String) return text;
    }
    return null;
  }

  static String? _responsesDelta(Map<dynamic, dynamic> json, String? name) {
    final type = json['type'] ?? name;
    if (type == 'error') _throwIfError(json);
    if (type == 'response.failed') {
      final response = json['response'];
      final error = response is Map ? response['error'] : null;
      throw ProviderException(
        ProviderFailure.server,
        detail: error is Map && error['message'] is String
            ? error['message'] as String
            : '',
      );
    }
    if (type == 'response.output_text.delta' && json['delta'] is String) {
      return json['delta'] as String;
    }
    return null;
  }

  static bool _isStop(
    CodeWire wire,
    Map<dynamic, dynamic> json,
    String? name,
  ) =>
      switch (wire) {
        CodeWire.chatCompletions => false,
        CodeWire.anthropicMessages => (json['type'] ?? name) == 'message_stop',
        CodeWire.responses => (json['type'] ?? name) == 'response.completed',
      };

  static void _throwIfError(Map<dynamic, dynamic> json) {
    final error = json['error'];
    if (error == null) return;
    var message = '';
    if (error is Map && error['message'] is String) {
      message = error['message'] as String;
    } else if (error is String) {
      message = error;
    }
    throw ProviderException(ProviderFailure.server, detail: message);
  }
}

/// One server-sent event: an optional name and its data.
class SseEvent {
  const SseEvent(this.name, this.data);

  final String? name;
  final String data;
}
