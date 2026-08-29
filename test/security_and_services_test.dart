import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/services/security_service/app_lock_service.dart';
import 'package:tx_browser/state/history_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLockService Tests', () {
    final service = AppLockService();

    test('hashPin returns consistent non-empty SHA256 hash', () {
      final hash1 = service.hashPin('1234');
      final hash2 = service.hashPin('1234');
      final hashDiff = service.hashPin('5678');

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hashDiff)));
      expect(hash1.length, equals(64)); // SHA-256 hex length
    });

    test('verifyPin correctly matches valid PIN and rejects invalid PIN', () {
      final hash = service.hashPin('9876');
      expect(service.verifyPin('9876', hash), isTrue);
      expect(service.verifyPin('0000', hash), isFalse);
      expect(service.verifyPin('987', hash), isFalse);
    });
  });

  group('HistoryEntryModel Tests', () {
    test('domain extracts clean host name without www', () {
      final entry1 = HistoryEntryModel(
        id: '1',
        url: 'https://www.github.com/flutter/flutter',
        title: 'Flutter',
        visitedAt: DateTime.now(),
      );
      expect(entry1.domain, equals('github.com'));

      final entry2 = HistoryEntryModel(
        id: '2',
        url: 'https://docs.flutter.dev/ui',
        title: 'Docs',
        visitedAt: DateTime.now(),
      );
      expect(entry2.domain, equals('docs.flutter.dev'));
    });
  });
}
