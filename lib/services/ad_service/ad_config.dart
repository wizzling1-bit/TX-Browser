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
    this.enableHomeAds = true,
    this.enableInterstitials = true,
    this.enableAppOpenAds = true,
    this.enableRewardedAds = true,

    // ── Interstitial frequency / safety ──────────────────────────────
    this.minimumActionsBetweenInterstitials = 3,
    this.cooldownDuration = const Duration(seconds: 45),
    this.appOpenCooldownDuration = const Duration(seconds: 45),
    this.maxInterstitialsPerSession = 6,

    // ── Per-screen native ad limits ──────────────────────────────────
    this.maxNativeAdsPerScreen = 1,

    // ── Placement enable/disable (A/B testable) ──────────────────────
    this.homeNativeAd = true,
    this.homeBanner = true,
    this.tabsNativeAd = true,
    this.historyNativeAd = true,
    this.downloadsNativeAd = true,
    this.bookmarksNativeAd = true,

    // ── Prohibited placements (never enable) ─────────────────────────
    this.browserOverlayAds = false,
    this.thirdPartyPageInjection = false,
    this.searchResultInjection = false,
  });

  // ── Master switches ──────────────────────────────────────────────────
  final bool enableAds;
  final bool enableHomeAds;
  final bool enableInterstitials;
  final bool enableAppOpenAds;
  final bool enableRewardedAds;

  // ── Interstitial frequency / safety ──────────────────────────────────
  final int minimumActionsBetweenInterstitials;
  final Duration cooldownDuration;
  final Duration appOpenCooldownDuration;
  final int maxInterstitialsPerSession;

  // ── Per-screen native ad limits ──────────────────────────────────────
  final int maxNativeAdsPerScreen;

  // ── Placement enable/disable (A/B testable) ──────────────────────────
  final bool homeNativeAd;
  final bool homeBanner;
  final bool tabsNativeAd;
  final bool historyNativeAd;
  final bool downloadsNativeAd;
  final bool bookmarksNativeAd;

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

  // ── Google AdMob official test Ad Unit IDs (Android) ─────────────────
  static const String testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testMrecId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testAppOpenId = 'ca-app-pub-3940256099942544/9257395921';
  static const String testRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String testRewardedInterstitialId = 'ca-app-pub-3940256099942544/5354046379';
  static const String testNativeId = 'ca-app-pub-3940256099942544/2247696110';
}
