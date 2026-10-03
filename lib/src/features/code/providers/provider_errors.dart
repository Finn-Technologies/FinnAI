import 'dart:convert';

import 'package:finn_ai/src/features/code/providers/code_provider.dart';

/// What went wrong talking to a provider, in terms the screen can explain.
enum ProviderFailure {
  /// The key is missing, wrong or revoked.
  auth,

  /// Command Code's Go plan has no API access: it needs GOAT or higher.
  planNoApi,

  /// Out of credit.
  paymentRequired,
  rateLimited,

  /// The provider does not serve this model on this request shape.
  wrongEndpoint,
  badRequest,
  server,
  network,
  timeout,

  /// The reply was not in a shape the app understands.
  malformed,
  unknown,
}

class ProviderException implements Exception {
  const ProviderException(this.failure, {this.statusCode, this.detail = ''});

  final ProviderFailure failure;
  final int? statusCode;

  /// The provider's own words, shortened. Never contains the API key: the key
  /// is only ever sent in a header and is not part of any message here.
  final String detail;

  /// True when the model might work on another request shape.
  bool get triesNextWire => failure == ProviderFailure.wrongEndpoint;

  /// Classifies an error response.
  factory ProviderException.fromResponse(
    CodeProvider provider,
    int status,
    String body,
  ) {
    final detail = _messageOf(body);
    final lower = detail.toLowerCase();
    // Verified against Command Code's docs: "You're on the Go plan, the only
    // plan without API access. Upgrade to GOAT or higher."
    if (provider == CodeProvider.commandCode &&
        lower.contains('go plan') &&
        lower.contains('api access')) {
      return ProviderException(
        ProviderFailure.planNoApi,
        statusCode: status,
        detail: detail,
      );
    }
    final failure = switch (status) {
      401 || 403 => ProviderFailure.auth,
      402 => ProviderFailure.paymentRequired,
      429 => ProviderFailure.rateLimited,
      404 || 405 || 415 || 422 => ProviderFailure.wrongEndpoint,
      400 => _looksLikeWrongEndpoint(lower)
          ? ProviderFailure.wrongEndpoint
          : ProviderFailure.badRequest,
      >= 500 => ProviderFailure.server,
      _ => ProviderFailure.unknown,
    };
    return ProviderException(failure, statusCode: status, detail: detail);
  }

  static bool _looksLikeWrongEndpoint(String message) =>
      message.contains('endpoint') ||
      message.contains('not supported') ||
      message.contains('unsupported') ||
      message.contains('/messages') ||
      message.contains('/responses') ||
      message.contains('chat/completions');

  /// The human-readable part of the error body, whichever shape it has:
  /// OpenAI `{error:{message}}`, Command Code `{success:false,error:{message}}`,
  /// Anthropic `{type:error,error:{message}}`, or plain text.
  static String _messageOf(String body) {
    final text = body.trim();
    if (text.isEmpty) return '';
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return _shorten(error['message'] as String);
        }
        if (error is String) return _shorten(error);
        if (decoded['message'] is String) {
          return _shorten(decoded['message'] as String);
        }
      }
    } on FormatException {
      // Not JSON: use the text as it is.
    }
    return _shorten(text);
  }

  static String _shorten(String text) {
    final line = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return line.length <= 300 ? line : '${line.substring(0, 300)}…';
  }

  @override
  String toString() => 'ProviderException($failure, $statusCode, $detail)';
}
