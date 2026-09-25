import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import 'notification_models.dart';
import 'notification_deep_link_handler.dart';
import 'notification_repository.dart';

/// Top-level background message handler required by FirebaseMessaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Already initialized or running in isolated background thread
  }
  debugPrint('[FCM Background] Incoming message: ${message.messageId} | ${message.data}');
}

/// Core Notification Service orchestrating Firebase Cloud Messaging,
/// local Android notification channels, token refreshes, and deep link routing.
class NotificationService {
  NotificationService({
    NotificationRepository? repository,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _repository = repository ?? NotificationRepository(),
        _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin();

  final NotificationRepository _repository;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  final StreamController<DeepLinkRoute> _routeController =
      StreamController<DeepLinkRoute>.broadcast();

  /// Stream of validated deep link routes triggered when the user taps any notification.
  Stream<DeepLinkRoute> get onNotificationRoute => _routeController.stream;

  bool _initialized = false;
  String? _installationId;
  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSub;

  // Channel definitions matching Android target guidelines
  static const String channelGeneral = 'tx_general';
  static const String channelUpdates = 'tx_updates';
  static const String channelSecurity = 'tx_security';
  static const String channelPromotions = 'tx_promotions';

  /// Asynchronously initializes Firebase, Android notification channels,
  /// token lifecycle listeners, and foreground/background handlers.
  Future<void> initialize({
    String? storedInstallationId,
    Future<void> Function(String id)? persistInstallationId,
    Future<void> Function(String token)? persistFcmToken,
  }) async {
    if (_initialized) return;

    try {
      // 1. Initialize Firebase if not already initialized
      try {
        await Firebase.initializeApp();
      } catch (e) {
        debugPrint('[NotificationService] Firebase already initialized or error: $e');
      }

      // 2. Setup stable installation identity
      _installationId = storedInstallationId;
      if (_installationId == null || _installationId!.isEmpty) {
        _installationId = const Uuid().v4();
        if (persistInstallationId != null) {
          await persistInstallationId(_installationId!);
        }
      }

      // 3. Setup Android Notification Channels
      await _setupNotificationChannels();

      // 4. Initialize Local Notifications for foreground alerts
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          _handleLocalNotificationTap(response.payload);
        },
      );

      // 5. Register background messaging handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 6. Listen for incoming foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      // 7. Handle notification tap when app opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessageTap(message);
      });

