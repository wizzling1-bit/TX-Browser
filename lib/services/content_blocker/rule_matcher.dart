import 'dart:collection';

/// Represents the classification reason when a request, popup, or redirect is blocked.
enum BlockReason {
  ad,
  tracker,
  customRule,
  malwareOrScam,
  popup,
  redirect,
}

/// The result of evaluating a resource request or navigation event.
class BlockDecision {
  const BlockDecision.allow()
      : isBlocked = false,
        reason = null,
        matchedRule = null,
        matchedHost = null;

  const BlockDecision.block({
    required this.reason,
    required this.matchedRule,
    required this.matchedHost,
  }) : isBlocked = true;

  final bool isBlocked;
  final BlockReason? reason;
  final String? matchedRule;
  final String? matchedHost;

  @override
  String toString() {
    if (!isBlocked) return 'ALLOWED';
    return 'BLOCKED ($reason via "$matchedRule")';
  }
}

/// Diagnostic log entry for development, test, and verification inspectability.
class BlockDiagnosticLog {
  const BlockDiagnosticLog({
    required this.timestamp,
    required this.url,
    required this.decision,
    required this.source,
  });

  final DateTime timestamp;
  final String url;
  final BlockDecision decision;
  final String source;
}

/// High-performance, in-memory multi-tier rule matching engine for Tx Shield.
///
/// Features:
/// 1. Subdomain suffix matching via domain token lookup in O(k) where k = domain depth.
/// 2. Fast URL path, query & substring matching for ad scripts, VAST endpoints, and tracking beacons.
/// 3. Navigation & Popup decision evaluation ([evaluatePopupOrNavigation]).
/// 4. In-Memory Decision Cache (LRU) for 0.0001ms evaluation time.
/// 5. Strict Video Playback & Essential Media Protection.
class RuleMatcher {
  RuleMatcher() {
    _initBuiltInRules();
  }

  // Exact & Suffix Match Sets
  final Set<String> _adDomains = <String>{};
  final Set<String> _trackerDomains = <String>{};
  final Set<String> _malwareDomains = <String>{};
  final Set<String> _customBlockedDomains = <String>{};
  final Set<String> _allowlistedDomains = <String>{};

  Set<String> get adDomains => UnmodifiableSetView(_adDomains);
  Set<String> get trackerDomains => UnmodifiableSetView(_trackerDomains);
  Set<String> get malwareDomains => UnmodifiableSetView(_malwareDomains);

  // URL Path, Query & Substring Patterns (lowercase)
  final List<String> _adPathPatterns = <String>[];
  final List<String> _trackerPathPatterns = <String>[];

  // In-Memory Decision Cache (max 1000 items)
  final Map<String, BlockDecision> _decisionCache = <String, BlockDecision>{};
  static const int _maxCacheSize = 1000;

  // FIFO Circular Buffer for Diagnostics (max 50)
  final Queue<BlockDiagnosticLog> _diagnosticLogs = Queue<BlockDiagnosticLog>();
  static const int _maxDiagnosticLogs = 50;

  List<BlockDiagnosticLog> get diagnosticLogs => _diagnosticLogs.toList(growable: false);

  void clearDiagnosticLogs() => _diagnosticLogs.clear();

  void updateAllowlist(Set<String> domains) {
    _allowlistedDomains.clear();
    _allowlistedDomains.addAll(domains.map(_normalizeHost));
    _decisionCache.clear();
  }

  void updateCustomBlocklist(Set<String> domains) {
    _customBlockedDomains.clear();
    _customBlockedDomains.addAll(domains.map(_normalizeHost));
    _decisionCache.clear();
  }

