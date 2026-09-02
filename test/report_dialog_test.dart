import 'dart:convert';

import 'package:finn_ai/src/reporting/report_dialog.dart';
import 'package:finn_ai/src/reporting/report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  final capturedBodies = <Map<String, dynamic>>[];
  final launchedUrls = <String>[];

  setUp(() {
    capturedBodies.clear();
    launchedUrls.clear();
  });

  ReportService serviceWith({
    required MockClient client,
    String endpoint = 'https://reports.finnai.app/v1/reports',
    String? reportEmail = 'finn_org@proton.me',
  }) =>
      ReportService(
          endpoint: endpoint, reportEmail: reportEmail, client: client);

  ReportService serviceReturning(http.Response response) => serviceWith(
        client: MockClient((request) async {
          capturedBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return response;
        }),
      );

  Future<void> pumpDialog(
    WidgetTester tester, {
    required ReportService service,
    String userPrompt = 'the secret prompt',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => ReportDialog.show(
                  context,
                  assistantResponse: 'flagged answer',
                  userPrompt: userPrompt,
                  modelTier: 'Qwen 3.5 2B',
                  appVersion: '1.2.3',
                  reportService: service,
                ),
                child: const Text('open report dialog'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open report dialog'));
    await tester.pumpAndSettle();
  }

  void mockLauncher() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async {
      if (call.method == 'launch') {
        launchedUrls.add(call.arguments['url'] as String);
      }
      return true;
    });
  }

  group('ReportDialog submission', () {
    testWidgets(
      'submits over HTTP first, includes no prompt without consent, shows sent confirmation',
      (tester) async {
        final service = serviceReturning(http.Response('{"ok": true}', 201));

        await pumpDialog(tester, service: service);

        await tester.tap(find.text('Continue to Email'));
        await tester.pumpAndSettle();

        expect(capturedBodies, hasLength(1));
        expect(capturedBodies.single['assistantResponse'], 'flagged answer');
        expect(capturedBodies.single['modelTier'], 'Qwen 3.5 2B');
        // Consent checkbox unchecked by default: the prompt stays local.
        expect(capturedBodies.single.containsKey('userPrompt'), isFalse);
        // The dialog closes and confirms delivery; no email app is opened.
        expect(launchedUrls, isEmpty);
        expect(find.byType(ReportDialog), findsNothing);
        expect(
          find.text('Report sent. Thank you for helping keep FinnAI safe.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'includes the prompt over HTTP only when the consent checkbox is ticked',
      (tester) async {
        final service = serviceReturning(http.Response('{"ok": true}', 201));

        await pumpDialog(tester, service: service);
        await tester.tap(find.text('Include my prompt in this report'));
        await tester.pump();

        await tester.tap(find.text('Continue to Email'));
        await tester.pumpAndSettle();

        expect(capturedBodies, hasLength(1));
        expect(capturedBodies.single['userPrompt'], 'the secret prompt');
      },
    );

    testWidgets(
      'falls back to the email flow when the endpoint rejects the report',
      (tester) async {
        mockLauncher();
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance.defaultBinaryMessenger
              .setMockMethodCallHandler(launcherChannel, null),
        );
        final service = serviceReturning(
          http.Response('{"error": "rejected"}', 500),
        );

        await pumpDialog(tester, service: service);

        await tester.tap(find.text('Continue to Email'));
        await tester.pumpAndSettle();

        // HTTP failed (500), so the existing mailto: flow ran automatically.
        expect(launchedUrls, hasLength(1));
        expect(launchedUrls.single, startsWith('mailto:'));
        expect(launchedUrls.single, contains('finn_org'));
        expect(launchedUrls.single, contains('subject='));
        expect(find.byType(ReportDialog), findsNothing);
        expect(
          find.text('Review the report in your email app, then send it.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'falls back to the email flow when the network is unreachable',
      (tester) async {
        mockLauncher();
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance.defaultBinaryMessenger
              .setMockMethodCallHandler(launcherChannel, null),
        );
        final service = serviceWith(
          client: MockClient(
            (request) async => throw Exception('device is offline'),
          ),
        );

        await pumpDialog(tester, service: service);

        await tester.tap(find.text('Continue to Email'));
        await tester.pumpAndSettle();

        expect(launchedUrls, hasLength(1));
        expect(launchedUrls.single, startsWith('mailto:'));
      },
    );
  });
}
