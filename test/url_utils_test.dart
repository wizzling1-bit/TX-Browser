import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/core/utils/url_utils.dart';

void main() {
  group('UrlUtils', () {
    test('isUrl correctly identifies valid URLs', () {
      expect(UrlUtils.isUrl('https://example.com'), isTrue);
      expect(UrlUtils.isUrl('http://example.com/path?arg=val'), isTrue);
      expect(UrlUtils.isUrl('example.com'), isTrue);
      expect(UrlUtils.isUrl('sub.domain.co.uk'), isTrue);
      expect(UrlUtils.isUrl('192.168.1.1'), isTrue);
      expect(UrlUtils.isUrl('localhost:8080'), isTrue);
    });

    test('isUrl correctly rejects non-URLs (search queries)', () {
      expect(UrlUtils.isUrl('hello world'), isFalse);
      expect(UrlUtils.isUrl('how to build a browser'), isFalse);
      expect(UrlUtils.isUrl(''), isFalse);
      expect(UrlUtils.isUrl('   '), isFalse);
    });

    test('normalizeUrl prepends https when needed', () {
      expect(
        UrlUtils.normalizeUrl('example.com'),
        equals('https://example.com'),
      );
      expect(
        UrlUtils.normalizeUrl('https://example.com'),
        equals('https://example.com'),
      );
      expect(UrlUtils.normalizeUrl('search query'), isNull);
    });

    test('extractDomain removes www and extracts domain', () {
      expect(
        UrlUtils.extractDomain('https://www.google.com/search?q=test'),
        equals('google.com'),
      );
      expect(
        UrlUtils.extractDomain('https://github.com/flutter/flutter'),
        equals('github.com'),
      );
    });

    test('isSecure detects HTTPS correctly', () {
      expect(UrlUtils.isSecure('https://example.com'), isTrue);
      expect(UrlUtils.isSecure('http://example.com'), isFalse);
      expect(UrlUtils.isSecure('not a url'), isFalse);
    });

    test('isExternalScheme detects external link schemes', () {
      expect(UrlUtils.isExternalScheme('tel'), isTrue);
      expect(UrlUtils.isExternalScheme('mailto'), isTrue);
      expect(UrlUtils.isExternalScheme('intent'), isTrue);
      expect(UrlUtils.isExternalScheme('http'), isFalse);
      expect(UrlUtils.isExternalScheme('https'), isFalse);
    });
  });
}
