import 'package:flutter/foundation.dart';
import 'notification_models.dart';

/// Validates and resolves notification deep link routing.
/// Enforces strict HTTPS restrictions and blocks arbitrary command/scheme injection.
class NotificationDeepLinkHandler {
  NotificationDeepLinkHandler._();

  /// Resolves the given [NotificationPayload] into an executable [DeepLinkRoute].
  static DeepLinkRoute resolveRoute(NotificationPayload payload) {
    switch (payload.destinationType) {
      case DestinationType.home:
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
  /// Enforces HTTPS only and blocks dangerous schemes.
  static DeepLinkRoute _resolveWebUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      debugPrint('[DeepLink] web_url destination value is empty; falling back to home.');
      return DeepLinkRoute.home;
    }

    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);

    if (uri == null || !uri.hasScheme) {
      debugPrint('[DeepLink] Invalid URI format: $trimmed; falling back to home.');
      return DeepLinkRoute.home;
    }

    final scheme = uri.scheme.toLowerCase();

    // Strictly enforce HTTPS only
    if (scheme != 'https') {
      debugPrint('[DeepLink Security] Blocked non-HTTPS scheme: $scheme ($trimmed)');
      return DeepLinkRoute.home;
    }

    // Verify host is valid
    if (uri.host.isEmpty || uri.host.contains('localhost') || uri.host == '127.0.0.1') {
      debugPrint('[DeepLink Security] Blocked internal/loopback host: ${uri.host}');
      return DeepLinkRoute.home;
    }

    return DeepLinkRoute(
      routeType: DeepLinkRouteType.webNavigation,
      path: '/browser',
      webUrl: trimmed,
      extra: trimmed,
    );
  }

  /// Resolves Play Store link for TX Browser updates.
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
