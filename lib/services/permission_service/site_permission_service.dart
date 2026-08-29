import 'package:drift/drift.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/database/app_database.dart';

enum SitePermissionState { allow, ask, block }

/// Service managing per-website permissions with native Android integration and Drift persistence.
class SitePermissionService {
  SitePermissionService(this._db);

  final AppDatabase _db;

  String _normalizeHost(String raw) {
    var h = raw.toLowerCase().trim();
    if (h.startsWith('http://')) h = h.substring(7);
    if (h.startsWith('https://')) h = h.substring(8);
    if (h.startsWith('www.')) h = h.substring(4);
    final slashIndex = h.indexOf('/');
    if (slashIndex != -1) h = h.substring(0, slashIndex);
    final portIndex = h.indexOf(':');
    if (portIndex != -1) h = h.substring(0, portIndex);
    return h;
  }

  Future<SitePermissionState> getPermissionState({
    required String host,
    required String permissionType,
  }) async {
    final normHost = _normalizeHost(host);
    final record = await _db.getSitePermission(normHost, permissionType);
    if (record == null) return SitePermissionState.ask;

    switch (record.state) {
      case 'allow':
        return SitePermissionState.allow;
      case 'block':
        return SitePermissionState.block;
      default:
        return SitePermissionState.ask;
    }
  }

  Future<void> setPermissionState({
    required String host,
    required String permissionType,
    required SitePermissionState state,
  }) async {
    final normHost = _normalizeHost(host);
    final id = '${normHost}_$permissionType';
    final stateStr = state == SitePermissionState.allow
        ? 'allow'
        : (state == SitePermissionState.block ? 'block' : 'ask');

    await _db.setSitePermission(
      SitePermissionsCompanion(
        id: Value(id),
        host: Value(normHost),
        permissionType: Value(permissionType),
        state: Value(stateStr),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> resetHostPermissions(String host) async {
    final normHost = _normalizeHost(host);
    await _db.clearSitePermissionsForHost(normHost);
  }

  /// Verifies and requests native device permission from Android OS.
  Future<bool> requestNativeDevicePermission(String permissionType) async {
    Permission? perm;
    if (permissionType == 'camera') {
      perm = Permission.camera;
    } else if (permissionType == 'microphone') {
      perm = Permission.microphone;
    } else if (permissionType == 'location') {
      perm = Permission.locationWhenInUse;
    } else if (permissionType == 'notification') {
      perm = Permission.notification;
    }

    if (perm == null) return true;

    final status = await perm.status;
    if (status.isGranted) return true;

    final result = await perm.request();
    return result.isGranted;
  }
}