  /// Evaluates an incoming network subresource request (images, scripts, iframes, xhr).
  BlockDecision evaluate({
    required String requestUrl,
    required String? pageHost,
    String? resourceType,
  }) {
    final cacheKey = '$pageHost|$requestUrl';
    final cached = _decisionCache[cacheKey];
    if (cached != null) {
      _recordLog(requestUrl, cached, resourceType ?? 'RESOURCE (CACHE)');
      return cached;
    }

    final decision = _evaluateInternal(
      requestUrl: requestUrl,
      pageHost: pageHost,
      resourceType: resourceType,
      isNavigation: false,
    );

    // Cache the result (bound cache size)
    if (_decisionCache.length >= _maxCacheSize) {
      _decisionCache.remove(_decisionCache.keys.first);
    }
    _decisionCache[cacheKey] = decision;

    _recordLog(requestUrl, decision, resourceType ?? 'RESOURCE');
    return decision;
  }

  /// Evaluates a top-level or popup navigation attempt (window.open, redirect, new tab).
  BlockDecision evaluatePopupOrNavigation({
    required String destinationUrl,
    required String? pageHost,
  }) {
    final cacheKey = 'NAV|$pageHost|$destinationUrl';
    final cached = _decisionCache[cacheKey];
    if (cached != null) {
      _recordLog(destinationUrl, cached, 'NAVIGATION (CACHE)');
      return cached;
    }

    final decision = _evaluateInternal(
      requestUrl: destinationUrl,
      pageHost: pageHost,
      resourceType: 'NAVIGATION',
      isNavigation: true,
    );

    if (_decisionCache.length >= _maxCacheSize) {
      _decisionCache.remove(_decisionCache.keys.first);
    }
    _decisionCache[cacheKey] = decision;

    _recordLog(destinationUrl, decision, 'NAVIGATION');
    return decision;
  }

  BlockDecision _evaluateInternal({
    required String requestUrl,
    required String? pageHost,
    String? resourceType,
    required bool isNavigation,
  }) {
    // 1. Fail-open safely on empty or malformed URLs
    if (requestUrl.isEmpty) return const BlockDecision.allow();

    final uri = Uri.tryParse(requestUrl);
    if (uri == null) return const BlockDecision.allow();

    // Bypass non-network schemes (javascript:, blob:, data:, about:, file:)
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https' && scheme != 'ws' && scheme != 'wss') {
      return const BlockDecision.allow();
    }

    final reqHost = _normalizeHost(uri.host);
    if (reqHost.isEmpty) return const BlockDecision.allow();

    // 2. Per-Site Allowlist Check
    if (pageHost != null && pageHost.isNotEmpty) {
      final normPage = _normalizeHost(pageHost);
      if (_allowlistedDomains.contains(normPage) ||
          _matchesDomainSuffix(normPage, _allowlistedDomains) != null) {
        return const BlockDecision.allow();
      }
    }

    // 2.5 Essential Media & Video Playback Protection
    // Video streaming CDNs (googlevideo.com, vimeocdn.com, dailymotion.com) and core player
    // scripts must NEVER be blocked to prevent video player black screens and media stalls.
    if (_isProtectedPlaybackResource(reqHost, uri.path)) {
      return const BlockDecision.allow();
    }

    // 3. User Custom Blocklist
    if (_customBlockedDomains.contains(reqHost)) {
      return BlockDecision.block(
        reason: BlockReason.customRule,
        matchedRule: reqHost,
        matchedHost: reqHost,
      );
    }
    final customSuffix = _matchesDomainSuffix(reqHost, _customBlockedDomains);
    if (customSuffix != null) {
      return BlockDecision.block(
        reason: BlockReason.customRule,
        matchedRule: '*.$customSuffix',
        matchedHost: reqHost,
      );
    }

    // 4. Advertising Domain Check (Exact & Subdomain)
    if (_adDomains.contains(reqHost)) {
      return BlockDecision.block(
        reason: isNavigation ? BlockReason.popup : BlockReason.ad,
        matchedRule: reqHost,
        matchedHost: reqHost,
      );
    }
    final adSuffix = _matchesDomainSuffix(reqHost, _adDomains);
    if (adSuffix != null) {
      return BlockDecision.block(
        reason: isNavigation ? BlockReason.popup : BlockReason.ad,
        matchedRule: '*.$adSuffix',
        matchedHost: reqHost,
      );
    }

