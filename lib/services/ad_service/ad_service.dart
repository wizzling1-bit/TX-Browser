import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'ad_frequency_controller.dart';
import 'app_open_ad_manager.dart';
import 'banner_ad_manager.dart';
import 'interstitial_ad_manager.dart';
import 'rewarded_ad_manager.dart';
import '../../state/rewarded_perks_provider.dart';

export 'ad_config.dart';
export 'ad_frequency_controller.dart';
export 'app_open_ad_manager.dart';
export 'banner_ad_manager.dart';
export 'interstitial_ad_manager.dart';
export 'rewarded_ad_manager.dart';

/// Centralized production service for Google Mobile Ads lifecycle management.
///
/// Features:
/// - Coordinates [AppOpenAdManager], [BannerAdManager], [InterstitialAdManager], and [RewardedAdManager].
/// - Enforces frequency capping via [AdFrequencyController].
/// - Strict policy: Webpage contents are 100% untouched.
class AdService {
  AdService({AdConfig? config})
      : _config = config ?? const AdConfig(),
        frequencyController = AdFrequencyController(config: config) {
    appOpenManager = AppOpenAdManager(frequencyController: frequencyController);
    bannerManager = const BannerAdManager();
    interstitialManager = InterstitialAdManager(frequencyController: frequencyController);
    rewardedManager = RewardedAdManager();
  }

  final AdConfig _config;
  final AdFrequencyController frequencyController;

  late final AppOpenAdManager appOpenManager;
  late final BannerAdManager bannerManager;
  late final InterstitialAdManager interstitialManager;
  late final RewardedAdManager rewardedManager;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Optional callback to check if user has unlocked an Ad-Free Pass.
  bool Function()? isAdFreeChecker;

  /// Initializes the Mobile Ads SDK and preloads ads on supported platforms.
  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;

      if (_config.enableInterstitials) {
        interstitialManager.preload();
      }
      if (_config.enableAppOpenAds) {
        appOpenManager.loadAd();
      }
      if (_config.enableRewardedAds) {
        rewardedManager.preload();
      }
    } catch (e) {
      debugPrint('[AdService] MobileAds initialization failed: $e');
    }
  }

  /// Records a user action (e.g. tabs opened, page loaded, downloads, search submitted) to count towards interstitial thresholds.
  void recordUserAction() {
    frequencyController.recordAction();
  }

  /// Evaluates frequency criteria and shows an interstitial if eligible.
  bool maybeShowInterstitial({VoidCallback? onDismissed}) {
    if (isAdFreeChecker?.call() == true) return false;
    return interstitialManager.maybeShow(onDismissed: onDismissed);
  }

  /// Forces display of an interstitial (e.g. exit dialog).
  bool forceShowInterstitial({VoidCallback? onDismissed}) {
    if (isAdFreeChecker?.call() == true) return false;
    return interstitialManager.forceShow(onDismissed: onDismissed);
  }

  /// Shows a rewarded video ad and invokes reward callback upon completion.
  bool showRewardedAd({
    required void Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onDismissed,
  }) {
    return rewardedManager.showRewardedAd(
      onUserEarnedReward: onUserEarnedReward,
      onDismissed: onDismissed,
    );
  }

  /// Evaluates app resume criteria and shows an App Open ad if eligible.
  void handleAppResume({VoidCallback? onDismissed}) {
    if (isAdFreeChecker?.call() == true) return;
    appOpenManager.showAdIfAvailable(onDismissed: onDismissed);
  }

  void dispose() {
    interstitialManager.dispose();
    appOpenManager.dispose();
    rewardedManager.dispose();
  }
}

/// Global provider for [AdService].
final adServiceProvider = Provider<AdService>((ref) {
  final service = AdService();
  service.isAdFreeChecker = () => ref.read(rewardedPerksProvider).isAdFreeActive;
  service.initialize();
  ref.onDispose(service.dispose);
  return service;
});
