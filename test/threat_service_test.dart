import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/services/threat_service/threat_service.dart';
import 'package:tx_browser/services/ad_service/ad_config.dart';

void main() {
  group('ThreatService Tests', () {
    late ThreatService threatService;

    setUp(() {
      threatService = ThreatService();
      // Initialize with offline default database
      threatService.initialize();
    });

    test('Initializes with default threats', () {
      final result = threatService.checkUrl('https://metamask-restore-wallet.xyz');
      expect(result.isThreat, isTrue);
      expect(result.threat, isNotNull);
      expect(result.threat!.category, equals(ThreatCategory.cryptoDrainer));
      expect(result.threat!.severity, equals('CRITICAL'));
    });

    test('Detects malicious subdomains via suffix match', () {
      final result = threatService.checkUrl('https://auth.login.binance-verify-auth.net/secure');
      expect(result.isThreat, isTrue);
      expect(result.threat!.category, equals(ThreatCategory.phishing));
    });

    test('Allows safe domains without false positives', () {
      final result1 = threatService.checkUrl('https://google.com');
      final result2 = threatService.checkUrl('https://en.wikipedia.org/wiki/Flutter');
      final result3 = threatService.checkUrl('https://github.com/flutter/flutter');

      expect(result1.isThreat, isFalse);
      expect(result2.isThreat, isFalse);
      expect(result3.isThreat, isFalse);
    });

    test('Bypass mechanism permits user override for current session', () {
      const malicious = 'https://claim-iphone16-reward.top';
      expect(threatService.checkUrl(malicious).isThreat, isTrue);

      threatService.bypassDomainWarning(malicious);
      expect(threatService.checkUrl(malicious).isThreat, isFalse);

      threatService.clearBypasses();
      expect(threatService.checkUrl(malicious).isThreat, isTrue);
    });
  });

  group('AdConfig Remote Sync & KillSwitch Tests', () {
    test('Default config has ads enabled and killSwitch false', () {
      const config = AdConfig();
      expect(config.enableAds, isTrue);
      expect(config.killSwitch, isFalse);
      expect(config.areAdsGloballyEnabled, isTrue);
    });

    test('killSwitch disables all ads even if individual formats enabled', () {
      const config = AdConfig(
        killSwitch: true,
        enableAds: true,
        enableInterstitials: true,
        enableAppOpenAds: true,
      );
      expect(config.areAdsGloballyEnabled, isFalse);
    });

    test('AdConfig fromJson parses backend remote configuration payload', () {
      final json = {
        'killSwitch': true,
        'enableAds': false,
        'bannerEnabled': false,
        'interstitialEnabled': false,
        'appOpenEnabled': false,
        'rewardedEnabled': true,
        'interstitialPageThreshold': 5,
        'interstitialIntervalMinutes': 10,
        'rewardedPerkMinutes': 15,
        'bannerAdUnitId': 'custom-banner-id',
        'interstitialAdUnitId': 'custom-interstitial-id',
        'rewardedAdUnitId': 'custom-rewarded-id',
        'appOpenAdUnitId': 'custom-appopen-id',
        'nativeAdUnitId': 'custom-native-id',
      };

      final config = AdConfig.fromJson(json);
      expect(config.killSwitch, isTrue);
      expect(config.enableAds, isFalse);
      expect(config.areAdsGloballyEnabled, isFalse);
      expect(config.minimumActionsBetweenInterstitials, equals(5));
      expect(config.cooldownDuration.inMinutes, equals(10));
      expect(config.rewardedPerkMinutes, equals(15));
      expect(config.bannerAdUnitId, equals('custom-banner-id'));
      expect(config.interstitialAdUnitId, equals('custom-interstitial-id'));
    });
  });
}
