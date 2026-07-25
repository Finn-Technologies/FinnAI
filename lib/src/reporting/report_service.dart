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
        'categoryLabel': category.displayName,
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
  ReportService._();
  static final ReportService instance = ReportService._();

  static const String endpointConfig = String.fromEnvironment(
    'FINN_REPORT_ENDPOINT',
    defaultValue: '',
  );

  /// Submits an in-app AI response report.
  Future<bool> submitReport(ReportPayload payload) async {
    final endpoint = endpointConfig.trim();

    if (endpoint.isEmpty) {
      debugPrint('ReportService: FINN_REPORT_ENDPOINT is unconfigured.');
      if (kDebugMode) {
        // In debug mode with unconfigured endpoint, simulate successful mock submission
        await Future<void>.delayed(const Duration(milliseconds: 400));
        debugPrint('Mock report submitted successfully: ${jsonEncode(payload.toJson())}');
        return true;
      }
      return false;
    }

    final uri = Uri.tryParse(endpoint);
    if (uri == null || (!uri.isScheme('HTTPS') && !uri.isScheme('http'))) {
      debugPrint('ReportService: Invalid endpoint URI format.');
      return false;
    }

    if (kReleaseMode && !uri.isScheme('HTTPS')) {
      debugPrint('ReportService: Release builds require HTTPS report endpoints.');
      return false;
    }

    try {
      final body = jsonEncode(payload.toJson());
      if (body.length > 64 * 1024) {
        debugPrint('ReportService: Payload exceeds 64 KB limit.');
        return false;
      }

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'FinnAI-Android/${payload.appVersion}',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ReportService submission failed: $e');
      return false;
    }
  }
}
