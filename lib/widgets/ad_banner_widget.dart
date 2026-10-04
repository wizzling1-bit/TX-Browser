import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/theme/colors.dart';
import '../core/theme/shapes.dart';
import '../core/theme/spacing.dart';

import '../services/ad_service/ad_config.dart';

/// Adaptive banner ad widget that collapses gracefully on load failure.
///
/// Loads an AdMob banner ad and renders it with clear "AD" labeling.
/// On failure: collapses to [SizedBox.shrink] — no permanent placeholder.
/// Single deferred retry (30s) if initial load fails.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _hasFailed = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (kIsWeb) return;

    try {
      _bannerAd = BannerAd(
        adUnitId: AdConfig.bannerId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _isAdLoaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('[AdBannerWidget] Ad failed to load: ${error.message}');
            ad.dispose();
            if (mounted) {
              setState(() {
                _bannerAd = null;
                _isAdLoaded = false;
              });

              // Single deferred retry
              if (!_hasFailed) {
                _hasFailed = true;
                _retryTimer?.cancel();
                _retryTimer = Timer(const Duration(seconds: 30), () {
                  if (mounted && !_isAdLoaded) {
                    _loadAd();
                  }
                });
              }
            }
          },
        ),
      )..load();
    } catch (_) {
      // AdMob not initialized or mock env
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Collapse entirely when ad is not loaded
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: TxSpacing.lg,
        vertical: TxSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: TxRadius.borderRadiusSm,
        color: colors.surface,
        border: Border.all(
          color: colors.border.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
