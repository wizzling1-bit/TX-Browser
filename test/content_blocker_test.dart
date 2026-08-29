import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/services/content_blocker/content_blocker_service.dart';
import 'package:tx_browser/state/shield_provider.dart';

void main() {
  group('Tx Shield Content Blocker & RuleMatcher Engine Tests', () {
    late ContentBlockerService blocker;

    setUp(() {
      blocker = ContentBlockerService();
    });

    test('Blocks known advertising root domains', () {
      final decision1 = blocker.evaluateRequest(
        requestUrl: 'https://doubleclick.net/ad.js',
        pageHost: 'news.example.com',
      );
      expect(decision1.isBlocked, isTrue);
      expect(decision1.reason, equals(BlockReason.ad));

      final decision2 = blocker.evaluateRequest(
        requestUrl: 'https://criteo.com/delivery/r/show.php',
        pageHost: 'shop.example.com',
      );
      expect(decision2.isBlocked, isTrue);
      expect(decision2.reason, equals(BlockReason.ad));

      final decision3 = blocker.evaluateRequest(
        requestUrl: 'https://amazon-adsystem.com/aax2/apstag.js',
        pageHost: 'blog.example.com',
      );
      expect(decision3.isBlocked, isTrue);
      expect(decision3.reason, equals(BlockReason.ad));

      // Adult & Popunder networks
      final decision4 = blocker.evaluateRequest(
        requestUrl: 'https://syndication.exoclick.com/splash.php?cat=1',
        pageHost: 'bhojpurisex.site',
      );
      expect(decision4.isBlocked, isTrue);
      expect(decision4.reason, equals(BlockReason.ad));

      final decision5 = blocker.evaluateRequest(
        requestUrl: 'https://adsterra.com/tag.js',
        pageHost: 'bhojpurisex.site',
      );
      expect(decision5.isBlocked, isTrue);
      expect(decision5.reason, equals(BlockReason.ad));

      final decision6 = blocker.evaluateRequest(
        requestUrl: 'https://popads.net/serve/pop.js',
        pageHost: 'example.com',
      );
      expect(decision6.isBlocked, isTrue);
      expect(decision6.reason, equals(BlockReason.ad));
    });

    test('Blocks deep subdomains via suffix matching', () {
      final decision1 = blocker.evaluateRequest(
        requestUrl: 'https://securepubads.g.doubleclick.net/gampad/ads',
        pageHost: 'example.com',
      );
      expect(decision1.isBlocked, isTrue);
      expect(decision1.reason, equals(BlockReason.ad));

      final decision2 = blocker.evaluateRequest(
        requestUrl: 'https://pagead2.googlesyndication.com/pagead/show_ads.js',
        pageHost: 'example.com',
      );
      expect(decision2.isBlocked, isTrue);
      expect(decision2.reason, equals(BlockReason.ad));

      final decision3 = blocker.evaluateRequest(
        requestUrl: 'https://aax-us-east.amazon-adsystem.com/x/getad',
        pageHost: 'example.com',
      );
      expect(decision3.isBlocked, isTrue);
      expect(decision3.reason, equals(BlockReason.ad));

      final decision4 = blocker.evaluateRequest(
        requestUrl: 'https://ads.exoclick.com/iframe.php',
        pageHost: 'example.com',
      );
      expect(decision4.isBlocked, isTrue);
      expect(decision4.reason, equals(BlockReason.ad));
    });

    test('Evaluates and blocks popups, popunders and new window spam', () {
      // Popunder / Ad network destination
      final popup1 = blocker.evaluatePopupOrNavigation(
        destinationUrl: 'https://popads.net/click/redirect?id=123',
        pageHost: 'bhojpurisex.site',
      );
      expect(popup1.isBlocked, isTrue);
      expect(popup1.reason, equals(BlockReason.popup));

      final popup2 = blocker.evaluatePopupOrNavigation(
        destinationUrl: 'https://onclickads.net/afu.php?zoneid=999',
        pageHost: 'streamingsite.com',
      );
      expect(popup2.isBlocked, isTrue);
      expect(popup2.reason, equals(BlockReason.popup));

      // Legitimate user navigation
      final legitNav = blocker.evaluatePopupOrNavigation(
        destinationUrl: 'https://github.com/flutter/flutter',
        pageHost: 'github.com',
      );
      expect(legitNav.isBlocked, isFalse);
    });

    test('Evaluates and blocks forced redirect chains', () {
      final redirect1 = blocker.evaluatePopupOrNavigation(
        destinationUrl: 'https://zeroredirect1.com/land/offer',
        pageHost: 'example.com',
      );
      expect(redirect1.isBlocked, isTrue);

      final redirect2 = blocker.evaluatePopupOrNavigation(
        destinationUrl: 'https://api.segment.io/v1/p',
        pageHost: 'example.com',
      );
      expect(redirect2.isBlocked, isTrue);
      expect(redirect2.reason, equals(BlockReason.redirect));
    });

    test('Strictly protects essential media playback and prevents black-screens', () {
      // 1. YouTube Video stream chunks on googlevideo.com must NEVER be blocked
      final decision1 = blocker.evaluateRequest(
        requestUrl: 'https://rr2---sn-4g5ednss.googlevideo.com/videoplayback?expire=123&sparams=expire,id,itag,source&id=xyz',
        pageHost: 'm.youtube.com',
      );
      expect(decision1.isBlocked, isFalse);

      // 2. YouTube Player core assets, thumbnails & scripts must NEVER be blocked
      final decision2 = blocker.evaluateRequest(
        requestUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        pageHost: 'm.youtube.com',
      );
      expect(decision2.isBlocked, isFalse);

      final decision3 = blocker.evaluateRequest(
        requestUrl: 'https://www.youtube.com/s/player/9b23fa8c/player_ias.vflset/en_US/base.js',
        pageHost: 'www.youtube.com',
      );
      expect(decision3.isBlocked, isFalse);

      // 3. Vimeo & HTML5 Video CDNs
      final decision4 = blocker.evaluateRequest(
        requestUrl: 'https://f.vimeocdn.com/p/4.33.2/js/player.js',
        pageHost: 'vimeo.com',
      );
      expect(decision4.isBlocked, isFalse);

      // 4. HLS / DASH stream chunks (.m3u8, .mp4, .ts)
      final decision5 = blocker.evaluateRequest(
        requestUrl: 'https://cdn.videosite.org/streams/hls/master.m3u8',
        pageHost: 'videosite.org',
      );
      expect(decision5.isBlocked, isFalse);

      final decision6 = blocker.evaluateRequest(
        requestUrl: 'https://cdn.videosite.org/streams/hls/segment_001.ts',
        pageHost: 'videosite.org',
      );
      expect(decision6.isBlocked, isFalse);
    });

    test('Blocks telemetry and tracking endpoints', () {
      final decision1 = blocker.evaluateRequest(
        requestUrl: 'https://google-analytics.com/analytics.js',
        pageHost: 'example.com',
      );
      expect(decision1.isBlocked, isTrue);
      expect(decision1.reason, equals(BlockReason.tracker));

      final decision2 = blocker.evaluateRequest(
        requestUrl: 'https://clarity.ms/tag/clarity.js',
        pageHost: 'example.com',
      );
      expect(decision2.isBlocked, isTrue);
      expect(decision2.reason, equals(BlockReason.tracker));

      final decision3 = blocker.evaluateRequest(
        requestUrl: 'https://api.segment.io/v1/p',
        pageHost: 'example.com',
      );
      expect(decision3.isBlocked, isTrue);
      expect(decision3.reason, equals(BlockReason.tracker));
    });

    test('Blocks ad script path patterns even on generic or custom hosts', () {
      final decision = blocker.evaluateRequest(
        requestUrl: 'https://customcdn.example.org/pagead/js/adsbygoogle.js',
        pageHost: 'example.com',
      );
      expect(decision.isBlocked, isTrue);
      expect(decision.reason, equals(BlockReason.ad));
    });

    test('Allows normal legitimate content and resources', () {
      final decision1 = blocker.evaluateRequest(
        requestUrl: 'https://flutter.dev/main.dart.js',
        pageHost: 'flutter.dev',
      );
      expect(decision1.isBlocked, isFalse);

      final decision2 = blocker.evaluateRequest(
        requestUrl: 'https://upload.wikimedia.org/wikipedia/commons/logo.png',
        pageHost: 'wikipedia.org',
      );
      expect(decision2.isBlocked, isFalse);

      final decision3 = blocker.evaluateRequest(
        requestUrl: 'https://fonts.googleapis.com/css2?family=Inter',
        pageHost: 'example.com',
      );
      expect(decision3.isBlocked, isFalse);
    });

    test('Respects per-site allowlist exceptions', () {
      blocker.updateAllowlist({'trusted-news.com'});

      // Ad on normal site is blocked
      final blocked = blocker.evaluateRequest(
        requestUrl: 'https://doubleclick.net/ad.js',
        pageHost: 'normal-site.com',
      );
      expect(blocked.isBlocked, isTrue);

      // Same ad on allowlisted site is permitted
      final allowed = blocker.evaluateRequest(
        requestUrl: 'https://doubleclick.net/ad.js',
        pageHost: 'trusted-news.com',
      );
      expect(allowed.isBlocked, isFalse);
    });

    test('Respects custom user blocklist', () {
      blocker.updateCustomBlocklist({'annoying-popup.net'});

      final decision = blocker.evaluateRequest(
        requestUrl: 'https://sub.annoying-popup.net/script.js',
        pageHost: 'example.com',
      );
      expect(decision.isBlocked, isTrue);
      expect(decision.reason, equals(BlockReason.customRule));
    });

    test('Handles non-network schemes and malformed URLs gracefully (fail-open)', () {
      expect(
        blocker.evaluateRequest(requestUrl: 'javascript:void(0)', pageHost: 'example.com').isBlocked,
        isFalse,
      );
      expect(
        blocker.evaluateRequest(requestUrl: 'blob:https://example.com/uuid', pageHost: 'example.com').isBlocked,
        isFalse,
      );
      expect(
        blocker.evaluateRequest(requestUrl: 'data:image/png;base64,...', pageHost: 'example.com').isBlocked,
        isFalse,
      );
      expect(
        blocker.evaluateRequest(requestUrl: '', pageHost: null).isBlocked,
        isFalse,
      );
      expect(
        blocker.evaluateRequest(requestUrl: 'invalid://not-a-url', pageHost: 'example.com').isBlocked,
        isFalse,
      );
    });

    test('Generates safe native ContentBlockers and Cosmetic UserScript without player interference', () {
      final nativeBlockers = blocker.generateNativeBlockers();
      expect(nativeBlockers, isNotEmpty);
      expect(nativeBlockers.length, greaterThan(30));

      final script = blocker.getCosmeticAndYouTubeUserScript();
      expect(script.source, contains('adsbygoogle'));
      expect(script.source, contains('floating-ad'));
      expect(script.source, contains('popunder'));
      expect(script.source, contains('exoclick'));
      expect(script.source, contains('display: none !important'));
      expect(script.source, contains('window.open'));
      // Ensure destructive video duration / playback mutations are NOT in the script
      expect(script.source, isNot(contains('video.currentTime')));
      expect(script.source, isNot(contains('ytInitialPlayerResponse.adPlacements')));
    });

    test('ShieldSiteStats increments individual metrics accurately', () {
      var stats = const ShieldSiteStats();
      expect(stats.adsBlocked, equals(0));
      expect(stats.trackersBlocked, equals(0));
      expect(stats.popupsBlocked, equals(0));
      expect(stats.redirectsBlocked, equals(0));
      expect(stats.requestsBlocked, equals(0));

      stats = stats.increment(BlockReason.ad);
      expect(stats.adsBlocked, equals(1));
      expect(stats.requestsBlocked, equals(1));

      stats = stats.increment(BlockReason.tracker);
      expect(stats.trackersBlocked, equals(1));
      expect(stats.requestsBlocked, equals(2));

      stats = stats.increment(BlockReason.popup);
      expect(stats.popupsBlocked, equals(1));
      expect(stats.requestsBlocked, equals(3));

      stats = stats.increment(BlockReason.redirect);
      expect(stats.redirectsBlocked, equals(1));
      expect(stats.requestsBlocked, equals(4));
    });

    test('Performance micro-benchmark: 10,000 evaluations execute with decision cache in under 50ms', () {
      final stopwatch = Stopwatch()..start();

      const testUrls = [
        'https://pagead2.googlesyndication.com/pagead/show_ads.js',
        'https://flutter.dev/main.dart.js',
        'https://clarity.ms/tag/clarity.js',
        'https://rr2---sn-4g5ednss.googlevideo.com/videoplayback?id=123',
        'https://syndication.exoclick.com/splash.php',
        'https://popads.net/serve/pop.js',
        'https://wikipedia.org/logo.png',
        'https://securepubads.g.doubleclick.net/gampad/ads',
        'https://github.com/index.html',
        'https://amazon-adsystem.com/aax2/apstag.js',
        'https://fonts.googleapis.com/css2',
        'https://criteo.com/delivery/r/show.php',
        'https://api.segment.io/v1/p',
      ];

      for (var i = 0; i < 10000; i++) {
        final url = testUrls[i % testUrls.length];
        blocker.evaluateRequest(requestUrl: url, pageHost: 'example.com');
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });
}
