import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;

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
/// - Cloud-managed remote configuration & emergency kill-switch.
/// - Strict policy: Webpage contents are 100% untouched.
class AdService {
  AdService({AdConfig? config, http.Client? httpClient})
      : _config = config ?? const AdConfig(),
        _httpClient = httpClient ?? http.Client(),
        frequencyController = AdFrequencyController(config: config) {
    appOpenManager = AppOpenAdManager(frequencyController: frequencyController);
    bannerManager = const BannerAdManager();
    interstitialManager = InterstitialAdManager(frequencyController: frequencyController);
    rewardedManager = RewardedAdManager();
  }

  AdConfig _config;
  AdConfig get config => _config;
  final http.Client _httpClient;
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
  Future<void> initialize({String? backendBaseUrl}) async {
    // Asynchronously fetch latest cloud configuration
    fetchRemoteConfig(backendBaseUrl: backendBaseUrl);

    if (_isInitialized || kIsWeb) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;

      if (_config.areAdsGloballyEnabled && _config.enableInterstitials) {
        interstitialManager.preload();
      }
      if (_config.areAdsGloballyEnabled && _config.enableAppOpenAds) {
        appOpenManager.loadAd();
      }
      if (_config.areAdsGloballyEnabled && _config.enableRewardedAds) {
        rewardedManager.preload();
      }
    } catch (e) {
      debugPrint('[AdService] MobileAds initialization failed: $e');
    }
  }

  /// Synchronizes remote configuration and emergency controls from backend and Supabase Cloud.
  Future<void> fetchRemoteConfig({String? backendBaseUrl}) async {
    final baseUrl = backendBaseUrl ?? 'https://txbrowser.com';
    try {
      final uri = Uri.parse('$baseUrl/api/v1/config/ads');
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['config'] is Map<String, dynamic>) {
          final newConfig = AdConfig.fromJson(data['config'] as Map<String, dynamic>);
          updateConfig(newConfig);
          debugPrint('[AdService] Synced remote ad configuration (killSwitch=${newConfig.killSwitch}).');
          return;
        }
      }
    } catch (_) {}

    // Direct Supabase Cloud Serverless Fallback
    try {
      const anonKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpZHJicmt5dmNhamFiZHl5Y21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMjAzNjEsImV4cCI6MjEwNTg5NjM2MX0.0VyAmmu65b5aiduXDbG4eDAAYYXJGky5S5ooHJ9A0sQ';
      final supabaseUri = Uri.parse(
          'https://vidrbrkyvcajabdyycmq.supabase.co/rest/v1/ad_configurations?id=eq.global');
      final response = await _httpClient.get(supabaseUri, headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        if (list.isNotEmpty && list.first is Map<String, dynamic>) {
          final newConfig = AdConfig.fromJson(list.first as Map<String, dynamic>);
          updateConfig(newConfig);
          debugPrint('[AdService] Synced ad configuration directly from Supabase Cloud: killSwitch=${newConfig.killSwitch}');
        }
      }
    } catch (e) {
      debugPrint('[AdService] Remote ad config note (safe defaults active): $e');
    }
  }

  /// Updates current ad configuration dynamically.
  void updateConfig(AdConfig newConfig) {
    _config = newConfig;
  }

  /// Records a user action (e.g. tabs opened, page loaded, downloads, search submitted) to count towards interstitial thresholds.
  void recordUserAction() {
    if (!_config.areAdsGloballyEnabled) return;
    frequencyController.recordAction();
  }

  /// Evaluates frequency criteria and shows an interstitial if eligible.
  bool maybeShowInterstitial({VoidCallback? onDismissed}) {
    if (!_config.areAdsGloballyEnabled || !_config.enableInterstitials) {
      onDismissed?.call();
      return false;
    }
    if (isAdFreeChecker?.call() == true) {
      onDismissed?.call();
      return false;
    }
    return interstitialManager.maybeShow(onDismissed: onDismissed);
  }

  /// Forces display of an interstitial (e.g. exit dialog).
  bool forceShowInterstitial({VoidCallback? onDismissed}) {
    if (!_config.areAdsGloballyEnabled || !_config.enableInterstitials) {
      onDismissed?.call();
      return false;
    }
    if (isAdFreeChecker?.call() == true) {
      onDismissed?.call();
      return false;
    }
    return interstitialManager.forceShow(onDismissed: onDismissed);
  }

  /// Shows a rewarded video ad and invokes reward callback upon completion.
  bool showRewardedAd({
    required void Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onDismissed,
  }) {
    if (_config.killSwitch || !_config.enableRewardedAds) {
      onDismissed?.call();
      return false;
    }
    return rewardedManager.showRewardedAd(
      onUserEarnedReward: onUserEarnedReward,
      onDismissed: onDismissed,
    );
  }

  /// Evaluates app resume criteria and shows an App Open ad if eligible.
  void handleAppResume({VoidCallback? onDismissed}) {
    if (!_config.areAdsGloballyEnabled || !_config.enableAppOpenAds) {
      onDismissed?.call();
      return;
    }
    if (isAdFreeChecker?.call() == true) {
      onDismissed?.call();
      return;
    }
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
