import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'notification_models.dart';

/// Repository responsible for synchronizing device registration, token refreshes,
/// heartbeats, and notification open events with the TX Browser push notification backend.
class NotificationRepository {
  NotificationRepository({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? defaultBaseUrl;

  final http.Client _client;

  /// Default production API base URL. Can be overridden in settings or debug mode.
  static const String defaultBaseUrl = 'https://notify.txbrowser.com';

  final String baseUrl;

  /// Registers or updates the device installation with FCM token and hardware metadata.
  Future<bool> registerDevice(DeviceRegistrationPayload payload) async {
    final uri = Uri.parse('$baseUrl/api/v1/devices/register');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload.toJson()),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[NotificationRepo] Device registered successfully: ${payload.installationId}');
        return true;
      } else {
        debugPrint(
            '[NotificationRepo] Registration error (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[NotificationRepo] Device registration network exception (safe fallback): $e');
      return false;
    }
  }

  /// Sends a periodic lightweight heartbeat to keep the installation active.
  Future<bool> sendHeartbeat({
    required String installationId,
    required String appVersion,
    required String notificationPermission,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/devices/heartbeat');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'installationId': installationId,
              'appVersion': appVersion,
              'notificationPermission': notificationPermission,
            }),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[NotificationRepo] Heartbeat failed (safe fallback): $e');
      return false;
    }
  }

  /// Records when the user taps on a notification to provide accurate delivery analytics.
  Future<bool> trackNotificationOpen({
    required String notificationId,
    required String installationId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/devices/notification-open');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'notificationId': notificationId,
              'installationId': installationId,
              'openedAt': DateTime.now().toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 6));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[NotificationRepo] Open tracking failed (safe fallback): $e');
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}
