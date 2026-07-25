import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../privacy/ad_consent_service.dart';
import '../theme/flux_theme.dart';
import 'ad_service.dart';

/// Container widget displaying a native AdMob Banner Ad when user consent is granted.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key, this.margin, this.adUnitId});

  final EdgeInsetsGeometry? margin;
  final String? adUnitId;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _adLoaded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    AdConsentService.instance.addListener(_onConsentChanged);
    _loadAdIfAllowed();
  }

  void _onConsentChanged() {
    if (mounted && !_adLoaded && !_isLoading) {
      _loadAdIfAllowed();
    }
  }

  Future<void> _loadAdIfAllowed() async {
    if (!AdService.instance.isSupportedPlatform) return;
    if (!AdConsentService.instance.canRequestAds) return;
    if (_isLoading || _adLoaded) return;

    _isLoading = true;
    try {
      await AdService.instance.initialize();
      if (!mounted) return;

      final ad = BannerAd(
        adUnitId: widget.adUnitId ?? AdService.bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() {
              _bannerAd = ad as BannerAd;
              _adLoaded = true;
              _isLoading = false;
            });
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('BannerAd failed to load: $error');
            ad.dispose();
            if (mounted) {
              setState(() {
                _bannerAd = null;
                _adLoaded = false;
                _isLoading = false;
              });
            }
          },
        ),
      );

      await ad.load();
    } catch (e) {
      debugPrint('BannerAdWidget error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
