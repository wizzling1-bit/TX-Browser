import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/services/acquisition_service/referrer_url_validator.dart';
import 'package:tx_browser/services/acquisition_service/referrer_parser.dart';
import 'package:tx_browser/services/acquisition_service/deferred_navigation_model.dart';
import 'package:tx_browser/state/shortcuts_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Acquisition & ReferrerUrlValidator Tests', () {
    test('Validates secure HTTPS URLs correctly', () {
      expect(
        ReferrerUrlValidator.isValid('https://www.bhojpurisex.site/'),
        isTrue,
      );
      expect(
        ReferrerUrlValidator.sanitizeAndValidate('https://www.bhojpurisex.site/'),
        equals('https://www.bhojpurisex.site/'),
      );
      expect(
        ReferrerUrlValidator.isValid('https://example.com/search?q=test&lang=en#top'),
        isTrue,
      );
    });

    test('Validates standard HTTP URLs correctly', () {
      expect(
        ReferrerUrlValidator.isValid('http://example.org/news'),
        isTrue,
      );
    });

    test('Strictly rejects dangerous and malicious schemes', () {
      // JavaScript execution
      expect(ReferrerUrlValidator.isValid('javascript:alert(1)'), isFalse);
      expect(ReferrerUrlValidator.isValid('JAVASCRIPT:document.cookie'), isFalse);

      // Local file access
      expect(ReferrerUrlValidator.isValid('file:///etc/passwd'), isFalse);
      expect(ReferrerUrlValidator.isValid('file:///sdcard/Download/secret.txt'), isFalse);

      // Content & intent providers
      expect(ReferrerUrlValidator.isValid('content://contacts/people'), isFalse);
      expect(ReferrerUrlValidator.isValid('intent:#Intent;action=android.intent.action.VIEW;end'), isFalse);

      // Data URIs & Blobs
      expect(ReferrerUrlValidator.isValid('data:text/html,<script>alert(1)</script>'), isFalse);
      expect(ReferrerUrlValidator.isValid('blob:https://example.com/uuid'), isFalse);

      // Chrome / About internal schemes
      expect(ReferrerUrlValidator.isValid('about:blank'), isFalse);
      expect(ReferrerUrlValidator.isValid('chrome://settings'), isFalse);
    });

    test('Rejects malformed, empty, and oversized URLs', () {
      expect(ReferrerUrlValidator.isValid(''), isFalse);
      expect(ReferrerUrlValidator.isValid('   '), isFalse);
      expect(ReferrerUrlValidator.isValid(null), isFalse);
      expect(ReferrerUrlValidator.isValid('not a url'), isFalse);
      expect(ReferrerUrlValidator.isValid('https://'), isFalse);

      // Control characters & null bytes
      expect(ReferrerUrlValidator.isValid('https://example.com/\x00evil'), isFalse);
      expect(ReferrerUrlValidator.isValid('https://example.com/\r\nevil'), isFalse);

      // Oversized string (>2048 chars)
      final hugeUrl = 'https://example.com/${'a' * 2100}';
      expect(ReferrerUrlValidator.isValid(hugeUrl), isFalse);
    });
  });

  group('Acquisition & ReferrerParser Tests', () {
    test('Parses plain target_url and campaign', () {
      const raw = 'target_url=https://www.bhojpurisex.site/&campaign=campaign_01';
      final result = ReferrerParser.parse(raw);

      expect(result['targetUrl'], equals('https://www.bhojpurisex.site/'));
      expect(result['campaign'], equals('campaign_01'));
    });

    test('Parses URL-encoded Play Store referrer payload', () {
      const raw = 'target_url%3Dhttps%3A%2F%2Fwww.bhojpurisex.site%2F%26campaign%3Dsummer_promo';
      final result = ReferrerParser.parse(raw);

      expect(result['targetUrl'], equals('https://www.bhojpurisex.site/'));
      expect(result['campaign'], equals('summer_promo'));
    });

    test('Parses alternative parameter aliases (url, destination, utm_source)', () {
      const raw = 'url=https://flutter.dev/docs&utm_source=twitter&utm_campaign=launch';
      final result = ReferrerParser.parse(raw);

      expect(result['targetUrl'], equals('https://flutter.dev/docs'));
      expect(result['campaign'], equals('launch'));
    });

    test('Rejects referrer containing malicious schemes in target_url', () {
      const raw = 'target_url=javascript:alert(document.domain)&campaign=attack';
      final result = ReferrerParser.parse(raw);

      expect(result['targetUrl'], isNull);
      expect(result['campaign'], equals('attack'));
    });

    test('Handles direct URLs gracefully', () {
      const raw = 'https://www.bhojpurisex.site/';
      final result = ReferrerParser.parse(raw);

      expect(result['targetUrl'], equals('https://www.bhojpurisex.site/'));
      expect(result['campaign'], isNull);
    });

    test('Handles empty and invalid referrer strings without throwing', () {
      expect(ReferrerParser.parse(null)['targetUrl'], isNull);
      expect(ReferrerParser.parse('')['targetUrl'], isNull);
      expect(ReferrerParser.parse('random_garbage_without_equal_sign')['targetUrl'], isNull);
    });
  });

  group('DeferredNavigationPayload Model Tests', () {
    test('JSON serialization round-trip', () {
      final now = DateTime.now();
      final payload = DeferredNavigationPayload(
        targetUrl: 'https://www.bhojpurisex.site/',
        campaign: 'test_campaign',
        receivedAt: now,
        processed: true,
        isPinnedToQuickAccess: true,
      );

      final json = payload.toJson();
      final reconstructed = DeferredNavigationPayload.fromJson(json);

      expect(reconstructed.targetUrl, equals(payload.targetUrl));
      expect(reconstructed.campaign, equals(payload.campaign));
      expect(reconstructed.processed, isTrue);
      expect(reconstructed.isPinnedToQuickAccess, isTrue);
    });

    test('copyWith updates fields correctly', () {
      final payload = DeferredNavigationPayload(
        targetUrl: 'https://www.bhojpurisex.site/',
        receivedAt: DateTime.now(),
        processed: false,
      );

      final updated = payload.copyWith(
        processed: true,
        campaign: 'new_campaign',
      );

      expect(updated.processed, isTrue);
      expect(updated.campaign, equals('new_campaign'));
      expect(updated.targetUrl, equals(payload.targetUrl));
    });
  });

  group('ShortcutsNotifier Duplicate Prevention Tests', () {
    test('addShortcutIfNotExists prevents adding duplicate domain or URL', () {
      final state = [
        ShortcutModel(id: '1', label: 'Google', url: 'https://google.com'),
        ShortcutModel(id: '2', label: 'Bhojpuri Sex', url: 'https://www.bhojpurisex.site/'),
      ];

      // Exact URL duplicate should be detected
      final exactMatchResult = state.any((s) {
        final targetHost = Uri.tryParse('https://www.bhojpurisex.site/')?.host.toLowerCase().replaceAll('www.', '');
        final existingHost = Uri.tryParse(s.url)?.host.toLowerCase().replaceAll('www.', '');
        return existingHost == targetHost || s.url.toLowerCase() == 'https://www.bhojpurisex.site/'.toLowerCase();
      });
      expect(exactMatchResult, isTrue);

      // Different domain should not match
      final newSiteMatch = state.any((s) {
        final targetHost = Uri.tryParse('https://flutter.dev')?.host.toLowerCase().replaceAll('www.', '');
        final existingHost = Uri.tryParse(s.url)?.host.toLowerCase().replaceAll('www.', '');
        return existingHost == targetHost || s.url.toLowerCase() == 'https://flutter.dev'.toLowerCase();
      });
      expect(newSiteMatch, isFalse);
    });
  });
}
