import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Report categories aligned with Google Play generative AI content policies.
enum ReportCategory {
  harmfulOrDangerous('Harmful or dangerous'),
  hateOrHarassment('Hate or harassment'),
  sexualContent('Sexual content'),
  childSafety('Child-safety concern'),
  selfHarm('Self-harm concern'),
  illegalOrDeceptive('Illegal or deceptive guidance'),
  falseOrMisleading('False or misleading response'),
  other('Other');

  const ReportCategory(this.displayName);
  final String displayName;
}

enum ReportSubmitStatus {
  success,
  unconfigured,
  networkError,
  badRequest,
  rateLimited,
  serverError,
  invalidEndpoint,
}

class ReportPayload {
  const ReportPayload({
    required this.reportId,
    required this.category,
    required this.assistantResponse,
    required this.timestamp,
    required this.appVersion,
    required this.modelTier,
    this.userPrompt,
    this.additionalDetails,
  });

  final String reportId;
  final ReportCategory category;
  final String assistantResponse;
  final DateTime timestamp;
  final String appVersion;
  final String modelTier;
  final String? userPrompt;
  final String? additionalDetails;

  Map<String, dynamic> toJson() => {
    'reportId': reportId,
    'category': category.name,
    'assistantResponse': assistantResponse,
    'timestamp': timestamp.toIso8601String(),
    'appVersion': appVersion,
    'modelTier': modelTier,
    if (userPrompt != null && userPrompt!.isNotEmpty) 'userPrompt': userPrompt,
    if (additionalDetails != null && additionalDetails!.isNotEmpty)
      'additionalDetails': additionalDetails,
  };
}

class ReportService {
  ReportService({
    String? endpoint,
    http.Client? client,
    this._isReleaseModeOverride,
  }) : _customEndpoint = endpoint,
       _client = client ?? http.Client();

  static final ReportService instance = ReportService();
  final String? _customEndpoint;
  final http.Client _client;
  final bool? _isReleaseModeOverride;

  String get endpoint =>
      _customEndpoint?.trim() ??
      const String.fromEnvironment(
        'FINN_REPORT_ENDPOINT',
        defaultValue: 'https://finn-org.vercel.app/v1/reports',
      ).trim();

  bool get isConfigured => endpoint.isNotEmpty;

  /// Submits an in-app AI response report.
  Future<ReportSubmitStatus> submitReport(ReportPayload payload) async {
    final ep = endpoint;

    if (ep.isEmpty) {
      return ReportSubmitStatus.unconfigured;
    }

    final uri = Uri.tryParse(ep);
    if (uri == null || (!uri.isScheme('https') && !uri.isScheme('http'))) {
      return ReportSubmitStatus.invalidEndpoint;
    }

    final isRelease = _isReleaseModeOverride ?? kReleaseMode;
    if (isRelease && !uri.isScheme('https')) {
      return ReportSubmitStatus.invalidEndpoint;
    }

    try {
      final body = jsonEncode(payload.toJson());
      if (body.length > 64 * 1024) {
        return ReportSubmitStatus.badRequest;
      }

      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'FinnAI-Android/${payload.appVersion}',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ReportSubmitStatus.success;
      } else if (response.statusCode == 400) {
        return ReportSubmitStatus.badRequest;
      } else if (response.statusCode == 429) {
        return ReportSubmitStatus.rateLimited;
      } else if (response.statusCode >= 500) {
        return ReportSubmitStatus.serverError;
      }
      return ReportSubmitStatus.networkError;
    } on TimeoutException {
      return ReportSubmitStatus.networkError;
    } catch (_) {
      return ReportSubmitStatus.networkError;
    }
  }
}
