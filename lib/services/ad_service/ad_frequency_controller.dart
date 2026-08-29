import 'ad_config.dart';

/// Manages impression frequency caps, cooldowns, session caps, per-screen
/// native limits, and user action counters for all AdMob ad types.
///
/// All ad-show decisions flow through this controller — no screen should
/// bypass it to show ads directly.
class AdFrequencyController {
  AdFrequencyController({AdConfig? config})
      : _config = config ?? const AdConfig();

  final AdConfig _config;

  // ── Interstitial tracking ──────────────────────────────────────────
  int _actionCount = 0;
  DateTime? _lastInterstitialTime;
  int _sessionInterstitialCount = 0;

  // ── App Open tracking ──────────────────────────────────────────────
  DateTime? _lastAppOpenTime;

  // ── Per-screen native impression tracking ──────────────────────────
  final Map<String, int> _nativeImpressions = {};

  // ── Getters (for testing / observability) ──────────────────────────
  int get actionCount => _actionCount;
  DateTime? get lastInterstitialTime => _lastInterstitialTime;
  DateTime? get lastAppOpenTime => _lastAppOpenTime;
  int get sessionInterstitialCount => _sessionInterstitialCount;

  /// Increments natural browser action counter (page loads, tab operations,
  /// downloads, history clears, bookmarks, etc.).
  void recordAction() {
    _actionCount++;
  }

  // ═══════════════════════════════════════════════════════════════════
  // INTERSTITIAL
  // ═══════════════════════════════════════════════════════════════════

  /// Evaluates whether an Interstitial Ad is eligible to be shown.
  ///
  /// Checks:
  /// 1. Master + interstitial switches enabled
  /// 2. Minimum action threshold met
  /// 3. Cooldown interval elapsed
  /// 4. Session cap not exceeded
  bool canShowInterstitial() {
    if (!_config.enableAds || !_config.enableInterstitials) return false;

    // Must satisfy minimum action threshold
    if (_actionCount < _config.minimumActionsBetweenInterstitials) return false;

    // Must satisfy cooldown interval
    if (_lastInterstitialTime != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialTime!);
      if (elapsed < _config.cooldownDuration) return false;
    }

    // Must not exceed session cap
    if (_sessionInterstitialCount >= _config.maxInterstitialsPerSession) {
      return false;
    }

    return true;
  }

  /// Records that an interstitial ad was successfully presented.
  void recordInterstitialShown() {
    _lastInterstitialTime = DateTime.now();
    _actionCount = 0;
    _sessionInterstitialCount++;
  }

  // ═══════════════════════════════════════════════════════════════════
  // APP OPEN
  // ═══════════════════════════════════════════════════════════════════

  /// Evaluates whether an App Open Ad is eligible to be shown on app
  /// launch / resume.
  bool canShowAppOpen() {
    if (!_config.enableAds || !_config.enableAppOpenAds) return false;

    // Enforce configured cooldown on App Open ads
    if (_lastAppOpenTime != null) {
      final elapsed = DateTime.now().difference(_lastAppOpenTime!);
      if (elapsed < _config.appOpenCooldownDuration) return false;
    }

    return true;
  }

  /// Records that an App Open ad was successfully presented.
  void recordAppOpenShown() {
    _lastAppOpenTime = DateTime.now();
  }

  // ═══════════════════════════════════════════════════════════════════
  // NATIVE / BANNER (per-screen)
  // ═══════════════════════════════════════════════════════════════════

  /// Returns true if a native/banner ad can be shown on [screenId].
  ///
  /// Checks the per-screen impression limit ([AdConfig.maxNativeAdsPerScreen]).
  bool canShowNativeAd(String screenId) {
    if (!_config.enableAds) return false;
    final count = _nativeImpressions[screenId] ?? 0;
    return count < _config.maxNativeAdsPerScreen;
  }

  /// Returns true if a specific placement is enabled in the config.
  bool isPlacementEnabled(String placementKey) {
    switch (placementKey) {
      case 'homeNative':
        return _config.homeNativeAd;
      case 'homeBanner':
        return _config.homeBanner;
      case 'tabsNative':
        return _config.tabsNativeAd;
      case 'historyNative':
        return _config.historyNativeAd;
      case 'downloadsNative':
        return _config.downloadsNativeAd;
      case 'bookmarksNative':
        return _config.bookmarksNativeAd;
      default:
        return false;
    }
  }

  /// Records that a native ad impression occurred on [screenId].
  void recordNativeImpression(String screenId) {
    _nativeImpressions[screenId] =
        (_nativeImpressions[screenId] ?? 0) + 1;
  }

  // ═══════════════════════════════════════════════════════════════════
  // SESSION MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Resets per-session state. Call on cold start.
  void resetSession() {
    _sessionInterstitialCount = 0;
    _nativeImpressions.clear();
  }

  /// Resets all frequency state (useful for tests).
  void reset() {
    _actionCount = 0;
    _lastInterstitialTime = null;
    _lastAppOpenTime = null;
    _sessionInterstitialCount = 0;
    _nativeImpressions.clear();
  }
}
