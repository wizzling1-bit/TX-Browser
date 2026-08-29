import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'ad_frequency_controller.dart';

/// Manages background preloading and policy-compliant display of Interstitial Ads.
class InterstitialAdManager {
  InterstitialAdManager({
    required this.frequencyController,
    this.adUnitId = AdConfig.interstitialId,
  });

  final AdFrequencyController frequencyController;
  final String adUnitId;

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;

  bool get isAdReady => _interstitialAd != null;

  /// Preloads an interstitial in the background.
  void preload() {
    if (kIsWeb || _isLoading || _interstitialAd != null) return;
    _isLoading = true;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoading = false;
          debugPrint('[AdService] Interstitial loaded successfully');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isLoading = false;
          debugPrint('[AdService] Interstitial failed to load: ${error.message}');
        },
      ),
    );
  }

  /// Shows the interstitial if frequency criteria pass, and fires [onDismissed].
  bool maybeShow({VoidCallback? onDismissed}) {
    if (kIsWeb) {
      onDismissed?.call();
      return false;
    }

    if (!frequencyController.canShowInterstitial()) {
      onDismissed?.call();
      if (_interstitialAd == null && !_isLoading) preload();
      return false;
    }

    return _presentAd(onDismissed: onDismissed);
  }

  /// Forces display of an interstitial regardless of frequency count (e.g. exit dialog).
  bool forceShow({VoidCallback? onDismissed}) {
    if (kIsWeb) {
      onDismissed?.call();
      return false;
    }

    return _presentAd(onDismissed: onDismissed);
  }

  bool _presentAd({VoidCallback? onDismissed}) {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          frequencyController.recordInterstitialShown();
          onDismissed?.call();
          preload();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          onDismissed?.call();
          preload();
        },
      );

      _interstitialAd!.show();
      _interstitialAd = null;
      return true;
    } else {
      preload();
      onDismissed?.call();
      return false;
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}

