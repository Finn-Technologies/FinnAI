import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized AdMob Ad Service managing ad initialization, unit IDs, and ad lifecycles.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Standard Google AdMob Test Unit IDs (Production app IDs replaced prior to store release).
  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-4976264332074869/1275127603'; // Production Android Banner ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // Google iOS Test Banner ID
    }
    return '';
  }

  /// Banner placement used exclusively on the Settings page.
  static String get settingsBannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-4976264332074869/3646140073';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Google Android Test Interstitial ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // Google iOS Test Interstitial ID
    }
    return '';
  }

  /// Initializes the Google Mobile Ads SDK on supported platforms.
  Future<void> initialize() async {
    if (_initialized || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _initialized = true;
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      debugPrint('MobileAds initialization error: $e');
    }
  }

  /// Loads an Interstitial Ad and displays it upon completion.
  void showInterstitialAd({VoidCallback? onAdDismissed}) {
    if (!isSupportedPlatform) {
      onAdDismissed?.call();
      return;
    }

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onAdDismissed?.call();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onAdDismissed?.call();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          onAdDismissed?.call();
        },
      ),
    );
  }

  bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
