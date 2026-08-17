import 'dart:async';
import 'dart:convert';

import 'package:finn_ai/src/reporting/report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReportPayload testPayload;

  setUp(() {
    testPayload = ReportPayload(
      reportId: 'rep_12345',
      category: ReportCategory.harmfulOrDangerous,
      assistantResponse: 'Sample flagged AI response',
      timestamp: DateTime.parse('2026-07-25T12:00:00Z'),
      appVersion: '1.0.0',
      modelTier: 'Qwen 3.5 2B',
      userPrompt: 'Tell me something dangerous',
      additionalDetails: 'Test details',
    );
  });

  group('ReportService Unit Tests', () {
    test('Email report is complete and addressed to FinnAI support', () {
      final service = ReportService(
        endpoint: '',
        reportEmail: 'finn_org@proton.me',
      );

      final uri = service.buildEmailUri(testPayload);

      expect(uri, isNotNull);
      expect(uri!.scheme, 'mailto');
      expect(uri.path, 'finn_org@proton.me');
      expect(uri.queryParameters['subject'], contains('rep_12345'));
      final body = uri.queryParameters['body']!;
      expect(body, contains('Harmful or dangerous'));
      expect(body, contains('Qwen 3.5 2B'));
      expect(body, contains('Tell me something dangerous'));
      expect(body, contains('Sample flagged AI response'));
      expect(body, contains('Test details'));
    });

    test('Invalid report email cannot create a mailto URI', () {
      final service = ReportService(endpoint: '', reportEmail: 'not-an-email');

      expect(service.canComposeEmail, isFalse);
      expect(service.buildEmailUri(testPayload), isNull);
    });

    test('Unconfigured endpoint returns unconfigured status', () async {
      final service = ReportService(endpoint: '');
      final status = await service.submitReport(testPayload);
      expect(status, ReportSubmitStatus.unconfigured);
    });

    test('Successful 201 response returns success', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"success": true}', 201);
      });
      final service = ReportService(
        endpoint: 'https://reports.finnai.app/v1/reports',
        client: mockClient,
      );

      final status = await service.submitReport(testPayload);
      expect(status, ReportSubmitStatus.success);
    });

    test('HTTP 400 response returns badRequest', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "Invalid field"}', 400);
      });
      final service = ReportService(
        endpoint: 'https://reports.finnai.app/v1/reports',
        client: mockClient,
      );

      final status = await service.submitReport(testPayload);
      expect(status, ReportSubmitStatus.badRequest);
    });

    test('HTTP 429 response returns rateLimited', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "Too many requests"}', 429);
      });
      final service = ReportService(
        endpoint: 'https://reports.finnai.app/v1/reports',
        client: mockClient,
      );

      final status = await service.submitReport(testPayload);
      expect(status, ReportSubmitStatus.rateLimited);
    });

    test('HTTP 500 response returns serverError', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "Internal error"}', 500);
      });
      final service = ReportService(
        endpoint: 'https://reports.finnai.app/v1/reports',
        client: mockClient,
      );

      final status = await service.submitReport(testPayload);
      expect(status, ReportSubmitStatus.serverError);
    });

    test('Timeout exception returns networkError', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Request timed out');
      });
      final service = ReportService(
        endpoint: 'https://reports.finnai.app/v1/reports',
        client: mockClient,
      );

      final status = await service.submitReport(testPayload);
      expect(status, ReportSubmitStatus.networkError);
    });

    test(
      'Non-HTTPS endpoint in release mode returns invalidEndpoint',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"success": true}', 200);
        });
        final service = ReportService(
          endpoint: 'http://insecure-reports.finnai.app/v1/reports',
          client: mockClient,
          isReleaseModeOverride: true,
        );

        final status = await service.submitReport(testPayload);
        expect(status, ReportSubmitStatus.invalidEndpoint);
      },
    );

    test(
      'Report payload uses exact generating model tier rather than default or currently selected model',
      () async {
        late String transmittedModelTier;
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          transmittedModelTier = body['modelTier'] as String;
          return http.Response('{"success": true}', 201);
        });

        final service = ReportService(
          endpoint: 'https://reports.finnai.app/v1/reports',
          client: mockClient,
        );

        final routedPayload = ReportPayload(
          reportId: 'rep_routed_999',
          category: ReportCategory.other,
          assistantResponse: 'Answer from Pro tier',
          timestamp: DateTime.now(),
          appVersion: '1.0.0',
          modelTier: 'Qwen 3.5 2B',
        );

        await service.submitReport(routedPayload);

        expect(transmittedModelTier, 'Qwen 3.5 2B');
        expect(transmittedModelTier, isNot(equals('Finn AI')));
      },
    );
  });
}
