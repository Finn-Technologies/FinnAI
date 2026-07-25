import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../privacy/ad_consent_service.dart';
import '../theme/flux_theme.dart';
import 'ad_service.dart';

/// Abstraction over the real BannerAd construction + load, injectable for tests.
///
/// The loader is responsible for building the [BannerAd] (with listener
/// attached) and starting the load.  [generation] is captured by the caller
/// before any await and must be forwarded to [onLoaded] / [onFailed] so the
/// widget can detect stale callbacks.
typedef BannerAdLoader =
    Future<void> Function({
      required String adUnitId,
      required int generation,
      required void Function(BannerAd ad, int gen) onLoaded,
      required void Function(Ad ad, LoadAdError error, int gen) onFailed,
    });

/// Default production loader — creates a real [BannerAd] and calls load().
Future<void> _defaultLoader({
  required String adUnitId,
  required int generation,
  required void Function(BannerAd ad, int gen) onLoaded,
  required void Function(Ad ad, LoadAdError error, int gen) onFailed,
}) async {
  final ad = BannerAd(
    adUnitId: adUnitId,
    size: AdSize.banner,
    request: const AdRequest(),
    listener: BannerAdListener(
      onAdLoaded: (loaded) => onLoaded(loaded as BannerAd, generation),
      onAdFailedToLoad: (failed, err) => onFailed(failed, err, generation),
    ),
  );
  await ad.load();
}

/// Container widget displaying a native AdMob Banner Ad when user consent is
/// granted.
///
/// A monotonically-increasing [_generation] counter is incremented every time
/// a new ad request starts or consent is revoked.  Callbacks that carry an
/// older generation number are silently disposed — this closes the race between
/// consent revocation / re-grant and an in-flight network response.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({
    super.key,
    this.margin,
    this.adUnitId,
    this.onAdLoadedStateChanged,
    this.adLoader,
    this.isSupportedPlatformOverride,
  });

  final EdgeInsetsGeometry? margin;
  final String? adUnitId;
  final ValueChanged<bool>? onAdLoadedStateChanged;

  /// Override in tests to control when/whether the ad callback fires.
  final BannerAdLoader? adLoader;

  /// When non-null, overrides [AdService.instance.isSupportedPlatform].
  /// Use only in tests to bypass the Android/iOS platform gate.
  @visibleForTesting
  final bool? isSupportedPlatformOverride;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;

  /// Incremented every time a new request begins or consent is revoked so that
  /// callbacks from stale requests can be detected and discarded.
  int _generation = 0;

  bool _adLoaded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    AdConsentService.instance.addListener(_onConsentChanged);
    _loadAdIfAllowed();
  }

  void _onConsentChanged() {
    if (!mounted) return;
    if (AdConsentService.instance.canRequestAds) {
      if (!_adLoaded && !_isLoading) {
        _loadAdIfAllowed();
      }
    } else {
      // Revoke: advance the generation counter so any in-flight callback for
      // generation N will be ignored because _generation is now > N.
      _generation++;
      _bannerAd?.dispose();
      _bannerAd = null;
      if (_adLoaded || _isLoading) {
        setState(() {
          _adLoaded = false;
          _isLoading = false;
        });
        widget.onAdLoadedStateChanged?.call(false);
      }
    }
  }

  Future<void> _loadAdIfAllowed() async {
    final supported =
        widget.isSupportedPlatformOverride ??
        AdService.instance.isSupportedPlatform;
    if (!supported) return;
    if (!AdConsentService.instance.canRequestAds) return;
    if (_isLoading || _adLoaded) return;

    _isLoading = true;

    // Snapshot the generation that belongs to *this* request before any
    // await so the closure captures it immutably.
    final int myGeneration = _generation;

    try {
      await AdService.instance.initialize();
      if (!mounted) return;

      // If consent was revoked while we awaited initialize(), our generation
      // will have been incremented and we must not proceed.
      if (_generation != myGeneration) return;

      final loader = widget.adLoader ?? _defaultLoader;
      await loader(
        adUnitId: widget.adUnitId ?? AdService.bannerAdUnitId,
        generation: myGeneration,
        onLoaded: _handleAdLoaded,
        onFailed: _handleAdFailed,
      );
    } catch (e) {
      debugPrint('BannerAdWidget error: $e');
      if (mounted && _generation == myGeneration) {
        setState(() {
          _isLoading = false;
        });
        widget.onAdLoadedStateChanged?.call(false);
      }
    }
  }

  void _handleAdLoaded(BannerAd ad, int gen) {
    // Stale generation: this callback belongs to a revoked or superseded
    // request. Dispose immediately and leave the layout collapsed.
    if (gen != _generation) {
      ad.dispose();
      return;
    }
    // Re-check live consent in case it changed between the callback being
    // enqueued and it being processed on the Dart event loop.
    if (!mounted || !AdConsentService.instance.canRequestAds) {
      ad.dispose();
      if (mounted) {
        setState(() {
          _adLoaded = false;
          _isLoading = false;
        });
        widget.onAdLoadedStateChanged?.call(false);
      }
      return;
    }
    setState(() {
      _bannerAd = ad;
      _adLoaded = true;
      _isLoading = false;
    });
    widget.onAdLoadedStateChanged?.call(true);
  }

  void _handleAdFailed(Ad ad, LoadAdError error, int gen) {
    debugPrint('BannerAd failed to load: $error');
    ad.dispose();
    if (mounted && gen == _generation) {
      setState(() {
        _bannerAd = null;
        _adLoaded = false;
        _isLoading = false;
      });
      widget.onAdLoadedStateChanged?.call(false);
    }
  }

  @override
  void dispose() {
    AdConsentService.instance.removeListener(_onConsentChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_adLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final isDark = FluxColors.isDark(context);
    final bg = isDark
        ? const Color(0xDD18181B)
        : Colors.white.withValues(alpha: .85);
    final borderColor = FluxColors.lineOf(context);

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
