import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../services/ad_service/ad_config.dart';

enum TxAdSizeVariant {
  mediumRectangle, // 300x250 (High eCPM)
  standardBanner, // 320x50
}

/// Production-ready In-Feed Ad Card component powered by Google Mobile Ads.
///
/// Behaviour:
/// - Loads AdMob banner/MREC ad on init.
/// - Shows a subtle shimmer skeleton during loading.
/// - On success: renders the ad with a clear "AD" label.
/// - On failure: collapses to [SizedBox.shrink] — never shows a permanent placeholder.
/// - Single deferred retry (30s) if initial load fails, then gives up.
/// - Disposes ad properly on widget removal.
class TxNativeAdCard extends StatefulWidget {
  const TxNativeAdCard({
    super.key,
    this.adUnitId = AdConfig.bannerId,
    this.variant = TxAdSizeVariant.mediumRectangle,
    this.margin,
  });

  final String adUnitId;
  final TxAdSizeVariant variant;
  final EdgeInsetsGeometry? margin;

  @override
  State<TxNativeAdCard> createState() => _TxNativeAdCardState();
}

class _TxNativeAdCardState extends State<TxNativeAdCard>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  bool _hasFailed = false;
  Timer? _retryTimer;

  @override
  bool get wantKeepAlive => true;

  AdSize get _adSize {
    switch (widget.variant) {
      case TxAdSizeVariant.mediumRectangle:
        return AdSize.mediumRectangle;
      case TxAdSizeVariant.standardBanner:
        return AdSize.banner;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (kIsWeb || _isLoading || _isAdLoaded) return;
    _isLoading = true;

    try {
      _bannerAd = BannerAd(
        adUnitId: widget.adUnitId,
        size: _adSize,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted) {
              setState(() {
                _isAdLoaded = true;
                _isLoading = false;
                _hasFailed = false;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('[TxNativeAdCard] Ad failed to load: ${error.message}');
            ad.dispose();
            if (mounted) {
              setState(() {
                _bannerAd = null;
                _isAdLoaded = false;
                _isLoading = false;
              });

              // Schedule a single deferred retry after 30s
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
    } catch (e) {
      debugPrint('[TxNativeAdCard] Error initializing BannerAd: $e');
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Standard banner in docked bars stays collapsed until ready
    if (widget.variant == TxAdSizeVariant.standardBanner) {
      if (!_isAdLoaded || _bannerAd == null) {
        return const SizedBox.shrink();
      }
    } else {
      // In-feed medium rectangle collapses only on failure
      if (!_isAdLoaded && !_isLoading) {
        return const SizedBox.shrink();
      }
    }

    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return Container(
      margin: widget.margin ??
          const EdgeInsets.symmetric(
            horizontal: TxSpacing.lg,
            vertical: TxSpacing.sm,
          ),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TxRadius.borderRadiusMd,
        border: Border.all(
          color: colors.border.withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: TxElevation.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: AD Badge + Sponsor Attribution
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'AD',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: TxSpacing.xs),
              Text(
                'Sponsored',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textTertiary,
                      fontSize: 10.5,
                    ),
              ),
              const Spacer(),
              Icon(
                LucideIcons.sparkles,
                size: 13,
                color: colors.primary.withValues(alpha: 0.6),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Ad Canvas wrapped in FittedBox to avoid any overflow
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle animated shimmer skeleton shown while an ad is loading.
class _AdLoadingSkeleton extends StatefulWidget {
  const _AdLoadingSkeleton({
    required this.variant,
    required this.colors,
  });

  final TxAdSizeVariant variant;
  final TxColorScheme colors;

  @override
  State<_AdLoadingSkeleton> createState() => _AdLoadingSkeletonState();
}

class _AdLoadingSkeletonState extends State<_AdLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMrec = widget.variant == TxAdSizeVariant.mediumRectangle;
    final adHeight = isMrec ? 250.0 : 50.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: adHeight,
          decoration: BoxDecoration(
            color: widget.colors.surfaceAlt.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}
