import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../privacy/ad_consent_service.dart';

/// Centralized AdMob Ad Service managing ad initialization and environment-aware unit IDs.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Returns official Google test ad-unit IDs in debug/profile builds,
  /// and production FinnAI ad-unit IDs only in release builds.
  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return kReleaseMode
          ? 'ca-app-pub-4976264332074869/1275127603' // Production Android Banner ID
          : 'ca-app-pub-3940256099942544/6300978111'; // Google Test Banner ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // Google iOS Test Banner ID
    }
    return '';
  }

  /// Banner placement used exclusively on the Settings page.
  static String get settingsBannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return kReleaseMode
          ? 'ca-app-pub-4976264332074869/3646140073' // Production Settings Banner ID
          : 'ca-app-pub-3940256099942544/6300978111'; // Google Test Banner ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // Google iOS Test Banner ID
    }
    return '';
  }

  /// Initializes the Google Mobile Ads SDK on supported platforms when UMP consent is granted.
  Future<void> initialize() async {
    if (_initialized || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _initialized = true;
      return;
    }
    if (!AdConsentService.instance.canRequestAds && !kDebugMode) {
      debugPrint('MobileAds initialization skipped: Privacy consent not granted.');
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      debugPrint('MobileAds initialization error: $e');
    }
  }

  bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
