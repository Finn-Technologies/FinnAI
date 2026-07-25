import 'package:finn_ai/src/ads/ad_service.dart';
import 'package:finn_ai/src/ads/banner_ad_widget.dart';
import 'package:finn_ai/src/privacy/ad_consent_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ad Service & AdMob Consent Tests', () {
    test('AdConsentService provides default initial state', () {
      final consentService = AdConsentService.instance;
      expect(consentService.canRequestAds, false);
      expect(consentService.isPrivacyOptionsRequired, false);
    });

    test('AdService provides environment-aware banner unit IDs', () {
      expect(AdService.bannerAdUnitId, isA<String>());
      expect(AdService.settingsBannerAdUnitId, isA<String>());
    });

    testWidgets('BannerAdWidget collapses cleanly when consent is not granted', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BannerAdWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BannerAdWidget), findsOneWidget);
      // When ad consent is not granted, height/width are collapsed (SizedBox.shrink)
      final size = tester.getSize(find.byType(BannerAdWidget));
      expect(size.width, 0);
      expect(size.height, 0);
    });
  });
}
