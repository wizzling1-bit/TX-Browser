import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/database/app_database.dart';
import 'deferred_navigation_model.dart';
import 'referrer_parser.dart';
import 'referrer_url_validator.dart';

/// Acquisition & Play Install Referrer Service.
///
/// Features:
/// - Asynchronously queries Google Play Install Referrer on first app launch.
/// - Validates & sanitizes target destination URL.
/// - Persists processing state atomically in Drift Settings table.
/// - Provides Android launcher shortcut pinning via ShortcutManagerCompat.
/// - Non-blocking execution with strict safety timeouts.
class AcquisitionService {
  AcquisitionService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('com.wizzling.tx_browser/acquisition') {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  final MethodChannel _channel;
  final _deepLinkController = StreamController<String>.broadcast();

  Stream<String> get onDeepLink => _deepLinkController.stream;

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onDeepLinkReceived') {
      final rawLink = call.arguments as String?;
      final validated = ReferrerUrlValidator.sanitizeAndValidate(rawLink);
      if (validated != null) {
        _deepLinkController.add(validated);
      }
    }
  }

  /// Checks if this is a fresh install and processes the Google Play Install Referrer.
  ///
  /// Guaranteed non-blocking with a strict 2.5-second timeout.
  /// Uses Drift database to ensure the referral is processed only once.
  Future<DeferredNavigationPayload?> checkAndProcessReferrer({
    required AppDatabase db,
  }) async {
    try {
      // 1. Check if already processed in local Drift database
      final processedSetting = await db.getSetting('acquisition_processed');
      if (processedSetting == 'true') {
        if (kDebugMode) {
          debugPrint('[Acquisition] Already processed on a previous launch. Skipping.');
        }
        return null;
      }

      // 2. Query Play Install Referrer asynchronously via native bridge
      Map<dynamic, dynamic>? referrerData;
      try {
        referrerData = await _channel
            .invokeMethod<Map<dynamic, dynamic>>('getInstallReferrer')
            .timeout(const Duration(milliseconds: 2500), onTimeout: () {
          if (kDebugMode) {
            debugPrint('[Acquisition] Referrer query timed out (2500ms). Continuing startup.');
          }
          return null;
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[Acquisition] Native referrer error: $e');
        }
      }

      final rawReferrer = referrerData?['installReferrer'] as String?;
      if (kDebugMode) {
        debugPrint('[Acquisition] Referrer payload received: ${rawReferrer != null ? "PRESENT" : "NULL"}');
      }

      // 3. Parse and validate target URL
      final parsed = ReferrerParser.parse(rawReferrer);
      final targetUrl = parsed['targetUrl'];
      final campaign = parsed['campaign'];

      // 4. Mark as processed in Drift Settings table
      await db.setSetting('acquisition_processed', 'true');

      if (targetUrl != null && targetUrl.isNotEmpty) {
        final now = DateTime.now();
        await db.setSetting('acquisition_target_url', targetUrl);
        if (campaign != null) {
          await db.setSetting('acquisition_campaign', campaign);
        }
        await db.setSetting('acquisition_received_at', now.toIso8601String());

        if (kDebugMode) {
          debugPrint('[Acquisition] Valid deferred destination identified: $targetUrl');
        }

        return DeferredNavigationPayload(
          targetUrl: targetUrl,
          campaign: campaign,
          receivedAt: now,
          processed: true,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Acquisition] Error in checkAndProcessReferrer: $e');
      }
    }

    return null;
  }

  /// Checks if the app was launched with an initial deep link / shortcut intent.
  Future<String?> getInitialDeepLink() async {
    try {
      final rawLink = await _channel.invokeMethod<String>('getInitialDeepLink');
      return ReferrerUrlValidator.sanitizeAndValidate(rawLink);
    } catch (_) {
      return null;
    }
  }

  /// Requests the Android launcher to pin a shortcut for [url] with [title].
  ///
  /// Respects user approval (Android displays the system confirmation dialog).
  Future<bool> requestLauncherPin({
    required String title,
    required String url,
    String? shortcutId,
  }) async {
    final validatedUrl = ReferrerUrlValidator.sanitizeAndValidate(url);
    if (validatedUrl == null) return false;

    try {
      final success = await _channel.invokeMethod<bool>('requestPinShortcut', {
        'url': validatedUrl,
        'title': title,
        'shortcutId': shortcutId ?? 'tx_pin_${Uri.parse(validatedUrl).host}',
      });
      return success ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Acquisition] Pin shortcut error: $e');
      }
      return false;
    }
  }

  /// Checks if launcher pinning is supported by the user's Android launcher.
  Future<bool> isPinShortcutSupported() async {
    try {
      final supported = await _channel.invokeMethod<bool>('isPinShortcutSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _deepLinkController.close();
  }
}
