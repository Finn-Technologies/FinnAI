import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/flux_theme.dart';
import 'ad_service.dart';

/// Glassmorphic container widget displaying a native AdMob Banner Ad.
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

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (!AdService.instance.isSupportedPlatform) return;

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
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    );

    await ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final bg = isDark
        ? const Color(0xDD18181B)
        : Colors.white.withValues(alpha: .85);
    final borderColor = FluxColors.lineOf(context);

    if (_adLoaded && _bannerAd != null) {
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

    // Sleek fallback banner container
    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Ad',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: FluxColors.mutedOf(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Finn AI · On-Device Intelligence',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 11,
                color: FluxColors.mutedOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
