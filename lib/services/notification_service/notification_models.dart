import 'package:flutter/foundation.dart';

/// Destination actions when user taps on a notification.
enum DestinationType {
  home,
  webUrl,
  playStore,
  internalScreen,
  noAction;

  static DestinationType fromString(String? value) {
    if (value == null) return DestinationType.home;
    switch (value.trim().toLowerCase()) {
      case 'web_url':
      case 'weburl':
      case 'url':
        return DestinationType.webUrl;
      case 'play_store':
      case 'playstore':
      case 'store':
        return DestinationType.playStore;
      case 'internal_screen':
      case 'internalscreen':
      case 'screen':
        return DestinationType.internalScreen;
      case 'no_action':
      case 'noaction':
      case 'none':
        return DestinationType.noAction;
      case 'home':
      default:
        return DestinationType.home;
    }
  }

  String toPayloadString() {
    switch (this) {
      case DestinationType.home:
        return 'home';
      case DestinationType.webUrl:
        return 'web_url';
      case DestinationType.playStore:
        return 'play_store';
      case DestinationType.internalScreen:
        return 'internal_screen';
      case DestinationType.noAction:
        return 'no_action';
    }
  }
}

/// Category classification of notification.
enum NotificationType {
  general,
  browserUpdate,
  promotion,
  newFeature,
  security,
  announcement,
  maintenance;

  static NotificationType fromString(String? value) {
    if (value == null) return NotificationType.general;
    switch (value.trim().toLowerCase()) {
      case 'browser_update':
      case 'browserupdate':
      case 'update':
        return NotificationType.browserUpdate;
      case 'promotion':
      case 'promo':
      case 'ad':
        return NotificationType.promotion;
      case 'new_feature':
      case 'newfeature':
      case 'feature':
        return NotificationType.newFeature;
      case 'security':
        return NotificationType.security;
      case 'announcement':
        return NotificationType.announcement;
      case 'maintenance':
        return NotificationType.maintenance;
      case 'general':
      default:
        return NotificationType.general;
    }
  }
}

/// Approved FCM topics that clients are permitted to subscribe to.
class ApprovedTopics {
  ApprovedTopics._();

  static const String allUsers = 'tx_all';
  static const String updates = 'tx_updates';
  static const String security = 'tx_security';
  static const String promotions = 'tx_promotions';
  static const String announcements = 'tx_announcements';

  static const List<String> all = [
    allUsers,
    updates,
    security,
    promotions,
    announcements,
  ];

  static bool isApproved(String topic) => all.contains(topic);
}

/// Type of deep link routing resulting from resolving a notification payload.
enum DeepLinkRouteType {
  internalNavigation,
  webNavigation,
  externalIntent,
  none,
}

/// Result of deep link routing containing target route information.
@immutable
class DeepLinkRoute {
  const DeepLinkRoute({
    required this.routeType,
    this.path,
    this.webUrl,
    this.extra,
  });

  final DeepLinkRouteType routeType;
  final String? path;
  final String? webUrl;
  final Object? extra;

  static const DeepLinkRoute home = DeepLinkRoute(
    routeType: DeepLinkRouteType.internalNavigation,
    path: '/',
  );

  static const DeepLinkRoute none = DeepLinkRoute(
    routeType: DeepLinkRouteType.none,
  );
}

/// Standardized notification payload model extracted from FCM message or local notification.
@immutable
class NotificationPayload {
  const NotificationPayload({
    required this.notificationId,
    required this.title,
    required this.body,
    this.imageUrl,
    this.notificationType = NotificationType.general,
    this.destinationType = DestinationType.home,
    this.destinationValue,
    this.data = const {},
  });

  final String notificationId;
  final String title;
  final String body;
  final String? imageUrl;
  final NotificationType notificationType;
  final DestinationType destinationType;
  final String? destinationValue;
  final Map<String, dynamic> data;

  factory NotificationPayload.fromMap({
    required Map<String, dynamic> data,
    String? notificationTitle,
    String? notificationBody,
  }) {
    final title = notificationTitle ?? (data['title'] as String?) ?? 'TX Browser';
    final body = notificationBody ?? (data['body'] as String?) ?? '';
    final notificationId = (data['notificationId'] as String?) ??
        (data['id'] as String?) ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final imageUrl = (data['imageUrl'] as String?) ?? (data['image'] as String?);
    final notificationType = NotificationType.fromString(data['type'] as String?);
    final destinationType = DestinationType.fromString(data['destinationType'] as String?);
    final destinationValue = data['destinationValue'] as String?;

    return NotificationPayload(
      notificationId: notificationId,
      title: title,
      body: body,
      imageUrl: imageUrl,
      notificationType: notificationType,
      destinationType: destinationType,
      destinationValue: destinationValue,
      data: Map<String, dynamic>.from(data),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'type': notificationType.name,
      'destinationType': destinationType.toPayloadString(),
      'destinationValue': destinationValue,
      ...data,
    };
  }
}

/// Device metadata payload sent to backend /api/v1/devices/register
@immutable
class DeviceRegistrationPayload {
  const DeviceRegistrationPayload({
    required this.installationId,
    required this.fcmToken,
    required this.appVersion,
    required this.buildNumber,
    required this.androidVersion,
    required this.deviceModel,
    this.notificationPermission = 'unknown',
  });

  final String installationId;
  final String fcmToken;
  final String appVersion;
  final int buildNumber;
  final String androidVersion;
  final String deviceModel;
  final String notificationPermission; // 'granted' | 'denied' | 'unknown'

  Map<String, dynamic> toJson() {
    return {
      'installationId': installationId,
      'fcmToken': fcmToken,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'androidVersion': androidVersion,
      'deviceModel': deviceModel,
      'notificationPermission': notificationPermission,
    };
  }
}
