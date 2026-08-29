import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'rule_matcher.dart';

export 'rule_matcher.dart' show BlockDecision, BlockReason, BlockDiagnosticLog;

/// Production-Grade Content Blocking & Privacy Engine (Tx Shield).
///
/// Multi-Layer Architecture:
/// 1. Native WebKit/Chromium ContentBlockers (C++ level).
/// 2. Android ServiceWorker Request Interceptor ([ServiceWorkerController]).
/// 3. Dart Subresource Request Interceptor ([shouldInterceptRequest]).
/// 4. Popup, Popunder & Forced Redirect Interceptor ([onCreateWindow] & [shouldOverrideUrlLoading]).
/// 5. Document-Start Cosmetic Stylesheet, Popunder Defuser & Click Trap Cleaner ([UserScript]).
/// 6. In-Memory Sub-Millisecond Decision Matcher ([RuleMatcher]).
/// 7. Persistent Per-Site Allowlist & Custom Rules.
class ContentBlockerService {
  ContentBlockerService() : _matcher = RuleMatcher();

  final RuleMatcher _matcher;
  bool _isGlobalEnabled = true;

  bool get isGlobalEnabled => _isGlobalEnabled;
  void setGlobalEnabled(bool enabled) => _isGlobalEnabled = enabled;

  RuleMatcher get matcher => _matcher;

  void updateAllowlist(Set<String> hosts) {
    _matcher.updateAllowlist(hosts);
  }

  void updateCustomBlocklist(Set<String> hosts) {
    _matcher.updateCustomBlocklist(hosts);
  }

