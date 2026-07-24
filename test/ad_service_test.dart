import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux_local/src/ads/ad_service.dart';
import 'package:flux_local/src/ads/banner_ad_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ad Service & AdMob Component Tests', () {
    test('AdService initializes without throwing', () async {
      final adService = AdService.instance;
      await adService.initialize();
      expect(adService.isInitialized, true);
    });

    test('AdService provides test unit IDs', () {
      expect(AdService.bannerAdUnitId, isA<String>());
      expect(AdService.interstitialAdUnitId, isA<String>());
    });

    testWidgets('BannerAdWidget renders cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BannerAdWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BannerAdWidget), findsOneWidget);
    });
  });
}
