/// Centralized Ad Configuration for Tx Browser.
///
/// Configured with production AdMob IDs for maximum earnings across all formats:
/// - App Open Ads (launch & resume)
/// - Adaptive & Medium Rectangle (MREC 300x250) In-Feed Banners
/// - Transition Interstitials (with intelligent frequency capping)
/// - Rewarded Video & Rewarded Interstitial Ads
///
/// Follows strict Google Mobile Ads policies:
/// - Never inject ads into or replace third-party webpage content.
/// - Frequency capping, cooldowns, and session caps on interstitials.
/// - Never show ads during active reading or on every click.
class AdConfig {
  const AdConfig({
    // ── Master switches ──────────────────────────────────────────────
    this.enableAds = true,
    this.killSwitch = false,
    this.enableHomeAds = true,
    this.enableInterstitials = true,
    this.enableAppOpenAds = true,
    this.enableRewardedAds = true,

    // ── Interstitial frequency / safety ──────────────────────────────
    this.minimumActionsBetweenInterstitials = 3,
    this.cooldownDuration = const Duration(seconds: 45),
    this.appOpenCooldownDuration = const Duration(seconds: 45),
    this.maxInterstitialsPerSession = 6,

    // ── Rewarded Perk Duration ─────────────────────────────────────────
    this.rewardedPerkMinutes = 10,

    // ── Dynamic Ad Unit IDs ────────────────────────────────────────────
    this.bannerAdUnitId = bannerId,
    this.interstitialAdUnitId = interstitialId,
    this.rewardedAdUnitId = rewardedId,
    this.appOpenAdUnitId = appOpenId,
    this.nativeAdUnitId = nativeId,

    // ── Per-screen native ad limits ──────────────────────────────────
    this.maxNativeAdsPerScreen = 1,

    // ── Placement enable/disable (A/B testable) ──────────────────────
    this.homeNativeAd = true,
    this.homeBanner = true,
    this.tabsNativeAd = true,
    this.historyNativeAd = true,
    this.downloadsNativeAd = true,
    this.bookmarksNativeAd = true,
    this.downloadCompleteAd = true,
    this.searchSuggestionsAd = true,
    this.clearDataAd = true,
    this.privateSessionEndedAd = true,

    // ── Prohibited placements (never enable) ─────────────────────────
    this.browserOverlayAds = false,
    this.thirdPartyPageInjection = false,
    this.searchResultInjection = false,
  });

  // ── Master switches ──────────────────────────────────────────────────
  final bool enableAds;
  final bool killSwitch;
  final bool enableHomeAds;
  final bool enableInterstitials;
  final bool enableAppOpenAds;
  final bool enableRewardedAds;

  /// Returns true only if ads are enabled and kill-switch is NOT active
  bool get areAdsGloballyEnabled => enableAds && !killSwitch;

  // ── Interstitial frequency / safety ──────────────────────────────────
  final int minimumActionsBetweenInterstitials;
  final Duration cooldownDuration;
  final Duration appOpenCooldownDuration;
  final int maxInterstitialsPerSession;

  // ── Rewarded Perk Duration ─────────────────────────────────────────
  final int rewardedPerkMinutes;

  // ── Dynamic Ad Unit IDs ────────────────────────────────────────────
  final String bannerAdUnitId;
  final String interstitialAdUnitId;
  final String rewardedAdUnitId;
  final String appOpenAdUnitId;
  final String nativeAdUnitId;

  // ── Per-screen native ad limits ──────────────────────────────────────
  final int maxNativeAdsPerScreen;

  // ── Placement enable/disable (A/B testable) ──────────────────────────
  final bool homeNativeAd;
  final bool homeBanner;
  final bool tabsNativeAd;
  final bool historyNativeAd;
  final bool downloadsNativeAd;
  final bool bookmarksNativeAd;
  final bool downloadCompleteAd;
  final bool searchSuggestionsAd;
  final bool clearDataAd;
  final bool privateSessionEndedAd;

  // ── Prohibited placements (enforced) ─────────────────────────────────
  final bool browserOverlayAds;
  final bool thirdPartyPageInjection;
  final bool searchResultInjection;

  // ── Production AdMob Unit IDs ────────────────────────────────────────
  static const String appId = 'ca-app-pub-3435015056397165~5473577665';
  static const String bannerId = 'ca-app-pub-3435015056397165/1621912239';
  static const String mrecId = 'ca-app-pub-3435015056397165/1621912239';
  static const String interstitialId = 'ca-app-pub-3435015056397165/8850550042';
  static const String appOpenId = 'ca-app-pub-3435015056397165/3538513614';
  static const String rewardedId = 'ca-app-pub-3435015056397165/8658978359';
  static const String nativeId = 'ca-app-pub-3435015056397165/5210687936';

  factory AdConfig.fromJson(Map<String, dynamic> json) {
    return AdConfig(
      killSwitch: json['killSwitch'] == true || json['kill_switch'] == true,
      enableAds: json['enableAds'] ?? true,
      enableHomeAds: json['bannerEnabled'] ?? json['banner_enabled'] ?? true,
      enableInterstitials: json['interstitialEnabled'] ?? json['interstitial_enabled'] ?? true,
      enableAppOpenAds: json['appOpenEnabled'] ?? json['app_open_enabled'] ?? true,
      enableRewardedAds: json['rewardedEnabled'] ?? json['rewarded_enabled'] ?? true,
      minimumActionsBetweenInterstitials: ((json['interstitialPageThreshold'] ?? json['interstitial_page_threshold'] ?? 3) as num).toInt(),
      cooldownDuration: Duration(minutes: ((json['interstitialIntervalMinutes'] ?? json['interstitial_interval_minutes'] ?? 5) as num).toInt()),
      rewardedPerkMinutes: ((json['rewardedPerkMinutes'] ?? json['rewarded_perk_minutes'] ?? 10) as num).toInt(),
      bannerAdUnitId: (json['bannerAdUnitId'] ?? json['banner_ad_unit_id'] ?? bannerId) as String,
      interstitialAdUnitId: (json['interstitialAdUnitId'] ?? json['interstitial_ad_unit_id'] ?? interstitialId) as String,
      rewardedAdUnitId: (json['rewardedAdUnitId'] ?? json['rewarded_ad_unit_id'] ?? rewardedId) as String,
      appOpenAdUnitId: (json['appOpenAdUnitId'] ?? json['app_open_ad_unit_id'] ?? appOpenId) as String,
      nativeAdUnitId: (json['nativeAdUnitId'] ?? json['native_ad_unit_id'] ?? nativeId) as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'killSwitch': killSwitch,
    'enableAds': enableAds,
    'bannerEnabled': enableHomeAds,
    'interstitialEnabled': enableInterstitials,
    'appOpenEnabled': enableAppOpenAds,
    'rewardedEnabled': enableRewardedAds,
    'interstitialPageThreshold': minimumActionsBetweenInterstitials,
    'interstitialIntervalMinutes': cooldownDuration.inMinutes,
    'rewardedPerkMinutes': rewardedPerkMinutes,
    'bannerAdUnitId': bannerAdUnitId,
    'interstitialAdUnitId': interstitialAdUnitId,
    'rewardedAdUnitId': rewardedAdUnitId,
    'appOpenAdUnitId': appOpenAdUnitId,
    'nativeAdUnitId': nativeAdUnitId,
  };
}
