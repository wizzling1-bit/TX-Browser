import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Manages background preloading and display of AdMob Rewarded Video Ads.
class RewardedAdManager {
  RewardedAdManager({
    this.adUnitId = AdConfig.rewardedId,
  });

  final String adUnitId;

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  bool get isAdReady => _rewardedAd != null;

  /// Preloads a rewarded ad in the background.
  void preload() {
    if (kIsWeb || _isLoading || _rewardedAd != null) return;
    _isLoading = true;

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          debugPrint('[AdService] RewardedAd loaded successfully');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
          debugPrint('[AdService] RewardedAd failed to load: ${error.message}');
        },
      ),
    );
  }

  /// Shows the rewarded ad and triggers callbacks on user earn and ad dismiss.
  bool showRewardedAd({
    required void Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onDismissed,
  }) {
    if (kIsWeb) {
      onDismissed?.call();
      return false;
    }

    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          onDismissed?.call();
          preload();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedAd = null;
          onDismissed?.call();
          preload();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          onUserEarnedReward(reward);
        },
      );
      _rewardedAd = null;
      return true;
    } else {
      preload();
      onDismissed?.call();
      return false;
    }
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
