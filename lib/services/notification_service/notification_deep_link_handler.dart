import 'package:flutter/foundation.dart';
import 'notification_models.dart';
import '../acquisition_service/referrer_parser.dart';

/// Validates and resolves notification deep link routing.
/// Enforces strict HTTPS restrictions and blocks arbitrary command/scheme injection.
class NotificationDeepLinkHandler {
  NotificationDeepLinkHandler._();

  /// Resolves the given [NotificationPayload] into an executable [DeepLinkRoute].
  static DeepLinkRoute resolveRoute(NotificationPayload payload) {
    // 1. If payload has a Play Store campaign URL, handle it
    final destVal = payload.destinationValue?.trim();
    if (destVal != null && destVal.isNotEmpty) {
      if (destVal.contains('play.google.com/store/apps') || destVal.contains('market://')) {
        return _resolvePlayStore(destVal);
      }
    }

    switch (payload.destinationType) {
      case DestinationType.home:
        if (destVal != null && destVal.isNotEmpty && (destVal.startsWith('https://') || destVal.startsWith('http://'))) {
          return _resolveWebUrl(destVal);
        }
        return DeepLinkRoute.home;

      case DestinationType.noAction:
        return DeepLinkRoute.none;

      case DestinationType.webUrl:
        return _resolveWebUrl(payload.destinationValue);

      case DestinationType.playStore:
        return _resolvePlayStore(payload.destinationValue);

      case DestinationType.internalScreen:
        return _resolveInternalScreen(payload.destinationValue);
    }
  }

  /// Strictly validates and normalizes web URLs.
  /// Enforces secure HTTPS and strictly rejects unsafe schemes (javascript, data, file, intent, etc.).
  static DeepLinkRoute _resolveWebUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      debugPrint('[DeepLink] web_url destination value is empty; falling back to home.');
      return DeepLinkRoute.home;
    }

    var trimmed = rawUrl.trim();

    // If wrapped in a Play Store link with referrer, unwrap target URL
    if (trimmed.contains('play.google.com/store/apps') &&
        (trimmed.contains('referrer=') || trimmed.contains('target_url') || trimmed.contains('targetUrl'))) {
      final parsed = ReferrerParser.parse(trimmed);
      final targetUrl = parsed['targetUrl'];
      if (targetUrl != null && targetUrl.isNotEmpty) {
        trimmed = targetUrl;
      }
    }

    // Check if there is an explicit scheme
    if (trimmed.contains(':')) {
      final colonIdx = trimmed.indexOf(':');
      final scheme = trimmed.substring(0, colonIdx).toLowerCase();
      // Strictly require https scheme - all other schemes (http, javascript, data, file, intent, etc.) are rejected
      if (scheme != 'https') {
        debugPrint('[DeepLink Security] Blocked disallowed scheme "$scheme": $trimmed');
        return DeepLinkRoute.home;
      }
    } else {
      // Missing scheme: must not have whitespace, must contain dot, and must not contain invalid chars
      if (trimmed.contains(' ') || !trimmed.contains('.')) {
        debugPrint('[DeepLink Security] Invalid URL string: $trimmed; falling back to home.');
        return DeepLinkRoute.home;
      }
      trimmed = 'https://$trimmed';
    }

    final uri = Uri.tryParse(trimmed);

    if (uri == null || !uri.hasScheme) {
      debugPrint('[DeepLink] Invalid URI format: $trimmed; falling back to home.');
      return DeepLinkRoute.home;
    }

    final scheme = uri.scheme.toLowerCase();

    // Strictly enforce https only
    if (scheme != 'https') {
      debugPrint('[DeepLink Security] Blocked non-https scheme: $scheme ($trimmed)');
      return DeepLinkRoute.home;
    }

    // Verify host is valid
    if (uri.host.isEmpty ||
        !uri.host.contains('.') ||
        uri.host.contains('localhost') ||
        uri.host == '127.0.0.1' ||
        uri.host == '0.0.0.0' ||
        uri.host.contains(' ') ||
        uri.host.startsWith('.') ||
        uri.host.endsWith('.')) {
      debugPrint('[DeepLink Security] Blocked invalid or loopback host: ${uri.host}');
      return DeepLinkRoute.home;
    }

    return DeepLinkRoute(
      routeType: DeepLinkRouteType.webNavigation,
      path: '/browser',
      webUrl: trimmed,
      extra: trimmed,
    );
  }

  /// Resolves Play Store link for TX Browser updates or campaign backlinks.
  static DeepLinkRoute _resolvePlayStore(String? rawUrl) {
    const defaultPlayStoreUrl =
        'https://play.google.com/store/apps/details?id=com.wizzling.tx_browser';

    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return const DeepLinkRoute(
        routeType: DeepLinkRouteType.externalIntent,
        webUrl: defaultPlayStoreUrl,
      );
    }

    final trimmed = rawUrl.trim();

    // If this Play Store link contains a nested campaign referrer / target_url,
    // extract and navigate directly to the target URL inside TX Browser!
    if (trimmed.contains('referrer=') ||
        trimmed.contains('target_url') ||
        trimmed.contains('targetUrl')) {
      final parsed = ReferrerParser.parse(trimmed);
      final targetUrl = parsed['targetUrl'];
      if (targetUrl != null && targetUrl.isNotEmpty) {
        debugPrint('[DeepLink] Extracted campaign target URL from Play Store referrer: $targetUrl');
        return _resolveWebUrl(targetUrl);
      }
    }

    if (trimmed.contains('com.wizzling.tx_browser')) {
      return DeepLinkRoute(
        routeType: DeepLinkRouteType.externalIntent,
        webUrl: trimmed,
      );
    }

    // Fallback to official package
    return const DeepLinkRoute(
      routeType: DeepLinkRouteType.externalIntent,
      webUrl: defaultPlayStoreUrl,
    );
  }

  /// Maps internal screen identifiers to registered GoRouter paths.
  static DeepLinkRoute _resolveInternalScreen(String? screenName) {
    if (screenName == null || screenName.trim().isEmpty) {
      return DeepLinkRoute.home;
    }

    switch (screenName.trim().toLowerCase()) {
      case 'downloads':
      case 'download':
        return const DeepLinkRoute(
          routeType: DeepLinkRouteType.internalNavigation,
          path: '/downloads',
        );

      case 'bookmarks':
      case 'bookmark':
        return const DeepLinkRoute(
          routeType: DeepLinkRouteType.internalNavigation,
          path: '/bookmarks',
        );

      case 'history':
        return const DeepLinkRoute(
          routeType: DeepLinkRouteType.internalNavigation,
          path: '/history',
        );

      case 'tabs':
      case 'tab_manager':
        return const DeepLinkRoute(
          routeType: DeepLinkRouteType.internalNavigation,
          path: '/tabs',
        );

      case 'settings':
      case 'setting':
        return const DeepLinkRoute(
          routeType: DeepLinkRouteType.internalNavigation,
          path: '/settings',
        );

      case 'pinned_sites':
      case 'shortcuts':
        return const DeepLinkRoute(
          routeType: DeepLinkRouteType.internalNavigation,
          path: '/pinned-sites',
        );

      case 'app_lock':
      case 'security':
        return const DeepLinkRoute(
          routeType: DeepLinkRouteType.internalNavigation,
          path: '/app-lock',
        );

      case 'proxy':
        return const DeepLinkRoute(
          routeType: DeepLinkRouteType.internalNavigation,
          path: '/proxy',
        );

      default:
        debugPrint('[DeepLink] Unknown internal screen "$screenName"; routing to home.');
        return DeepLinkRoute.home;
    }
  }
}
