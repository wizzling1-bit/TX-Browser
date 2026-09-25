import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/services/notification_service/notification_models.dart';
import 'package:tx_browser/services/notification_service/notification_deep_link_handler.dart';

void main() {
  group('NotificationDeepLinkHandler Unit Tests', () {
    test('resolves home destination correctly', () {
      const payload = NotificationPayload(
        notificationId: 'test-id-1',
        title: 'Welcome',
        body: 'Welcome to TX Browser',
        destinationType: DestinationType.home,
      );

      final route = NotificationDeepLinkHandler.resolveRoute(payload);
      expect(route.routeType, DeepLinkRouteType.internalNavigation);
      expect(route.path, '/');
    });

    test('resolves web_url destination with valid https URL', () {
      const payload = NotificationPayload(
        notificationId: 'test-id-2',
        title: 'Promotion',
        body: 'Check this new website',
        destinationType: DestinationType.webUrl,
        destinationValue: 'https://example.com/promo?id=123',
      );

      final route = NotificationDeepLinkHandler.resolveRoute(payload);
      expect(route.routeType, DeepLinkRouteType.webNavigation);
      expect(route.path, '/browser');
      expect(route.webUrl, 'https://example.com/promo?id=123');
    });

    test('rejects unsafe web_url schemes like javascript, data, file, intent', () {
      final unsafeSchemes = [
        'javascript:alert(1)',
        'data:text/html,<script>alert(1)</script>',
        'file:///android_asset/something',
        'intent://scan/#Intent;scheme=zxing;package=com.google.zxing.client.android;end',
        'http://insecure-site.com',
        'ftp://ftp.example.com',
        'customscheme://execute/action',
        'not a url at all',
      ];

      for (final unsafeUrl in unsafeSchemes) {
        final payload = NotificationPayload(
          notificationId: 'test-id-unsafe',
          title: 'Suspicious payload',
          body: 'Suspicious payload body',
          destinationType: DestinationType.webUrl,
          destinationValue: unsafeUrl,
        );

        final route = NotificationDeepLinkHandler.resolveRoute(payload);
        // Must safely fall back to home or reject rather than navigating to dangerous URL
        expect(route.routeType, DeepLinkRouteType.internalNavigation,
            reason: 'Failed for unsafe URL: $unsafeUrl');
        expect(route.path, '/');
      }
    });

    test('resolves play_store destination with TX Browser package id', () {
      const payload = NotificationPayload(
        notificationId: 'test-id-3',
        title: 'Browser Update',
        body: 'New update available',
        destinationType: DestinationType.playStore,
        destinationValue: 'https://play.google.com/store/apps/details?id=com.wizzling.tx_browser',
      );

      final route = NotificationDeepLinkHandler.resolveRoute(payload);
      expect(route.routeType, DeepLinkRouteType.externalIntent);
      expect(route.webUrl, contains('com.wizzling.tx_browser'));
    });

    test('resolves internal screens (downloads, bookmarks, history, tabs, settings)', () {
      final screenMappings = {
        'downloads': '/downloads',
        'bookmarks': '/bookmarks',
        'history': '/history',
        'tabs': '/tabs',
        'settings': '/settings',
      };

      for (final entry in screenMappings.entries) {
        final payload = NotificationPayload(
          notificationId: 'test-screen-${entry.key}',
          title: 'Screen Test',
          body: 'Opening ${entry.key}',
          destinationType: DestinationType.internalScreen,
          destinationValue: entry.key,
        );

        final route = NotificationDeepLinkHandler.resolveRoute(payload);
        expect(route.routeType, DeepLinkRouteType.internalNavigation);
        expect(route.path, entry.value);
      }
    });

    test('parses NotificationPayload from FCM RemoteMessage data map', () {
      final data = {
        'notificationId': 'uuid-1234',
        'type': 'promotion',
        'destinationType': 'web_url',
        'destinationValue': 'https://txbrowser.com/perks',
        'imageUrl': 'https://txbrowser.com/banner.png',
      };

      final payload = NotificationPayload.fromMap(
        data: data,
        notificationTitle: 'Special Perk',
        notificationBody: 'Get your perk today',
      );

      expect(payload.notificationId, 'uuid-1234');
      expect(payload.title, 'Special Perk');
      expect(payload.body, 'Get your perk today');
      expect(payload.destinationType, DestinationType.webUrl);
      expect(payload.destinationValue, 'https://txbrowser.com/perks');
      expect(payload.imageUrl, 'https://txbrowser.com/banner.png');
    });
  });
}
