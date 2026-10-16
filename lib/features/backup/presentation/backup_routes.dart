/// Routes owned by the backup feature (screens 34 Backup & Sync,
/// 35 Import & Export).
library;

import 'package:focusflow/features/backup/presentation/screens/backup_sync_screen.dart';
import 'package:focusflow/features/backup/presentation/screens/import_export_screen.dart';
import 'package:focusflow/features/backup/presentation/screens/restore_screen.dart';
import 'package:go_router/go_router.dart';

/// `/settings/backup`, `/settings/backup/restore`, `/settings/import-export`.
final List<RouteBase> backupSettingsRoutes = [
  GoRoute(
    path: 'backup',
    builder: (context, state) => const BackupSyncScreen(),
    routes: [
      GoRoute(
        path: 'restore',
        builder: (context, state) => const RestoreScreen(),
      ),
    ],
  ),
  GoRoute(
    path: 'import-export',
    builder: (context, state) => const ImportExportScreen(),
  ),
];
