import 'dart:async';

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
      modelTier: 'Bonsai 4B',
      userPrompt: 'Tell me something dangerous',
      additionalDetails: 'Test details',
    );
  });

  group('ReportService Unit Tests', () {
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
  });
}
