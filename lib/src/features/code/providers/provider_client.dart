import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/providers/code_model.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/providers/code_wires.dart';
import 'package:finn_ai/src/features/code/providers/provider_errors.dart';

/// What is left to spend with a provider, as far as its API says.
@immutable
class ProviderAllowance {
  const ProviderAllowance({
    required this.fetchedAt,
    this.limit,
    this.remaining,
    this.used,
    this.usedToday,
    this.usedThisMonth,
    this.balance,
    this.freeTier,
    this.label,
  });

  final DateTime fetchedAt;

  /// Spend cap set on the key, in US dollars. Null when the key is uncapped.
  final double? limit;

  /// What is left under [limit].
  final double? remaining;

  /// All-time spend on this key.
  final double? used;
  final double? usedToday;
  final double? usedThisMonth;

  /// Account credit (purchased minus used). Only readable with a management
  /// key, so usually null.
  final double? balance;
  final bool? freeTier;

  /// The key's name on the provider's side.
  final String? label;

  bool get capped => limit != null;

  Map<String, Object?> toJson() => {
        'at': fetchedAt.toIso8601String(),
        if (limit != null) 'limit': limit,
        if (remaining != null) 'remaining': remaining,
        if (used != null) 'used': used,
        if (usedToday != null) 'today': usedToday,
        if (usedThisMonth != null) 'month': usedThisMonth,
        if (balance != null) 'balance': balance,
        if (freeTier != null) 'free': freeTier,
        if (label != null) 'label': label,
      };

  static ProviderAllowance? fromJson(Object? json) {
    if (json is! Map) return null;
    double? number(String key) =>
        json[key] is num ? (json[key] as num).toDouble() : null;
    return ProviderAllowance(
      fetchedAt: DateTime.tryParse('${json['at']}') ?? DateTime.now(),
      limit: number('limit'),
      remaining: number('remaining'),
      used: number('used'),
      usedToday: number('today'),
      usedThisMonth: number('month'),
      balance: number('balance'),
      freeTier: json['free'] is bool ? json['free'] as bool : null,
      label: json['label'] is String ? json['label'] as String : null,
    );
  }
}

/// Talks HTTP to the providers: the live model list, the allowance, a key
/// check, and streaming a reply.
class CodeProviderClient {
  CodeProviderClient({http.Client? client, DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;

  static const Duration _listTimeout = Duration(seconds: 20);
  static const Duration _connectTimeout = Duration(seconds: 45);
  static const Duration _idleTimeout = Duration(seconds: 90);

  void close() => _client.close();

  Map<String, String> _headers(String? apiKey) {
    final key = apiKey?.trim() ?? '';
    return {
      'accept': 'application/json',
      if (key.isNotEmpty) 'authorization': 'Bearer $key',
    };
  }

  Uri _uri(String baseUrl, String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }

  /// Fetches the provider's current model list. Throws [ProviderException].
  Future<List<CodeModel>> listModels(
    CodeProvider provider, {
    required String baseUrl,
    String? apiKey,
  }) async {
    final response = await _get(_uri(baseUrl, '/models'), apiKey);
    final Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw const ProviderException(ProviderFailure.malformed);
    }
    final models = switch (provider) {
      CodeProvider.openRouter => CodeModelParsers.openRouter(body),
      CodeProvider.commandCode => CodeModelParsers.commandCode(body),
      CodeProvider.openCodeZen ||
      CodeProvider.openCodeGo =>
        CodeModelParsers.openCode(provider, body),
      _ => CodeModelParsers.openAiCompatible(body),
    };
    if (models.isEmpty) {
      throw const ProviderException(ProviderFailure.malformed);
    }
    return models;
  }

  /// OpenRouter's key report (`GET /key`), plus the account balance when the
  /// key is allowed to read it (`GET /credits`, management keys only).
  Future<ProviderAllowance> openRouterAllowance({
    required String baseUrl,
    required String apiKey,
  }) async {
    final response = await _get(_uri(baseUrl, '/key'), apiKey);
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ProviderException(ProviderFailure.malformed);
    }
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Map) throw const ProviderException(ProviderFailure.malformed);
    double? number(String key) =>
        data[key] is num ? (data[key] as num).toDouble() : null;

    double? balance;
    try {
      final credits = await _get(_uri(baseUrl, '/credits'), apiKey);
      final body = jsonDecode(credits.body);
      final inner = body is Map ? body['data'] : null;
      if (inner is Map &&
          inner['total_credits'] is num &&
          inner['total_usage'] is num) {
        balance = (inner['total_credits'] as num).toDouble() -
            (inner['total_usage'] as num).toDouble();
      }
    } on ProviderException {
      // An ordinary key may not read the balance; the key report is enough.
    } on FormatException {
      // Same: optional.
    }

