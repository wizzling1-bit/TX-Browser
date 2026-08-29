import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Manages the creation and configuration of standard & adaptive Banner Ads.
class BannerAdManager {
  const BannerAdManager({this.adUnitId = AdConfig.bannerId});

  final String adUnitId;

  /// Creates and loads a BannerAd with lifecycle callbacks.
  BannerAd? createBannerAd({
    required void Function(Ad ad) onAdLoaded,
    required void Function(Ad ad, LoadAdError error) onAdFailedToLoad,
    AdSize size = AdSize.banner,
  }) {
    if (kIsWeb) return null;

    final banner = BannerAd(
      size: size,
      adUnitId: adUnitId,
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
      request: const AdRequest(),
    );

    banner.load();
    return banner;
  }
}
