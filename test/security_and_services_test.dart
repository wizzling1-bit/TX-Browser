import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:tx_browser/data/database/app_database.dart';
import 'package:tx_browser/services/permission_service/site_permission_service.dart';
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

  group('SitePermissionService Unit Tests', () {
    late AppDatabase db;
    late SitePermissionService permService;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      permService = SitePermissionService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('default permissions fallback to ask, and can be customized', () async {
      final initialCam = await permService.getDefaultPermission('camera');
      expect(initialCam, equals(SitePermissionState.ask));

      await permService.setDefaultPermission('camera', SitePermissionState.block);
      final updatedCam = await permService.getDefaultPermission('camera');
      expect(updatedCam, equals(SitePermissionState.block));

      // Site without record should now receive default block
      final siteState = await permService.getPermissionState(
        host: 'example.com',
        permissionType: 'camera',
      );
      expect(siteState, equals(SitePermissionState.block));
    });

    test('host-specific permission overrides default and can be deleted', () async {
      await permService.setDefaultPermission('location', SitePermissionState.block);

      // Explicitly allow location for maps.google.com
      await permService.setPermissionState(
        host: 'maps.google.com',
        permissionType: 'location',
        state: SitePermissionState.allow,
      );

      final mapsState = await permService.getPermissionState(
        host: 'maps.google.com',
        permissionType: 'location',
      );
      expect(mapsState, equals(SitePermissionState.allow));

      // Other site gets default
      final otherState = await permService.getPermissionState(
        host: 'other.com',
        permissionType: 'location',
      );
      expect(otherState, equals(SitePermissionState.block));

      // Delete maps rule -> should revert to default block
      await permService.deletePermission(
        host: 'maps.google.com',
        permissionType: 'location',
      );
      final reverted = await permService.getPermissionState(
        host: 'maps.google.com',
        permissionType: 'location',
      );
      expect(reverted, equals(SitePermissionState.block));
    });

    test('clearAllPermissions clears all site permission rows', () async {
      await permService.setPermissionState(
        host: 'site1.com',
        permissionType: 'microphone',
        state: SitePermissionState.allow,
      );
      await permService.setPermissionState(
        host: 'site2.com',
        permissionType: 'camera',
        state: SitePermissionState.allow,
      );

      final allBefore = await db.getAllSitePermissions();
      expect(allBefore.length, equals(2));

      await permService.clearAllPermissions();

      final allAfter = await db.getAllSitePermissions();
      expect(allAfter, isEmpty);
    });
  });
}