  /// Initializes Android ServiceWorker interception so service workers cannot bypass blocking.
  Future<void> initServiceWorkerInterception() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final swController = ServiceWorkerController.instance();
      await swController.setServiceWorkerClient(
        ServiceWorkerClient(
          shouldInterceptRequest: (request) async {
            final decision = evaluateRequest(
              requestUrl: request.url.toString(),
              pageHost: null,
            );

            if (decision.isBlocked) {
              return WebResourceResponse(
                contentType: 'text/plain',
                data: Uint8List(0),
                statusCode: 200,
                reasonPhrase: 'Blocked by Tx Shield ServiceWorker',
              );
            }
            return null;
          },
        ),
      );
    } catch (e) {
      debugPrint('[TxShield] ServiceWorkerController init note: $e');
    }
  }

  /// Determines whether an incoming resource request should be blocked.
  BlockDecision evaluateRequest({
    required String requestUrl,
    required String? pageHost,
    String? resourceType,
  }) {
    if (!_isGlobalEnabled) {
      return const BlockDecision.allow();
    }

    return _matcher.evaluate(
      requestUrl: requestUrl,
      pageHost: pageHost,
      resourceType: resourceType,
    );
  }

  /// Determines whether a popup or top-level navigation redirect should be blocked.
  BlockDecision evaluatePopupOrNavigation({
    required String destinationUrl,
    required String? pageHost,
  }) {
    if (!_isGlobalEnabled) {
      return const BlockDecision.allow();
    }

    return _matcher.evaluatePopupOrNavigation(
      destinationUrl: destinationUrl,
      pageHost: pageHost,
    );
  }

  /// Generates native [ContentBlocker] rules for [InAppWebViewSettings.contentBlockers].
  List<ContentBlocker> generateNativeBlockers() {
    if (!_isGlobalEnabled) return const [];

    final blockers = <ContentBlocker>[];

    // High-Frequency Native URL Filter Rules (C++ level)
    final highFrequencyPatterns = [
      '.*doubleclick\\.net.*',
      '.*googlesyndication\\.com.*',
      '.*adservice\\.google\\.com.*',
      '.*googleadservices\\.com.*',
      '.*google-analytics\\.com.*',
      '.*amazon-adsystem\\.com.*',
      '.*adnxs\\.com.*',
      '.*criteo\\..*',
      '.*pubmatic\\.com.*',
      '.*rubiconproject\\.com.*',
      '.*openx\\..*',
      '.*taboola\\.com.*',
      '.*outbrain\\.com.*',
      '.*scorecardresearch\\.com.*',
      '.*clarity\\.ms.*',
      '.*hotjar\\.com.*',
      '.*segment\\.(io|com).*',
      '.*amplitude\\.com.*',
      '.*mixpanel\\.com.*',
      '.*branch\\.io.*',
      '.*adjust\\.com.*',
      '.*appsflyer\\.com.*',
      '.*popads\\.net.*',
      '.*propellerads\\.com.*',
      '.*smartadserver\\.com.*',
      '.*yieldmo\\.com.*',
      '.*sharethrough\\.com.*',
      '.*triplelift\\.com.*',
      '.*sovrn\\.com.*',
      '.*lijit\\.com.*',
      '.*teads\\.tv.*',
      '.*spotxchange\\.com.*',
      '.*revcontent\\.com.*',
      '.*mgid\\.com.*',
      '.*media\\.net.*',
      '.*exoclick\\.com.*',
      '.*juicyads\\.com.*',
      '.*adsterra\\..*',
      '.*trafficjunky\\.com.*',
      '.*trafficstars\\.com.*',
      '.*adcash\\.com.*',
      '.*onclickads\\.net.*',
      '.*monetag\\.com.*',
      '.*hilltopads\\.com.*',
      '.*popcash\\.net.*',
      '.*zeroredirect1\\.com.*',
      '.*realsrv\\.com.*',
      '.*tsyndicate.*',
      '.*dtiserv.*',
      '.*clickadu\\.com.*',
      '.*admaven\\.com.*',
    ];

    for (final pattern in highFrequencyPatterns) {
      blockers.add(
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: pattern,
          ),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.BLOCK,
          ),
        ),
      );
    }

    // Native Cosmetic CSS Display None Selector
    blockers.add(
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: '.*',
        ),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.CSS_DISPLAY_NONE,
          selector: _cosmeticSelectors,
        ),
      ),
    );

    return blockers;
  }

  /// Comprehensive Cosmetic CSS element selectors for collapsing ad slots, floating cards,
  /// sticky headers/footers, popup overlays, and promotional widgets.
  static const String _cosmeticSelectors =
      'ins.adsbygoogle, '
      'div[id^="google_ads_iframe"], '
      'iframe[id^="aswift_"], '
      'div[id^="div-gpt-ad"], '
      '.ad-banner, '
      '.ad-container, '
      '.ad-wrapper, '
      '.ad-slot, '
      '.advertisement, '
      '.sponsored-post, '
      'div[class*="floating-ad"], '
      'div[id*="floating-ad"], '
      'div[class*="float-ad"], '
      'div[id*="float-ad"], '
      'div[class*="sticky-ad"], '
      'div[id*="sticky-ad"], '
      'div[class*="sticky_ad"], '
      'div[class*="popup-ad"], '
      'div[id*="popup-ad"], '
      'div[class*="popunder"], '
      'div[id*="popunder"], '
      'div[class*="overlay-ad"], '
      'div[id*="overlay-ad"], '
      'div[class*="ad-overlay"], '
      'div[id*="ad_overlay"], '
      'div[class*="interstitial-ad"], '
      'div[id*="interstitial-ad"], '
      'div[class*="modal_ad"], '
      'div[id*="modal_ad"], '
      'div[class*="banner_ad"], '
      'div[id*="exo_"], '
      'div[class*="exo_"], '
      'div[id*="juicy_"], '
      'div[class*="juicy_"], '
      'iframe[src*="exoclick"], '
      'iframe[src*="juicyads"], '
      'iframe[src*="adsterra"], '
      'iframe[src*="doubleclick"], '
      '#taboola-below-article-thumbnails, '
      '#outbrain_widget_0, '
      '.trc_rbox_div, '
      'ytm-promoted-sparkles-web-renderer, '
      'ytd-promoted-video-renderer, '
      'ytm-companion-ad-renderer, '
      'ytd-ad-slot-renderer';

  /// Generates a document-start [UserScript] that:
  /// 1. Injects universal high-priority cosmetic ad hiding styles.
  /// 2. Defuses popunders and unauthorized `window.open` traps.
  /// 3. Neutralizes invisible tap-capture overlay divs.
  /// 4. Restores natural body scrolling when an ad locks the viewport.
  /// 5. Safely auto-clicks YouTube skip buttons without touching player internals.
  UserScript getCosmeticAndYouTubeUserScript() {
    const jsSource = r'''
      (function() {
        if (window.__txShieldInjected) return;
        window.__txShieldInjected = true;

        // ── 1. Inject Universal High-Priority Cosmetic Ad Hiding Styles ──
        try {
          const style = document.createElement('style');
          style.type = 'text/css';
          style.id = '__tx_shield_styles';
          style.innerHTML = `
            ins.adsbygoogle,
            div[id^="google_ads_iframe"],
            iframe[id^="aswift_"],
            div[id^="div-gpt-ad"],
            .ad-banner,
            .ad-container,
            .ad-wrapper,
            .ad-slot,
            .advertisement,
            .sponsored-post,
            div[class*="floating-ad"],
            div[id*="floating-ad"],
            div[class*="float-ad"],
            div[id*="float-ad"],
            div[class*="sticky-ad"],
            div[id*="sticky-ad"],
            div[class*="sticky_ad"],
            div[class*="popup-ad"],
            div[id*="popup-ad"],
            div[class*="popunder"],
            div[id*="popunder"],
            div[class*="overlay-ad"],
            div[id*="overlay-ad"],
            div[class*="ad-overlay"],
            div[id*="ad_overlay"],
            div[class*="interstitial-ad"],
            div[id*="interstitial-ad"],
            div[class*="modal_ad"],
            div[id*="modal_ad"],
            div[class*="banner_ad"],
            div[id*="exo_"],
            div[class*="exo_"],
            div[id*="juicy_"],
            div[class*="juicy_"],
            iframe[src*="exoclick"],
            iframe[src*="juicyads"],
            iframe[src*="adsterra"],
            iframe[src*="doubleclick"],
            #taboola-below-article-thumbnails,
            #outbrain_widget_0,
            .trc_rbox_div,
            ytm-promoted-sparkles-web-renderer,
            ytd-promoted-video-renderer,
            ytm-companion-ad-renderer,
            ytd-ad-slot-renderer {
              display: none !important;
              visibility: hidden !important;
              height: 0 !important;
              max-height: 0 !important;
              opacity: 0 !important;
              pointer-events: none !important;
            }
          `;
          const target = document.head || document.documentElement;
          if (target) target.appendChild(style);
        } catch(e) {}

        // ── 2. Popunder & window.open Trap Defuser ──
        try {
          const originalOpen = window.open;
          let lastUserTapTime = 0;
          document.addEventListener('pointerup', function() {
            lastUserTapTime = Date.now();
          }, true);

          window.open = function(url, target, features) {
            const timeSinceTap = Date.now() - lastUserTapTime;
            // If window.open was triggered without a genuine recent user tap (< 400ms), neutralize it
            if (timeSinceTap > 500 && !features) {
              console.warn('[TxShield] Blocked automated window.open:', url);
              return null;
            }
            return originalOpen.apply(this, arguments);
          };
        } catch(e) {}

        // ── 3. Dynamic DOM Overlay & Invisible Click Trap Cleaner ──
        function cleanOverlaysAndClickTraps() {
          try {
            // Find full-screen transparent click traps (z-index > 9000 with 0 opacity or 100vw/100vh)
            const allElements = document.querySelectorAll('div, section, aside, span');
            for (let i = 0; i < allElements.length; i++) {
              const el = allElements[i];
              // Never touch video player or audio containers
              if (el.tagName === 'VIDEO' || el.tagName === 'AUDIO' || el.closest('video') || el.closest('#movie_player') || el.closest('.html5-video-player')) {
                continue;
              }

              const style = window.getComputedStyle(el);
              const zIndex = parseInt(style.zIndex, 10);
              const isFixed = style.position === 'fixed' || style.position === 'absolute';

              if (isFixed && zIndex > 9999) {
                const isFullScreen = (el.offsetWidth >= window.innerWidth * 0.95 && el.offsetHeight >= window.innerHeight * 0.95);
                const isTransparent = parseFloat(style.opacity) === 0 || style.backgroundColor === 'transparent' || style.backgroundColor === 'rgba(0, 0, 0, 0)';

                // Remove transparent click catchers
                if (isFullScreen && isTransparent && el.children.length === 0) {
                  el.remove();
                  continue;
                }

                // Check for floating ad card overlays containing ad banners / promo texts
                const text = el.innerText || '';
                const html = el.innerHTML || '';
                if (
                  html.includes('doubleclick') ||
                  html.includes('exoclick') ||
                  html.includes('adsterra') ||
                  html.includes('juicyads') ||
                  html.includes('adcash') ||
                  html.includes('monetag') ||
                  html.includes('popads') ||
                  (el.className && typeof el.className === 'string' && (el.className.includes('ad-') || el.className.includes('overlay_ad') || el.className.includes('pop_ad')))
                ) {
                  el.style.display = 'none';
                  el.style.visibility = 'hidden';
                  el.style.pointerEvents = 'none';
                }
              }
            }

            // Restore body scroll if an ad script locked scrolling
            if (document.body) {
              const bodyStyle = window.getComputedStyle(document.body);
              if (bodyStyle.overflow === 'hidden' && !document.querySelector('.modal-open, .lightbox-open')) {
                document.body.style.overflow = 'auto';
              }
            }
          } catch(e) {}
        }

        // Run DOM cleaner periodically & on mutations
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', cleanOverlaysAndClickTraps);
        } else {
          cleanOverlaysAndClickTraps();
        }

        let cleanupTimer = null;
        const observer = new MutationObserver(function() {
          if (!cleanupTimer) {
            cleanupTimer = setTimeout(function() {
              cleanOverlaysAndClickTraps();
              cleanupTimer = null;
            }, 350);
          }
        });

        observer.observe(document.documentElement || document.body, {
          childList: true,
          subtree: true,
        });

        // ── 4. YouTube Safe Auto-Skipper ──
        function checkAndSkipYouTubeAd() {
          if (!location.hostname.includes('youtube.com')) return;

          try {
            const skipSelectors = [
              '.ytp-ad-skip-button',
              '.ytp-ad-skip-button-modern',
              '.ytp-skip-ad-button',
              '.videoAdUiSkipButton',
              'button.ytp-ad-skip-button-text',
              '.ytp-ad-overlay-close-button'
            ];

            for (const selector of skipSelectors) {
              const btn = document.querySelector(selector);
              if (btn && typeof btn.click === 'function') {
                btn.click();
                break;
              }
            }
          } catch(e) {}
        }

        if (location.hostname.includes('youtube.com')) {
          setInterval(checkAndSkipYouTubeAd, 500);
          document.addEventListener('DOMContentLoaded', checkAndSkipYouTubeAd);
        }
      })();
    ''';

    return UserScript(
      source: jsSource,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );
  }
}
