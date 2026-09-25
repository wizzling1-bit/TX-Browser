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
    final allDomains = <String>{
      ..._matcher.adDomains,
      ..._matcher.trackerDomains,
      ..._matcher.malwareDomains,
    };

    final seenPatterns = <String>{};
    for (final domain in allDomains) {
      final escaped = RegExp.escape(domain);
      final pattern = '.*$escaped.*';
      if (seenPatterns.add(pattern)) {
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
      '.ad-box, '
      '.ad-zone, '
      '.ad_unit, '
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
      'div[class*="popup_ad"], '
      'div[id*="popup_ad"], '
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
      'div[class*="native-ad"], '
      'div[id*="native-ad"], '
      'div[id^="ad_"], '
      'div[class^="ad_"], '
      'div[id*="exo_"], '
      'div[class*="exo_"], '
      'div[id*="juicy_"], '
      'div[class*="juicy_"], '
      'a[href*="highcpm"], '
      'a[href*="onclick"], '
      'a[href*="adsterra"], '
      'a[href*="exoclick"], '
      'a[href*="juicyads"], '
      'a[href*="monetag"], '
      'a[href*="clickadu"], '
      'a[href*="deloton"], '
      'iframe[src*="exoclick"], '
      'iframe[src*="juicyads"], '
      'iframe[src*="adsterra"], '
      'iframe[src*="doubleclick"], '
      'iframe[src*="adservice"], '
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

        // ── 0. Defuse Inline Ad Pipelines & Popunder Queues ──
        try {
          window.mfAdsSpots = [];
          Object.defineProperty(window, 'mfAdsSpots', {
            get: () => [],
            set: () => {},
            configurable: false,
          });
          window.mfAdsQueue = { installed: true, push: () => {} };
          Object.defineProperty(window, 'mfAdsQueue', {
            get: () => ({ installed: true, push: () => {} }),
            set: () => {},
            configurable: false,
          });
          window.mfAdsPopDone = {};
          window.mfAdsWeightsFetch = 'fail';
        } catch(e) {}

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
            .bottom-adv,
            .footer-adv,
            ins[data-revive-zoneid],
            ins[class*="revive"],
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
            div[class*="inpp"],
            div[id*="inpp"],
            div[class*="videobaba"],
            div[id*="videobaba"],
            div[class*="asg_"],
            div[id*="asg_"],
            div[id*="exo_"],
            div[class*="exo_"],
            div[id*="juicy_"],
            div[class*="juicy_"],
            iframe[src*="videobaba"],
            iframe[src*="ronracepub"],
            iframe[src*="blazingserver"],
            iframe[src*="revive"],
            iframe[src*="exoclick"],
            iframe[src*="juicyads"],
            iframe[src*="adsterra"],
            iframe[src*="doubleclick"],
            iframe[src*="trafficstars"],
            iframe[src*="trafficjunky"],
            iframe[src*="eroadvertising"],
            iframe[src*="twinred"],
            iframe[src*="rollerads"],
            iframe[src*="popmyads"],
            iframe[src*="criteo"],
            iframe[src*="outbrain"],
            iframe[src*="taboola"],
            ins.adsbygoogle,
            div[id^="google_ads_"],
            div[id^="aswift_"],
            div[class*="popup_banner"],
            div[class*="banner_popup"],
            div[class*="floating-banner"],
            div[id*="floating-banner"],
            div[class*="sticky-bottom-banner"],
            div[class*="footer-banner"],
            div[class*="ad_box"],
            div[class*="ad-box"],
            div[class*="ad-holder"],
            .ad-placement,
            .ad-spot,
            .ad-under-player,
            .sponsored-content,
            .textads,
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

        // ── 2. Strict Popunder, Clickunder & window.open Trap Neutralizer ──
        try {
          const originalOpen = window.open;
          window.open = function(url, target, features) {
            // If window.open was triggered without a target URL or with empty/about:blank
            if (!url || url === 'about:blank' || url === '' || typeof url !== 'string') {
              console.warn('[TxShield] Suppressed blank window.open attempt');
              return {
                closed: false,
                close: function() {},
                focus: function() {},
                blur: function() {},
                location: { href: '' },
              };
            }

            const lower = url.toLowerCase();
            // Block known popunder, clickunder, and ad delivery networks
            if (
              lower.includes('videobaba') ||
              lower.includes('ronracepub') ||
              lower.includes('blazingserver') ||
              lower.includes('racerads') ||
              lower.includes('revive') ||
              lower.includes('adsterra') ||
              lower.includes('exoclick') ||
              lower.includes('monetag') ||
              lower.includes('popads') ||
              lower.includes('popcash') ||
              lower.includes('onclick') ||
              lower.includes('highcpm') ||
              lower.includes('juicyads') ||
              lower.includes('clickadu') ||
              lower.includes('hilltopads') ||
              lower.includes('traffichaus') ||
              lower.includes('plugrush') ||
              lower.includes('bet365') ||
              lower.includes('streamate') ||
              lower.includes('trafficstars') ||
              lower.includes('trafficjunky') ||
              lower.includes('eroadvertising') ||
              lower.includes('twinred') ||
              lower.includes('rollerads') ||
              lower.includes('popmyads') ||
              lower.includes('propellerads') ||
              lower.includes('richads') ||
              lower.includes('criteo') ||
              lower.includes('outbrain') ||
              lower.includes('taboola') ||
              lower.includes('mgid') ||
              lower.includes('revcontent') ||
              lower.includes('adcash')
            ) {
              console.warn('[TxShield] Blocked ad window.open:', url);
              return null;
            }

            // Mobile security: Block arbitrary third-party popunder redirects on user clicks
            try {
              const destHost = new URL(url, window.location.href).hostname.replace(/^www\./, '');
              const currHost = window.location.hostname.replace(/^www\./, '');
              if (destHost !== currHost && !destHost.endsWith('.' + currHost)) {
                if (!destHost.includes('google.com') && !destHost.includes('facebook.com') && !destHost.includes('apple.com')) {
                  console.warn('[TxShield] Blocked external popup to:', destHost);
                  return null;
                }
              }
            } catch(e) {}

            return originalOpen.apply(this, arguments);
          };
        } catch(e) {}

        // ── 3. Dynamic DOM Overlay & Invisible Click Trap Cleaner ──
        function cleanOverlaysAndClickTraps() {
          try {
            // Defuse known popunder queues and click hijack globals
            try {
              window._pop = undefined;
              window._pao = undefined;
              window.__mfAds = undefined;
              window._asg = undefined;
              window.popns = undefined;
            } catch(_) {}

            // Collapse ad iframes and known ad anchor wrappers immediately
            const adIframes = document.querySelectorAll('iframe[src*="videobaba"], iframe[src*="ronracepub"], iframe[src*="blazingserver"], iframe[src*="revive"], iframe[src*="doubleclick"], iframe[src*="exoclick"], iframe[src*="juicyads"], iframe[src*="adsterra"], iframe[src*="adservice"], iframe[src*="realsrv"], iframe[src*="tsyndicate"], iframe[src*="adcash"], iframe[src*="popads"], iframe[src*="monetag"], iframe[src*="clickadu"], iframe[src*="highcpm"], iframe[src*="wpadmngr"], iframe[src*="onclick"], iframe[src*="trafficstars"], iframe[src*="trafficjunky"], iframe[src*="eroadvertising"], iframe[src*="twinred"], iframe[src*="rollerads"], iframe[src*="popmyads"]');
            for (let i = 0; i < adIframes.length; i++) {
              adIframes[i].remove();
            }

            // Find full-screen transparent click traps and popunder triggers
            const allElements = document.querySelectorAll('div, section, aside, span, a');
            for (let i = 0; i < allElements.length; i++) {
              const el = allElements[i];
              // Never touch video player or audio containers
              if (el.tagName === 'VIDEO' || el.tagName === 'AUDIO' || el.closest('video') || el.closest('#movie_player') || el.closest('.html5-video-player')) {
                continue;
              }

              if (el.tagName === 'A' && el.href) {
                const h = el.href.toLowerCase();
                if (h.includes('highcpm') || h.includes('onclickalgo') || h.includes('adsterra') || h.includes('exoclick') || h.includes('monetag') || h.includes('clickadu') || h.includes('deloton') || h.includes('wpush') || h.includes('propush') || h.includes('hilltopads') || h.includes('videobaba') || h.includes('ronracepub') || h.includes('blazingserver')) {
                  el.remove();
                  continue;
                }
              }

              const style = window.getComputedStyle(el);
              const zIndex = parseInt(style.zIndex, 10);
              const isFixed = style.position === 'fixed' || style.position === 'absolute';

              if (isFixed && zIndex > 999) {
                const isFullScreen = (el.offsetWidth >= window.innerWidth * 0.90 && el.offsetHeight >= window.innerHeight * 0.90);
                const isTransparent = parseFloat(style.opacity) === 0 || style.backgroundColor === 'transparent' || style.backgroundColor === 'rgba(0, 0, 0, 0)';

                // Remove transparent click catchers
                if (isFullScreen && isTransparent && el.children.length === 0) {
                  el.remove();
                  continue;
                }

                // Check for floating ad card overlays containing ad banners / promo texts
                const html = el.innerHTML || '';
                if (
                  html.includes('doubleclick') ||
                  html.includes('exoclick') ||
                  html.includes('adsterra') ||
                  html.includes('juicyads') ||
                  html.includes('adcash') ||
                  html.includes('monetag') ||
                  html.includes('popads') ||
                  html.includes('highcpm') ||
                  html.includes('onclick') ||
                  html.includes('videobaba') ||
                  html.includes('ronracepub') ||
                  html.includes('blazingserver') ||
                  (el.className && typeof el.className === 'string' && (el.className.includes('ad-') || el.className.includes('overlay_ad') || el.className.includes('pop_ad') || el.className.includes('floating_ad') || el.className.includes('banner_ad') || el.className.includes('inpp')))
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
            }, 100);
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
      forMainFrameOnly: false,
    );
  }
}