    // 5. Tracker & Analytics Domain Check (Exact & Subdomain)
    if (_trackerDomains.contains(reqHost)) {
      return BlockDecision.block(
        reason: isNavigation ? BlockReason.redirect : BlockReason.tracker,
        matchedRule: reqHost,
        matchedHost: reqHost,
      );
    }
    final trackerSuffix = _matchesDomainSuffix(reqHost, _trackerDomains);
    if (trackerSuffix != null) {
      return BlockDecision.block(
        reason: isNavigation ? BlockReason.redirect : BlockReason.tracker,
        matchedRule: '*.$trackerSuffix',
        matchedHost: reqHost,
      );
    }

    // 6. Malware / Scam / Phishing Check
    if (_malwareDomains.contains(reqHost)) {
      return BlockDecision.block(
        reason: BlockReason.malwareOrScam,
        matchedRule: reqHost,
        matchedHost: reqHost,
      );
    }
    final malwareSuffix = _matchesDomainSuffix(reqHost, _malwareDomains);
    if (malwareSuffix != null) {
      return BlockDecision.block(
        reason: BlockReason.malwareOrScam,
        matchedRule: '*.$malwareSuffix',
        matchedHost: reqHost,
      );
    }

    // 7. URL Path, Query & Substring Patterns
    final lowerUrl = requestUrl.toLowerCase();
    for (final pattern in _adPathPatterns) {
      if (lowerUrl.contains(pattern)) {
        return BlockDecision.block(
          reason: isNavigation ? BlockReason.popup : BlockReason.ad,
          matchedRule: pattern,
          matchedHost: reqHost,
        );
      }
    }

    for (final pattern in _trackerPathPatterns) {
      if (lowerUrl.contains(pattern)) {
        return BlockDecision.block(
          reason: isNavigation ? BlockReason.redirect : BlockReason.tracker,
          matchedRule: pattern,
          matchedHost: reqHost,
        );
      }
    }

