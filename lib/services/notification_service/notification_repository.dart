import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'notification_models.dart';

/// Repository responsible for synchronizing device registration, token refreshes,
/// heartbeats, and notification open events.
///
/// Designed to work completely seamlessly in all operational topologies:
/// 1. Direct Cloud Sync: Connects directly to Supabase Cloud PostgREST API without needing any local backend.
/// 2. Dedicated Backend Sync: Connects to custom Fastify push backend if configured/deployed.
/// 3. Zero User Login: Entirely anonymous, identity is a persistent local device UUID.
class NotificationRepository {
  NotificationRepository({
    http.Client? client,
    String? baseUrl,
    String? supabaseUrl,
    String? supabaseAnonKey,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? defaultBaseUrl,
        supabaseUrl = supabaseUrl ?? defaultSupabaseUrl,
        supabaseAnonKey = supabaseAnonKey ?? defaultSupabaseAnonKey;

  final http.Client _client;

  /// Default production API base URL. Can be overridden in settings or debug mode.
  static const String defaultBaseUrl = 'https://notify.txbrowser.com';

  /// Supabase Cloud Project URL for direct-to-cloud serverless synchronization.
  static const String defaultSupabaseUrl = 'https://vidrbrkyvcajabdyycmq.supabase.co';

  /// Supabase Anon/Public Key for client-side device registration (RLS public access).
  static const String defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpZHJicmt5dmNhamFiZHl5Y21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMjAzNjEsImV4cCI6MjEwNTg5NjM2MX0.0VyAmmu65b5aiduXDbG4eDAAYYXJGky5S5ooHJ9A0sQ';

  final String baseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Headers required for direct Supabase PostgREST cloud operations.
  Map<String, String> get _supabaseHeaders => {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
        'Content-Type': 'application/json',
      };

  /// Registers or updates the device installation with FCM token and hardware metadata.
  /// Attempts the dedicated push backend first, then automatically synchronizes with
  /// Supabase Cloud so that no local backend process is required.
  Future<bool> registerDevice(DeviceRegistrationPayload payload) async {
    // 1. Direct Cloud Sync to Supabase PostgREST (Zero Local Backend required)
    bool cloudSuccess = false;
    try {
      final cloudUri = Uri.parse('$supabaseUrl/rest/v1/device_installations');
      final cloudPayload = {
        'id': payload.installationId,
        'installation_id': payload.installationId,
        'fcm_token': payload.fcmToken,
        'platform': 'android',
        'app_version': payload.appVersion,
        'build_number': payload.buildNumber,
        'android_version': payload.androidVersion,
        'device_model': payload.deviceModel,
        'notification_permission': payload.notificationPermission,
        'is_active': true,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _client
          .post(
            cloudUri,
            headers: {
              ..._supabaseHeaders,
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode(cloudPayload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        cloudSuccess = true;
        debugPrint('[NotificationRepo] Device registered directly to Supabase Cloud: ${payload.installationId}');
      } else {
        debugPrint('[NotificationRepo] Supabase registration response (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('[NotificationRepo] Cloud sync exception (safe non-blocking): $e');
    }

    // 2. Also register with custom push backend if available (non-blocking)
    if (baseUrl.isNotEmpty && !baseUrl.contains('notify.txbrowser.com')) {
      try {
        final uri = Uri.parse('$baseUrl/api/v1/devices/register');
        await _client
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload.toJson()),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    return cloudSuccess;
  }

  /// Sends a periodic lightweight heartbeat to keep the installation active.
  Future<bool> sendHeartbeat({
    required String installationId,
    required String appVersion,
    required String notificationPermission,
  }) async {
    // 1. Try dedicated backend only if custom URL is configured
    if (baseUrl.isNotEmpty && !baseUrl.contains('notify.txbrowser.com')) {
      try {
        final uri = Uri.parse('$baseUrl/api/v1/devices/heartbeat');
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
            .timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (_) {
        // Fallback to Supabase direct
      }
    }

    // 2. Direct Cloud Sync Heartbeat to Supabase
    try {
      final cloudUri = Uri.parse(
          '$supabaseUrl/rest/v1/device_installations?installation_id=eq.$installationId');
      final response = await _client
          .patch(
            cloudUri,
            headers: _supabaseHeaders,
            body: jsonEncode({
              'app_version': appVersion,
              'notification_permission': notificationPermission,
              'last_seen_at': DateTime.now().toUtc().toIso8601String(),
              'is_active': true,
            }),
          )
          .timeout(const Duration(seconds: 6));

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
    // 1. Try dedicated backend only if custom URL is configured
    if (baseUrl.isNotEmpty && !baseUrl.contains('notify.txbrowser.com')) {
      try {
        final uri = Uri.parse('$baseUrl/api/v1/devices/notification-open');
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
            .timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (_) {
        // Fallback
      }
    }

    // 2. Direct Cloud Delivery Update
    try {
      final cloudUri = Uri.parse(
          '$supabaseUrl/rest/v1/notification_deliveries?notification_id=eq.$notificationId&device_id=eq.$installationId');
      final response = await _client
          .patch(
            cloudUri,
            headers: _supabaseHeaders,
            body: jsonEncode({
              'status': 'OPENED',
              'opened_at': DateTime.now().toUtc().toIso8601String(),
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
