import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/ad_service.dart';

/// Centralized service handling Google UMP (User Messaging Platform) privacy consent.
class AdConsentService extends ChangeNotifier {
  AdConsentService._();
  static final AdConsentService instance = AdConsentService._();

  bool _isRequestingConsent = false;
  bool _canRequestAds = false;
  bool _isPrivacyOptionsRequired = false;
  String? _consentError;

  bool get canRequestAds => _canRequestAds;
  bool get isPrivacyOptionsRequired => _isPrivacyOptionsRequired;
  bool get isRequestingConsent => _isRequestingConsent;
  String? get consentError => _consentError;

  /// Requests UMP consent update with guaranteed Completer completion.
  Future<void> initializeConsentAndAds({bool isDebug = false}) async {
    if (!AdService.instance.isSupportedPlatform) {
      _canRequestAds = false;
      notifyListeners();
      return;
    }

    _isRequestingConsent = true;
    _consentError = null;
    notifyListeners();

    final params = ConsentRequestParameters(
      consentDebugSettings: isDebug && !kReleaseMode
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
            )
          : null,
    );

    final completer = Completer<void>();

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            final isFormAvailable = await ConsentInformation.instance.isConsentFormAvailable();
            if (isFormAvailable) {
              await _loadAndShowFormIfRequired();
            } else {
              await _updateConsentState();
            }
          } catch (e) {
            _consentError = e.toString();
            await _updateConsentState();
          } finally {
            if (!completer.isCompleted) completer.complete();
          }
        },
        (FormError error) async {
          debugPrint('Consent info update failed: ${error.message}');
          _consentError = error.message;
          await _updateConsentState();
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (e) {
      debugPrint('AdConsentService error: $e');
      _consentError = e.toString();
      await _updateConsentState();
      if (!completer.isCompleted) completer.complete();
    }

    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () async {
        _consentError = 'Consent request timed out.';
        await _updateConsentState();
      },
    );

    _isRequestingConsent = false;
    notifyListeners();
  }

  Future<void> _loadAndShowFormIfRequired() async {
    final completer = Completer<void>();
    try {
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) async {
        if (formError != null) {
          debugPrint('Consent form error: ${formError.message}');
          _consentError = formError.message;
        }
        await _updateConsentState();
        if (!completer.isCompleted) completer.complete();
      });
    } catch (e) {
      debugPrint('Error loading consent form: $e');
      _consentError = e.toString();
      await _updateConsentState();
      if (!completer.isCompleted) completer.complete();
    }

    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () async {
        _consentError = 'Form load timed out.';
        await _updateConsentState();
      },
    );
  }

  Future<void> _updateConsentState() async {
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      _isPrivacyOptionsRequired = (status == PrivacyOptionsRequirementStatus.required);

      if (_canRequestAds) {
        await AdService.instance.initialize();
      }
    } catch (e) {
      debugPrint('Error updating consent state: $e');
      _canRequestAds = false;
      _isPrivacyOptionsRequired = false;
    }
    notifyListeners();
  }

  /// Displays the UMP privacy options form when requested by the user from Settings.
  Future<bool> showPrivacyOptionsForm() async {
    if (!AdService.instance.isSupportedPlatform) return false;
    final completer = Completer<bool>();
    try {
      ConsentForm.showPrivacyOptionsForm((FormError? formError) async {
        if (formError != null) {
          debugPrint('Privacy options error: ${formError.message}');
          _consentError = formError.message;
          if (!completer.isCompleted) completer.complete(false);
        } else {
          await _updateConsentState();
          if (!completer.isCompleted) completer.complete(true);
        }
      });
    } catch (e) {
      debugPrint('Exception in showPrivacyOptionsForm: $e');
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => false,
    );
  }
}