      // 8. Handle cold-start notification tap when app opened from terminated state
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }

      // 9. Fetch FCM token and register with backend
      await _syncTokenAndRegister(persistFcmToken);

      // 10. Listen for token refresh events
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[FCM] Token refreshed: ${newToken.substring(0, 10)}...');
        _currentToken = newToken;
        if (persistFcmToken != null) {
          await persistFcmToken(newToken);
        }
        await _registerWithBackend(newToken);
      });

      _initialized = true;
      debugPrint('[NotificationService] Initialized successfully. Installation: $_installationId');
    } catch (e, stack) {
      debugPrint('[NotificationService] Initialization error (non-fatal): $e\n$stack');
    }
  }

  /// Sets up Android notification channels with appropriate importance.
  Future<void> _setupNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelGeneral,
          'TX Browser Announcements',
          description: 'General updates and browser announcements',
          importance: Importance.defaultImportance,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelUpdates,
          'Browser Updates',
          description: 'New feature updates and release notices',
          importance: Importance.high,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelSecurity,
          'Security Advisories',
          description: 'Critical security alerts and privacy protection notices',
          importance: Importance.high,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelPromotions,
          'Promotions & Perks',
          description: 'Featured partner promotions and perks',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  /// Obtains the current FCM token and registers the installation with the backend.
  Future<void> _syncTokenAndRegister([Future<void> Function(String token)? onTokenObtained]) async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _currentToken = token;
        if (onTokenObtained != null) {
          await onTokenObtained(token);
        }
        await _registerWithBackend(token);
      }
    } catch (e) {
      debugPrint('[NotificationService] Error fetching FCM token: $e');
    }
  }

  /// Sends device hardware and token registration to the backend server.
  Future<void> _registerWithBackend(String token) async {
    if (_installationId == null) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final settings = await _messaging.getNotificationSettings();

      String permissionStr = 'unknown';
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        permissionStr = 'granted';
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        permissionStr = 'denied';
      }

      final payload = DeviceRegistrationPayload(
        installationId: _installationId!,
        fcmToken: token,
        appVersion: packageInfo.version,
        buildNumber: int.tryParse(packageInfo.buildNumber) ?? 1,
        androidVersion: Platform.operatingSystemVersion,
        deviceModel: 'Android Device',
        notificationPermission: permissionStr,
      );

      await _repository.registerDevice(payload);
    } catch (e) {
      debugPrint('[NotificationService] Backend registration failed (safe): $e');
    }
  }

  /// Intercepts foreground message and shows a controlled local notification
  /// on the appropriate Android channel without disrupting active browsing.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM Foreground] Received: ${message.notification?.title}');

    final payload = NotificationPayload.fromMap(
      data: message.data,
      notificationTitle: message.notification?.title,
      notificationBody: message.notification?.body,
    );

    final channelId = _resolveChannelId(payload.notificationType);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      importance: (payload.notificationType == NotificationType.security ||
              payload.notificationType == NotificationType.browserUpdate)
          ? Importance.high
          : Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);

    final id = payload.notificationId.hashCode.abs();
    await _localNotifications.show(
      id,
      payload.title,
      payload.body,
      details,
      payload: jsonEncode(payload.toMap()),
    );
  }

  /// Resolves the notification channel ID from the notification type.
  String _resolveChannelId(NotificationType type) {
    switch (type) {
      case NotificationType.browserUpdate:
      case NotificationType.newFeature:
        return channelUpdates;
      case NotificationType.security:
        return channelSecurity;
      case NotificationType.promotion:
        return channelPromotions;
      case NotificationType.general:
      case NotificationType.announcement:
      case NotificationType.maintenance:
        return channelGeneral;
    }
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case channelUpdates:
        return 'Browser Updates';
      case channelSecurity:
        return 'Security Advisories';
      case channelPromotions:
        return 'Promotions & Perks';
      default:
        return 'TX Browser Announcements';
    }
  }

  /// Handles notification tap from background or terminated state.
  void _handleMessageTap(RemoteMessage message) {
    final payload = NotificationPayload.fromMap(
      data: message.data,
      notificationTitle: message.notification?.title,
      notificationBody: message.notification?.body,
    );

    _processPayloadRouting(payload);
  }

  /// Handles notification tap from foreground local notification.
  void _handleLocalNotificationTap(String? jsonPayload) {
    if (jsonPayload == null || jsonPayload.isEmpty) return;
    try {
      final map = jsonDecode(jsonPayload) as Map<String, dynamic>;
      final payload = NotificationPayload.fromMap(data: map);
      _processPayloadRouting(payload);
    } catch (e) {
      debugPrint('[NotificationService] Error decoding local notification tap: $e');
    }
  }

  /// Resolves deep link route and notifies listeners while tracking open event.
  void _processPayloadRouting(NotificationPayload payload) {
    final route = NotificationDeepLinkHandler.resolveRoute(payload);
    debugPrint('[NotificationService] Routing notification to: ${route.path ?? route.webUrl}');

    // Track open event with backend asynchronously
    if (_installationId != null && payload.notificationId.isNotEmpty) {
      _repository.trackNotificationOpen(
        notificationId: payload.notificationId,
        installationId: _installationId!,
      );
    }

    _routeController.add(route);
  }

  /// Requests user permission for notifications (Android 13+).
  Future<NotificationSettings> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (_currentToken != null) {
      await _registerWithBackend(_currentToken!);
    }

    return settings;
  }

  /// Subscribes to an approved broadcast topic.
  Future<bool> subscribeToTopic(String topic) async {
    if (!ApprovedTopics.isApproved(topic)) {
      debugPrint('[NotificationService Security] Rejected unapproved topic subscription: $topic');
      return false;
    }
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('[NotificationService] Subscribed to topic: $topic');
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Error subscribing to topic $topic: $e');
      return false;
    }
  }

  /// Unsubscribes from an approved topic.
  Future<bool> unsubscribeFromTopic(String topic) async {
    if (!ApprovedTopics.isApproved(topic)) return false;
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('[NotificationService] Unsubscribed from topic: $topic');
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Error unsubscribing from topic $topic: $e');
      return false;
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _routeController.close();
    _repository.dispose();
  }
}
