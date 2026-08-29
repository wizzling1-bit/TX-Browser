import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'ad_frequency_controller.dart';

/// Manages the preloading, caching, and display of AdMob App Open Ads on startup and resume.
class AppOpenAdManager {
  AppOpenAdManager({
    required this.frequencyController,
    this.adUnitId = AdConfig.appOpenId,
  });

  final AdFrequencyController frequencyController;
  final String adUnitId;

  AppOpenAd? _appOpenAd;
  bool _isLoading = false;
  bool _isShowingAd = false;
  DateTime? _appOpenLoadTime;

  bool get isAdAvailable {
    return _appOpenAd != null &&
        _appOpenLoadTime != null &&
        DateTime.now().difference(_appOpenLoadTime!) < const Duration(hours: 4);
  }

  /// Preloads an App Open ad in the background.
  void loadAd() {
    if (kIsWeb || _isLoading || isAdAvailable) return;
    _isLoading = true;

    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isLoading = false;
          _appOpenLoadTime = DateTime.now();
          debugPrint('[AdService] AppOpenAd loaded successfully');
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _appOpenAd = null;
          debugPrint('[AdService] AppOpenAd failed to load: ${error.message}');
        },
      ),
    );
  }

  /// Shows the App Open ad on app launch or resume if frequency criteria allow.
  void showAdIfAvailable({VoidCallback? onDismissed}) {
    if (kIsWeb || _isShowingAd) {
      onDismissed?.call();
      return;
    }

    if (!frequencyController.canShowAppOpen()) {
      if (!isAdAvailable && !_isLoading) loadAd();
      onDismissed?.call();
      return;
    }

    if (!isAdAvailable) {
      loadAd();
      onDismissed?.call();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        frequencyController.recordAppOpenShown();
        onDismissed?.call();
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        onDismissed?.call();
        loadAd();
      },
    );

    _appOpenAd!.show();
  }

  void dispose() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }
}

