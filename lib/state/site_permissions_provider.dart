import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../services/permission_service/site_permission_service.dart';
import 'database_provider.dart';

final sitePermissionServiceProvider = Provider<SitePermissionService>((ref) {
  final db = ref.watch(databaseProvider);
  return SitePermissionService(db);
});

final allSitePermissionsStreamProvider = StreamProvider<List<SitePermission>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllSitePermissions();
});
