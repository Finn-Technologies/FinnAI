import 'package:finn_ai/src/ads/banner_ad_widget.dart';
import 'package:finn_ai/src/privacy/ad_consent_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ad Service & AdMob Consent Tests', () {
    testWidgets('BannerAdWidget collapses cleanly when consent is not granted', (tester) async {
      expect(AdConsentService.instance.canRequestAds, isFalse);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BannerAdWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final finder = find.byType(BannerAdWidget);
      expect(finder, findsOneWidget);

      final renderBox = tester.renderObject(finder) as RenderBox;
      expect(renderBox.size.height, 0);
      expect(renderBox.size.width, 0);
    });
  });
}