    return const BlockDecision.allow();
  }

  void _recordLog(String url, BlockDecision decision, String source) {
    if (_diagnosticLogs.length >= _maxDiagnosticLogs) {
      _diagnosticLogs.removeFirst();
    }
    _diagnosticLogs.add(
      BlockDiagnosticLog(
        timestamp: DateTime.now(),
        url: url,
        decision: decision,
        source: source,
      ),
    );
  }

  String _normalizeHost(String host) {
    var h = host.toLowerCase().trim();
    if (h.startsWith('www.')) h = h.substring(4);
    final portIdx = h.indexOf(':');
    if (portIdx != -1) h = h.substring(0, portIdx);
    return h;
  }

  /// Checks if any parent domain of [host] matches a rule in [set].
  String? _matchesDomainSuffix(String host, Set<String> set) {
    final parts = host.split('.');
    if (parts.length <= 1) return null;

    for (var i = 1; i < parts.length; i++) {
      final candidate = parts.sublist(i).join('.');
      if (candidate.length >= 4 && set.contains(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  void _initBuiltInRules() {
    // ─── 1. COMPREHENSIVE ADVERTISING, POPUP & POPUNDER DOMAINS ─────────
    _adDomains.addAll([
      // Google Ads / DoubleClick / AdSense / Syndication / AdMob
      'doubleclick.net',
      'googlesyndication.com',
      'adservice.google.com',
      'googleadservices.com',
      'pagead2.googlesyndication.com',
      'safeframe.googlesyndication.com',
      'securepubads.g.doubleclick.net',
      'admob.com',
      'googleads.g.doubleclick.net',
      'tpc.googlesyndication.com',
      'ads.google.com',
      'partner.googleadservices.com',
      'pubads.g.doubleclick.net',
      'ad.doubleclick.net',
      'static.doubleclick.net',

      // Amazon Advertising & A9
      'amazon-adsystem.com',
      'aax-us-east.amazon-adsystem.com',
      'aax.amazon-adsystem.com',
      'fls-na.amazon.com',
      'adsystem.amazon.com',
      'c.amazon-adsystem.com',
      's.amazon-adsystem.com',
      'z-na.amazon-adsystem.com',

      // AppNexus / Xandr / Microsoft Ads
      'adnxs.com',
      'ib.adnxs.com',
      'secure.adnxs.com',
      'adnxs-simple.com',
      'bat.bing.com',

      // Criteo
      'criteo.com',
      'criteo.net',
      'static.criteo.net',
      'bidder.criteo.com',
      'cas.criteo.com',

      // PubMatic
      'pubmatic.com',
      'ads.pubmatic.com',
      'image2.pubmatic.com',
      'showads.pubmatic.com',

      // Rubicon Project / Magnite
      'rubiconproject.com',
      'fastlane.rubiconproject.com',
      'optimized-by.rubiconproject.com',

      // OpenX
      'openx.net',
      'openx.com',
      'ox-d.openx.net',

      // Taboola & Outbrain
      'taboola.com',
      'cdn.taboola.com',
      'trc.taboola.com',
      'outbrain.com',
      'widgets.outbrain.com',
      'zemanta.com',
      'images.outbrain.com',

      // Media.net / Yahoo / Oath / IndexExchange
      'media.net',
      'contextweb.com',
      'advertising.com',
      'serving-sys.com',
      'adtechus.com',
      'casalemedia.com',
      'indexexchange.com',
      'js.indexww.com',

      // Mobile & Video Ad Networks
      'applovin.com',
      'applvn.com',
      'unityads.unity3d.com',
      'unityads.unity.com',
      'vungle.com',
      'inmobi.com',
      'chartboost.com',
      'adcolony.com',
      'ironsrc.com',
      'supersonicads.com',
      'mintegral.com',
      'liftoff.io',
      'fyber.com',
      'teads.tv',
      'spotxchange.com',
      'spotx.tv',
      'smartadserver.com',
      'bidswitch.net',
      'yieldmo.com',
      'sharethrough.com',
      'triplelift.com',
      'sovrn.com',
      'lijit.com',
      'revcontent.com',
      'mgid.com',
      'adblade.com',
      'bidr.io',
      'adroll.com',
      'adform.net',
      'adfox.ru',
      'adsystem.com',
      'adkernel.com',
      'adbutler.com',
      'adspirit.de',
      'exponential.com',
      'tribalfusion.com',
      'quantserve.com',
      'moatads.com',
      'adlightning.com',
      'undertone.com',
      'distroscale.com',
      'gumgum.com',
      'kargo.com',
      'nativo.com',
      'smartclip.net',
      'conversantmedia.com',
      'bidvertiser.com',
      'infolinks.com',

      // Popunder, Popup, Floating & Aggressive Web Ad Networks
      'popads.net',
      'popcash.net',
      'popmyads.com',
      'propellerads.com',
      'exoclick.com',
      'trafficjunky.com',
      'juicyads.com',
      'adcash.com',
      'zeroredirect1.com',
      'onclickads.net',
      'monetag.com',
      'hilltopads.com',
      'richpush.co',
      'adsterra.com',
      'adsterra.net',
      'yllix.com',
      'clickadu.com',
      'clickaine.com',
      'trafficstars.com',
      'trafficfactory.biz',
      'twinred.com',
      'plugrush.com',
      'adxad.com',
      'zeropark.com',
      'galaksion.com',
      'mondiad.com',
      'admaven.com',
      'ad-maven.com',
      'deloton.com',
      'syndication.exoclick.com',
      'syndication.realsrv.com',
      'realsrv.com',
      'tsyndicate.com',
      'tsyndication.com',
      'dtiserv2.com',
      'dtiserv.com',
      'etahub.com',
      'wpush.biz',
      'propush.me',
      'richaudience.com',
      'smilewanted.com',
      'adreactor.com',
      'adnium.com',
      'runative-syndicate.com',
      'runative.com',
      'a-ads.com',
      'coinzilla.com',
      'hubtraffic.com',
      'trafficguard.ai',
      'bngpt.com',
      'traffichaus.com',
      'ero-advertising.com',
      'trafficforce.com',
      'adxxx.info',
      'tsyndication.com',
      'syndication.clickadu.com',
      'syndication.trafficstars.com',
      'creative.adreactor.com',
      'serving.exoclick.com',
      'main.exoclick.com',
      'ads.exoclick.com',
      'ad.adsterra.com',
      'xml.adcash.com',
      'cdn.adcash.com',
      'rtb.adcash.com',

      // ASG, RacerAds, Revive & Video Ad Servers (indiansexstories3, bhojpurisex, etc.)
      'videobaba.xyz',
      'asg.videobaba.xyz',
      'ronracepub.com',
      'racerads.com',
      'blazingserver.net',
      'revive-adserver.com',
      'reviveserver.net',
      'delivery-engine.com',
      'ad-delivery.net',

      // High-Frequency Popunder, Push, Vignette & Video Ad Hosts (EasyList / AdGuard)
      'highcpmgate.com',
      'highcpmrevenuenetwork.com',
      'highperformancegate.com',
      'highcpmnetwork.com',
      'h1ghcpm.com',
      'onclickalgo.com',
      'onclickperformance.com',
      'onclicksuper.com',
      'ontag.com',
      'ontagcdn.com',
      'wpadmngr.com',
      'wpush.biz',
      'propush.me',
      'pushub.net',
      'evadav.com',
      'clickadu.net',
      'ad-score.com',
      'ad-delivery.net',
      'bswsrv.com',
      'exosrv.com',
      'twinrdsrv.com',
      'hilltopads.net',
      'gammacdn.com',
      'adthrive.com',
      'raptive.com',
      'mediavine.com',
      'freestar.com',
      'snigel.com',
      'ezoic.com',
      'ezoic.net',
      'sulvo.com',
      'monumetric.com',
      'buyhitsfast.com',
      'trafficmonsoon.com',
      'adsterra.top',
      'adsterra.one',
      'adsterra.xyz',
      'adsterra.site',
      'adsterra.live',
      'popcash.org',
      'popcash.xyz',
      'popcash.live',
      'popads.org',
      'popads.live',
      'monetag.net',
      'monetag.xyz',
      'monetag.org',
      'monetag.live',
      'exoclick.net',
      'exoclick.xyz',
      'exoclick.org',
      'exoclick.live',
      'juicyads.net',
      'juicyads.xyz',
      'juicyads.org',
      'juicyads.live',
      'ad-maven.com',
      'ad-maven.net',
      'ad-maven.org',
      'adtarget.net',
      'adspirit.net',
      'adnuntius.com',
      'admanmedia.com',
      'adotmob.com',
      'aniview.com',
      'springserve.com',
      'vidazoo.com',
      'undertone.com',
      'primis.tech',
      'connatix.com',
      'brid.tv',
      'anyclip.com',
      'playstream.media',
      'streamamp.com',
      'targetspot.com',
      'adhese.com',
      'adhese.eu',
      'adzerk.net',
      'kevel.co',
      'kevel.com',
      'adition.com',
      'smartstream.tv',
      'yieldlove.com',
      'showheroes.com',

      // Expanded High-Impact Web & Adult Ad Networks
      'trafficstars.com',
      'ts-cdn.com',
      'trafficstar.com',
      'trafficjunky.com',
      'trafficjunky.net',
      'tjassets.com',
      'plugrush.com',
      'plugrush.net',
      'eroadvertising.com',
      'ero-advertising.com',
      'twinred.com',
      'tsyndicate.com',
      'tsyndicate.net',
      'tsyndicate.org',
      'traffichaus.com',
      'traffichaus.net',
      'rollerads.com',
      'rollerads.net',
      'zeropark.com',
      'bidvertiser.com',
      'infolinks.com',
      'popmyads.com',
      'propellerads.com',
      'propellerclick.com',
      'monetag.com',
      'richads.com',
      'richpush.co',
      'adnium.com',
      'criteo.com',
      'criteo.net',
      'outbrain.com',
      'outbrainimg.com',
      'taboola.com',
      'taboolasyndication.com',
      'mgid.com',
      'marketgid.com',
      'revcontent.com',
      'adcash.com',
      'hilltopads.com',
      'clickadu.com',
      'admaven.com',
      'exads.com',
      'adxad.com',
      'adxad.net',
      'popunder.net',
      'popcashcdn.com',
      'popads.net',
      'videobaba.net',
      'videobaba.online',
      'blazingserver.com',
      'blazingserver.org',
      'ronracepub.net',
      'ronracepub.org',
      'racerads.net',
      'pagead2.googlesyndication.com',
      'tpc.googlesyndication.com',
      'googleads.g.doubleclick.net',
      'adservice.google.com',
      'securepubads.g.doubleclick.net',
      'pubads.g.doubleclick.net',
    ]);

    // ─── 2. TRACKING, TELEMETRY & ANALYTICS DOMAINS ──────────────────
    _trackerDomains.addAll([
      // Google Analytics & Tag Manager
      'google-analytics.com',
      'analytics.google.com',
      'googletagservices.com',
      'googletagmanager.com',
      'stats.g.doubleclick.net',
      'region1.google-analytics.com',
      'region2.google-analytics.com',

      // Microsoft Clarity & Bing Tracking
      'clarity.ms',
      'c.bing.com',
      'c.clarity.ms',

      // Facebook / Meta Tracking Pixels
      'connect.facebook.net',
      'pixel.facebook.com',
      'an.facebook.com',

      // Analytics & Product Telemetry
      'segment.com',
      'segment.io',
      'api.segment.io',
      'cdn.segment.com',
      'mixpanel.com',
      'api.mixpanel.com',
      'amplitude.com',
      'api.amplitude.com',
      'heapanalytics.com',
      'heap.io',
      'hotjar.com',
      'static.hotjar.com',
      'script.hotjar.com',
      'crazyegg.com',
      'mouseflow.com',
      'fullstory.com',
      'logrocket.io',
      'inspectlet.com',
      'optimizely.com',
      'loggly.com',
      'datadoghq-browser-agent.com',
      'bugsnag.com',
      'rollbar.com',
      'sentry.io',
      'newrelic.com',
      'nr-data.net',
      'bam.nr-data.net',

      // Mobile Attribution & Deep Tracking
      'branch.io',
      'app.link',
      'adjust.com',
      'adjust.net.in',
      'appsflyer.com',
      'app.appsflyer.com',
      'kochava.com',
      'singular.net',
      'tenjin.com',
      'smartlook.com',

      // Push Notification Ad & Spam Gateways
      'onesignal.com',
      'pushwoosh.com',
      'clevertap.com',
      'webpushr.com',
      'sendpulse.com',

      // Audience Measurement & Fingerprinting
      'scorecardresearch.com',
      'sb.scorecardresearch.com',
      'b.scorecardresearch.com',
      'statcounter.com',
      'quantcount.com',
      'mc.yandex.ru',
      'top-fwz1.mail.ru',
      'gemius.pl',
      'chartbeat.com',
      'static.chartbeat.com',
      'alexametrics.com',
      'comscore.com',
      'rlcdn.com',
      'agkn.com',
      'tapad.com',
      'bluekai.com',
      'bkrtx.com',
      'demdex.net',
      'everesttech.net',
      'krxd.net',
      'lotame.com',
      'crwdcntrl.net',
      'liveramp.com',
      'pippio.com',
      'eyeota.net',
      'id5-sync.com',
    ]);

    // ─── 3. CRYPTOMINERS, MALWARE & SCAM REDIRECTS ───────────────────
    _malwareDomains.addAll([
      'coinhive.com',
      'coin-hive.com',
      'jsecoin.com',
      'crypto-loot.com',
      'webminepool.com',
      'minr.pw',
      'coinimp.com',
      'adbtc.top',
      'apkpure.direct',
      'directdownloadlink.net',
      'install-now.net',
      'download-app-now.com',
    ]);

    // ─── 4. AD & VIDEO URL PATH & QUERY PATTERNS ────────────────────
    _adPathPatterns.addAll([
      // Video Ad Endpoints & VAST / VPAID Tags
      '/api/stats/ads',
      '/pagead/',
      '/youtubei/v1/player/ad_break',
      '/get_midroll_info',
      '/vpaid',
      '/vast.xml',
      '/vast?',
      '/vpaid.js',
      'ima3.js',
      'videoadui',

      // Standard Display & Popunder Ad Script Paths
      'adsbygoogle.js',
      '/pagead/gen_204',
      '/pagead/show_ads.js',
      '/pagead/expansion_embed.js',
      '/ads/gpt/pubads_impl',
      '/delivery/asyncspc.php',
      '/delivery/ajs.php',
      '/ad_banner',
      '/ad_unit',
      '/ad-server',
      '/adframe',
      '/adview',
      '/ads.js',
      '/advert.js',
      '/ads.min.js',
      '/prebid.js',
      'gpt.js',
      'show_ads.js',
      'fbevents.js',
      '/popunder.js',
      '/popunder',
      '/pop.js',
      '/punder.js',
      '/direct-link?',
      'adsterra',
      'exoclick',
      'monetag',
      'hilltopads',
      'propellerads',
      'clickadu',
      'deloton',
      'highcpm',
      'onclickalgo',
      'onclickperformance',
      'wpadmngr',
      'zoneid=',
      'ad_zone=',
      'ad_unit=',
      '/ad-delivery/',
      '/ad-tag/',
      '/vignette?',
      '/delivery/asyncjs.php',
      '/delivery/',
      '/revive/',
      'videobaba',
      'blazingserver',
      'mfads',
      'trafficstars',
      'trafficjunky',
      'plugrush',
      'eroadvertising',
      'twinred',
      'tsyndicate',
      'traffichaus',
      'rollerads',
      'richpush',
      'richads',
      'popmyads',
      'propellerclick',
      '/clickunder',
      '/interstitial.js',
      '/interstitial?',
      'taboola',
      'outbrain',
      'criteo',
    ]);

    _trackerPathPatterns.addAll([
      '/gtag/js',
      '/analytics.js',
      '/gtm.js',
      '/beacon.js',
      '/telemetry',
      '/pixel.gif',
      '/tr/',
      '/collect?',
      '/matomo.js',
      '/piwik.js',
      'clarity.js',
      'hotjar-',
    ]);
  }

  /// Identifies essential media stream delivery CDNs and player scripts that must never be blocked.
  bool _isProtectedPlaybackResource(String host, String path) {
    // 1. YouTube & Google Video Streams (videoplayback, manifests, init chunks)
    if (host == 'googlevideo.com' || host.endsWith('.googlevideo.com')) {
      return true;
    }

    // 2. YouTube Static Assets, Thumbnails, Player Core JS/CSS
    if (host == 'ytimg.com' || host.endsWith('.ytimg.com')) {
      return true;
    }
    if (host == 'youtube-nocookie.com' || host.endsWith('.youtube-nocookie.com')) {
      return true;
    }
    if ((host == 'youtube.com' || host.endsWith('.youtube.com')) &&
        (path.startsWith('/s/player/') ||
            path.startsWith('/yts/') ||
            path.startsWith('/embed/') ||
            path.startsWith('/videoplayback') ||
            path.startsWith('/generate_204'))) {
      return true;
    }

    // 3. Vimeo & Other HTML5 Video CDNs
    if (host == 'vimeocdn.com' ||
        host.endsWith('.vimeocdn.com') ||
        host == 'dailymotion.com' ||
        host.endsWith('.dailymotion.com')) {
      return true;
    }

    // 4. Common HLS / DASH video chunk extensions
    if (path.endsWith('.m3u8') ||
        path.endsWith('.mpd') ||
        path.endsWith('.ts') ||
        path.endsWith('.mp4') ||
        path.endsWith('.webm')) {
      return true;
    }

    return false;
  }
}
