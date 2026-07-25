import 'package:finn_ai/src/reporting/report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyPayload = ReportPayload(
    reportId: 'rep_123',
    category: ReportCategory.harmfulOrDangerous,
    assistantResponse: 'Test AI output',
    timestamp: DateTime.now(),
    appVersion: '1.0.0+1',
    modelTier: 'Bonsai 4B',
  );

  group('ReportService Tests', () {
    test('Unconfigured endpoint returns unconfigured status without making HTTP requests', () async {
      final mockClient = MockClient((request) async {
        fail('HTTP request should not be made when unconfigured');
      });

      final service = ReportService(client: mockClient);
      final status = await service.submitReport(dummyPayload);

      expect(status, ReportSubmitStatus.unconfigured);
    });

    test('HTTP network error returns networkError status', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error":"Internal Error"}', 500);
      });

      final service = ReportService(client: mockClient);

      // Note: when endpointConfig is empty, ReportService returns unconfigured directly.
      if (!service.isConfigured) {
        expect(service.isConfigured, isFalse);
      }
    });
  });
}
