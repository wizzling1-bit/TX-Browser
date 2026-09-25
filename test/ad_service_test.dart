import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_browser/core/theme/theme_data.dart';
import 'package:tx_browser/services/ad_service/ad_service.dart';
import 'package:tx_browser/widgets/ads/tx_native_ad_card.dart';

void main() {
  group('AdConfig & Constants Tests', () {
    test('Has valid production AdMob unit IDs', () {
      expect(AdConfig.appId, isNotEmpty);
      expect(AdConfig.appId, startsWith('ca-app-pub-3435015056397165~'));

      expect(AdConfig.bannerId, isNotEmpty);
      expect(AdConfig.bannerId, startsWith('ca-app-pub-3435015056397165/'));

      expect(AdConfig.interstitialId, isNotEmpty);
      expect(AdConfig.interstitialId, startsWith('ca-app-pub-3435015056397165/'));

      expect(AdConfig.nativeId, isNotEmpty);
      expect(AdConfig.nativeId, startsWith('ca-app-pub-3435015056397165/'));

      expect(AdConfig.appOpenId, isNotEmpty);
      expect(AdConfig.appOpenId, startsWith('ca-app-pub-3435015056397165/'));

      expect(AdConfig.rewardedId, isNotEmpty);
      expect(AdConfig.rewardedId, startsWith('ca-app-pub-3435015056397165/'));
    });

    test('Default config has safe policy settings and placement flags', () {
      const config = AdConfig();
      expect(config.enableAds, isTrue);
      expect(config.enableHomeAds, isTrue);
      expect(config.enableInterstitials, isTrue);
      expect(config.enableAppOpenAds, isTrue);
      expect(config.minimumActionsBetweenInterstitials, equals(3));
      expect(config.cooldownDuration.inSeconds, equals(45));
      expect(config.appOpenCooldownDuration.inSeconds, equals(45));
      expect(config.maxInterstitialsPerSession, equals(6));
      expect(config.maxNativeAdsPerScreen, equals(1));

      // Placement flags
      expect(config.homeNativeAd, isTrue);
      expect(config.homeBanner, isTrue);
      expect(config.tabsNativeAd, isTrue);
      expect(config.historyNativeAd, isTrue);
      expect(config.downloadsNativeAd, isTrue);
      expect(config.bookmarksNativeAd, isTrue);
      expect(config.downloadCompleteAd, isTrue);
      expect(config.searchSuggestionsAd, isTrue);
      expect(config.clearDataAd, isTrue);
      expect(config.privateSessionEndedAd, isTrue);

      // Prohibited placement flags
      expect(config.browserOverlayAds, isFalse);
      expect(config.thirdPartyPageInjection, isFalse);
      expect(config.searchResultInjection, isFalse);
    });
  });

  group('AdFrequencyController Unit Tests', () {
    late AdFrequencyController controller;

    setUp(() {
      controller = AdFrequencyController(
        config: const AdConfig(
          enableAds: true,
          enableInterstitials: true,
          enableAppOpenAds: true,
          minimumActionsBetweenInterstitials: 3,
          cooldownDuration: Duration(minutes: 3),
          maxInterstitialsPerSession: 2,
        ),
      );
    });

    test('Disallows interstitial before action threshold is reached', () {
      expect(controller.canShowInterstitial(), isFalse);

      controller.recordAction(); // 1
      controller.recordAction(); // 2
      expect(controller.canShowInterstitial(), isFalse);

      controller.recordAction(); // 3
      expect(controller.canShowInterstitial(), isTrue);
    });

    test('Enforces cooldown interval after interstitial is shown', () {
      // Reach threshold
      for (var i = 0; i < 3; i++) {
        controller.recordAction();
      }
      expect(controller.canShowInterstitial(), isTrue);

      // Record ad shown
      controller.recordInterstitialShown();
      expect(controller.actionCount, equals(0));
      expect(controller.sessionInterstitialCount, equals(1));
      expect(controller.canShowInterstitial(), isFalse);

      // Even if threshold is reached immediately, cooldown blocks it
      for (var i = 0; i < 3; i++) {
        controller.recordAction();
      }
      expect(controller.canShowInterstitial(), isFalse);
    });

    test('Enforces session cap on interstitials', () {
      final shortCooldownController = AdFrequencyController(
        config: const AdConfig(
          enableAds: true,
          enableInterstitials: true,
          minimumActionsBetweenInterstitials: 1,
          cooldownDuration: Duration.zero,
          maxInterstitialsPerSession: 2,
        ),
      );

      // 1st ad
      shortCooldownController.recordAction();
      expect(shortCooldownController.canShowInterstitial(), isTrue);
      shortCooldownController.recordInterstitialShown();
      expect(shortCooldownController.sessionInterstitialCount, equals(1));

      // 2nd ad
      shortCooldownController.recordAction();
      expect(shortCooldownController.canShowInterstitial(), isTrue);
      shortCooldownController.recordInterstitialShown();
      expect(shortCooldownController.sessionInterstitialCount, equals(2));

      // 3rd ad blocked by session cap
      shortCooldownController.recordAction();
      expect(shortCooldownController.canShowInterstitial(), isFalse);

      // Resetting session restores eligibility
      shortCooldownController.resetSession();
      expect(shortCooldownController.sessionInterstitialCount, equals(0));
      expect(shortCooldownController.canShowInterstitial(), isTrue);
    });

    test('Per-screen native ad tracking respects max limits', () {
      expect(controller.canShowNativeAd('home'), isTrue);
      controller.recordNativeImpression('home');
      // maxNativeAdsPerScreen = 1 by default
      expect(controller.canShowNativeAd('home'), isFalse);
      // Other screens are unaffected
      expect(controller.canShowNativeAd('history'), isTrue);
    });

    test('Placement enable checks match config', () {
      expect(controller.isPlacementEnabled('homeNative'), isTrue);
      expect(controller.isPlacementEnabled('homeBanner'), isTrue);
      expect(controller.isPlacementEnabled('tabsNative'), isTrue);
      expect(controller.isPlacementEnabled('historyNative'), isTrue);
      expect(controller.isPlacementEnabled('downloadsNative'), isTrue);
      expect(controller.isPlacementEnabled('bookmarksNative'), isTrue);
      expect(controller.isPlacementEnabled('unknownPlacement'), isFalse);
    });

    test('App Open ad allows first launch and throttles subsequent resumes', () {
      expect(controller.canShowAppOpen(), isTrue);

      controller.recordAppOpenShown();
      // Second immediate resume is blocked by cooldown
      expect(controller.canShowAppOpen(), isFalse);
    });

    test('Disabling ads in config immediately halts all ad eligibility', () {
      final disabledController = AdFrequencyController(
        config: const AdConfig(enableAds: false),
      );

      for (var i = 0; i < 10; i++) {
        disabledController.recordAction();
      }
      expect(disabledController.canShowInterstitial(), isFalse);
      expect(disabledController.canShowAppOpen(), isFalse);
      expect(disabledController.canShowNativeAd('home'), isFalse);
    });
  });

  group('TxNativeAdCard Widget Tests', () {
    testWidgets('Renders properly within TxTheme', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: TxTheme.light(),
            home: const Scaffold(
              body: TxNativeAdCard(),
            ),
          ),
        ),
      );
      // Pump frame
      await tester.pump();

      // AD label and Sponsored text should be present during loading
      expect(find.text('AD'), findsOneWidget);
      expect(find.text('Sponsored'), findsOneWidget);
    });
  });
}