    return ProviderAllowance(
      fetchedAt: _clock(),
      limit: number('limit'),
      remaining: number('limit_remaining'),
      used: number('usage'),
      usedToday: number('usage_daily'),
      usedThisMonth: number('usage_monthly'),
      balance: balance,
      freeTier:
          data['is_free_tier'] is bool ? data['is_free_tier'] as bool : null,
      label: data['label'] is String ? data['label'] as String : null,
    );
  }

  /// Checks that a key works by asking for one token.
  ///
  /// Model listings are public on most providers, so they prove nothing about
  /// a key; only a real request does. It costs a fraction of a cent, and only
  /// runs when the user taps "Test".
  Future<void> testKey(CodeModel model,
      {required String baseUrl, String? apiKey}) async {
    final completion = const CodeCompletion(
      system: 'Reply with one word.',
      turns: [CodeTurn.user('Hi')],
      conversationId: 'test',
      maxTokens: 8,
    );
    await for (final _ in stream(
      model,
      baseUrl: baseUrl,
      apiKey: apiKey,
      completion: completion,
    )) {
      return; // The first fragment is proof enough.
    }
  }

  Future<http.Response> _get(Uri uri, String? apiKey) async {
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: _headers(apiKey))
          .timeout(_listTimeout);
    } on TimeoutException {
      throw const ProviderException(ProviderFailure.timeout);
    } on SocketException {
      throw const ProviderException(ProviderFailure.network);
    } on http.ClientException {
      throw const ProviderException(ProviderFailure.network);
    } on HandshakeException {
      throw const ProviderException(ProviderFailure.network);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw ProviderException.fromResponse(
      _providerFor(uri),
      response.statusCode,
      response.body,
    );
  }

  CodeProvider _providerFor(Uri uri) {
    final host = uri.host;
    if (host.contains('openrouter')) return CodeProvider.openRouter;
    if (host.contains('commandcode')) return CodeProvider.commandCode;
    if (host.contains('opencode')) {
      return uri.path.contains('/go/')
          ? CodeProvider.openCodeGo
          : CodeProvider.openCodeZen;
    }
    return CodeProvider.custom;
  }

  /// Streams a reply from [model].
  ///
  /// The model's request shapes are tried in order. A provider that answers
  /// "wrong endpoint" before sending any text moves on to the next shape, and
  /// [onWire] is told which shape finally worked so the choice is remembered.
  /// Any other failure (a bad key, no credit) is thrown at once: another shape
  /// would meet the same wall. If every shape says "wrong endpoint", that last
  /// answer is thrown.
  Stream<String> stream(
    CodeModel model, {
    required String baseUrl,
    required CodeCompletion completion,
    String? apiKey,
    void Function(CodeWire wire)? onWire,
  }) async* {
    ProviderException? last;
    for (final wire in model.wires) {
      var started = false;
      try {
        await for (final fragment in _streamOnce(
          model,
          wire,
          baseUrl: baseUrl,
          completion: completion,
          apiKey: apiKey,
        )) {
          if (!started) {
            started = true;
            onWire?.call(wire);
          }
          yield fragment;
        }
        if (!started) onWire?.call(wire);
        return;
      } on ProviderException catch (error) {
        // Once text has been shown the shape is the right one; a failure now
        // belongs to the reply, not to routing.
        if (started || !error.triesNextWire) rethrow;
        last = error;
      }
    }
    throw last ?? const ProviderException(ProviderFailure.unknown);
  }

  Stream<String> _streamOnce(
    CodeModel model,
    CodeWire wire, {
    required String baseUrl,
    required CodeCompletion completion,
    String? apiKey,
  }) async* {
    final request = CodeWires.buildRequest(
      wire,
      provider: model.provider,
      baseUrl: baseUrl,
      modelId: model.id,
      completion: completion,
      apiKey: apiKey,
    );
    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(_connectTimeout);
    } on TimeoutException {
      throw const ProviderException(ProviderFailure.timeout);
    } on SocketException {
      throw const ProviderException(ProviderFailure.network);
    } on http.ClientException {
      throw const ProviderException(ProviderFailure.network);
    } on HandshakeException {
      throw const ProviderException(ProviderFailure.network);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw ProviderException.fromResponse(
        model.provider,
        response.statusCode,
        body,
      );
    }
    try {
      yield* CodeWires.text(wire, response.stream.timeout(_idleTimeout));
    } on TimeoutException {
      throw const ProviderException(ProviderFailure.timeout);
    } on SocketException {
      throw const ProviderException(ProviderFailure.network);
    } on http.ClientException {
      throw const ProviderException(ProviderFailure.network);
    }
  }
}
