import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_browser/state/rewarded_perks_provider.dart';

void main() {
  group('RewardedPerksProvider Unit Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state has no active perks', () {
      final state = container.read(rewardedPerksProvider);
      expect(state.isAdFreeActive, isFalse);
      expect(state.isTurboSpeedActive, isFalse);
      expect(state.remainingAdFreeTime, equals(Duration.zero));
      expect(state.remainingTurboSpeedTime, equals(Duration.zero));
    });

    test('activateAdFreePass activates 10-minute ad-free window', () {
      final notifier = container.read(rewardedPerksProvider.notifier);
      notifier.activateAdFreePass(duration: const Duration(minutes: 10));

      final state = container.read(rewardedPerksProvider);
      expect(state.isAdFreeActive, isTrue);
      expect(state.remainingAdFreeTime.inMinutes, greaterThanOrEqualTo(9));
      expect(state.formatDuration(const Duration(minutes: 9, seconds: 45)), equals('9:45'));
    });

    test('activateTurboSpeed activates 2x turbo download speed', () {
      final notifier = container.read(rewardedPerksProvider.notifier);
      notifier.activateTurboSpeed(duration: const Duration(hours: 2));

      final state = container.read(rewardedPerksProvider);
      expect(state.isTurboSpeedActive, isTrue);
      expect(state.remainingTurboSpeedTime.inHours, greaterThanOrEqualTo(1));
    });

    test('formatDuration formats MM:SS correctly', () {
      final state = container.read(rewardedPerksProvider);
      expect(state.formatDuration(const Duration(minutes: 10, seconds: 0)), equals('10:00'));
      expect(state.formatDuration(const Duration(minutes: 2, seconds: 5)), equals('2:05'));
    });
  });
}
