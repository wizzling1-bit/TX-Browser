import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/services/notification_service/notification_models.dart';
import 'package:tx_browser/state/notification_provider.dart';

void main() {
  group('NotificationSettingsState Unit Tests', () {
    test('initial state has correct default values', () {
      const state = NotificationSettingsState();
      expect(state.notificationsEnabled, isTrue);
      expect(state.updatesEnabled, isTrue);
      expect(state.securityEnabled, isTrue);
      expect(state.promotionsEnabled, isTrue);
      expect(state.permissionStatus, 'unknown');
      expect(state.onboardingPromptShown, isFalse);
      expect(state.installationId, isNull);
      expect(state.fcmToken, isNull);
    });

    test('copyWith updates fields immutably', () {
      const state = NotificationSettingsState();
      final updated = state.copyWith(
        notificationsEnabled: false,
        updatesEnabled: false,
        permissionStatus: 'granted',
        onboardingPromptShown: true,
        installationId: 'test-inst-123',
        fcmToken: 'test-token-abc',
      );

      expect(updated.notificationsEnabled, isFalse);
      expect(updated.updatesEnabled, isFalse);
      expect(updated.securityEnabled, isTrue); // Unchanged
      expect(updated.promotionsEnabled, isTrue); // Unchanged
      expect(updated.permissionStatus, 'granted');
      expect(updated.onboardingPromptShown, isTrue);
      expect(updated.installationId, 'test-inst-123');
      expect(updated.fcmToken, 'test-token-abc');
    });

    test('ApprovedTopics allowlist verification', () {
      expect(ApprovedTopics.isApproved('tx_all'), isTrue);
      expect(ApprovedTopics.isApproved('tx_updates'), isTrue);
      expect(ApprovedTopics.isApproved('tx_security'), isTrue);
      expect(ApprovedTopics.isApproved('tx_promotions'), isTrue);
      expect(ApprovedTopics.isApproved('tx_announcements'), isTrue);

      expect(ApprovedTopics.isApproved('malicious_topic'), isFalse);
      expect(ApprovedTopics.isApproved(''), isFalse);
    });
  });
}
