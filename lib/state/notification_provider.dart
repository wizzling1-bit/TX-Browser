import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../services/notification_service/notification_models.dart';
import '../services/notification_service/notification_service.dart';
import 'database_provider.dart';

/// Keys used to persist notification preferences in the Drift settings table.
class NotificationSettingsKeys {
  NotificationSettingsKeys._();

  static const String installationId = 'notification_installation_id';
  static const String fcmToken = 'notification_fcm_token';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String updatesEnabled = 'topic_updates_enabled';
  static const String securityEnabled = 'topic_security_enabled';
  static const String promotionsEnabled = 'topic_promotions_enabled';
  static const String onboardingPromptShown = 'notification_onboarding_shown';
}

/// Immutable state holding user push notification preferences and permission status.
@immutable
class NotificationSettingsState {
  const NotificationSettingsState({
    this.notificationsEnabled = true,
    this.updatesEnabled = true,
    this.securityEnabled = true,
    this.promotionsEnabled = true,
    this.permissionStatus = 'unknown',
    this.onboardingPromptShown = false,
    this.installationId,
    this.fcmToken,
  });

  final bool notificationsEnabled;
  final bool updatesEnabled;
  final bool securityEnabled;
  final bool promotionsEnabled;
  final String permissionStatus; // 'granted' | 'denied' | 'unknown'
  final bool onboardingPromptShown;
  final String? installationId;
  final String? fcmToken;

  NotificationSettingsState copyWith({
    bool? notificationsEnabled,
    bool? updatesEnabled,
    bool? securityEnabled,
    bool? promotionsEnabled,
    String? permissionStatus,
    bool? onboardingPromptShown,
    String? installationId,
    String? fcmToken,
  }) {
    return NotificationSettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      updatesEnabled: updatesEnabled ?? this.updatesEnabled,
      securityEnabled: securityEnabled ?? this.securityEnabled,
      promotionsEnabled: promotionsEnabled ?? this.promotionsEnabled,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      onboardingPromptShown:
          onboardingPromptShown ?? this.onboardingPromptShown,
      installationId: installationId ?? this.installationId,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}

/// Provider for the singleton NotificationService instance.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Riverpod notifier managing push notification settings.
class NotificationSettingsNotifier
    extends Notifier<NotificationSettingsState> {
  @override
  NotificationSettingsState build() {
    return const NotificationSettingsState();
  }

  AppDatabase get _db => ref.read(databaseProvider);
  NotificationService get _service => ref.read(notificationServiceProvider);

  /// Loads notification preferences from local Drift storage.
  Future<void> loadSettings() async {
    final enabledStr =
        await _db.getSetting(NotificationSettingsKeys.notificationsEnabled);
    final updatesStr =
        await _db.getSetting(NotificationSettingsKeys.updatesEnabled);
    final securityStr =
        await _db.getSetting(NotificationSettingsKeys.securityEnabled);
    final promotionsStr =
        await _db.getSetting(NotificationSettingsKeys.promotionsEnabled);
    final onboardingStr =
        await _db.getSetting(NotificationSettingsKeys.onboardingPromptShown);
    final instId =
        await _db.getSetting(NotificationSettingsKeys.installationId);
    final token = await _db.getSetting(NotificationSettingsKeys.fcmToken);

    state = NotificationSettingsState(
      notificationsEnabled: enabledStr == null || enabledStr == 'true',
      updatesEnabled: updatesStr == null || updatesStr == 'true',
      securityEnabled: securityStr == null || securityStr == 'true',
      promotionsEnabled: promotionsStr == null || promotionsStr == 'true',
      onboardingPromptShown: onboardingStr == 'true',
      installationId: instId,
      fcmToken: token,
    );
  }

  /// Toggles master notification switch and synchronizes topic subscriptions.
  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _db.setSetting(
      NotificationSettingsKeys.notificationsEnabled,
      enabled ? 'true' : 'false',
    );

    if (enabled) {
      // Re-subscribe to approved topics that are active
      await _service.subscribeToTopic(ApprovedTopics.allUsers);
      if (state.updatesEnabled) {
        await _service.subscribeToTopic(ApprovedTopics.updates);
      }
      if (state.securityEnabled) {
        await _service.subscribeToTopic(ApprovedTopics.security);
      }
      if (state.promotionsEnabled) {
        await _service.subscribeToTopic(ApprovedTopics.promotions);
      }
    } else {
      // Unsubscribe from all topics
      for (final topic in ApprovedTopics.all) {
        await _service.unsubscribeFromTopic(topic);
      }
    }
  }

  /// Toggles individual topic subscriptions (Updates, Security, Promotions).
  Future<void> setTopicEnabled(String topic, bool enabled) async {
    switch (topic) {
      case ApprovedTopics.updates:
        state = state.copyWith(updatesEnabled: enabled);
        await _db.setSetting(
          NotificationSettingsKeys.updatesEnabled,
          enabled ? 'true' : 'false',
        );
        break;

      case ApprovedTopics.security:
        state = state.copyWith(securityEnabled: enabled);
        await _db.setSetting(
          NotificationSettingsKeys.securityEnabled,
          enabled ? 'true' : 'false',
        );
        break;

      case ApprovedTopics.promotions:
        state = state.copyWith(promotionsEnabled: enabled);
        await _db.setSetting(
          NotificationSettingsKeys.promotionsEnabled,
          enabled ? 'true' : 'false',
        );
        break;
    }

    if (state.notificationsEnabled) {
      if (enabled) {
        await _service.subscribeToTopic(topic);
      } else {
        await _service.unsubscribeFromTopic(topic);
      }
    }
  }

  /// Requests Android 13+ runtime notification permission and updates permission status.
  Future<void> requestPermission() async {
    final settings = await _service.requestPermission();
    final isAuthorized =
        settings.authorizationStatus.name == 'authorized';
    state = state.copyWith(
      permissionStatus: isAuthorized ? 'granted' : 'denied',
    );
  }

  /// Records that the contextual soft explanation sheet was shown so it is not repeated.
  Future<void> markOnboardingPromptShown() async {
    state = state.copyWith(onboardingPromptShown: true);
    await _db.setSetting(
      NotificationSettingsKeys.onboardingPromptShown,
      'true',
    );
  }

  /// Persists installation ID and cached token.
  Future<void> setInstallationMetadata({String? id, String? token}) async {
    state = state.copyWith(
      installationId: id ?? state.installationId,
      fcmToken: token ?? state.fcmToken,
    );
    if (id != null) {
      await _db.setSetting(NotificationSettingsKeys.installationId, id);
    }
    if (token != null) {
      await _db.setSetting(NotificationSettingsKeys.fcmToken, token);
    }
  }
}

/// Provider for notification settings state and controller.
final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
  NotificationSettingsNotifier.new,
);
