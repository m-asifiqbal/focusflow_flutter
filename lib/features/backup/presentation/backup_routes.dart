/// Routes owned by the backup feature (screens 34 Backup & Sync,
/// 35 Import & Export).
library;

import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// `/settings/backup`, `/settings/backup/restore`, `/settings/import-export`.
final List<RouteBase> backupSettingsRoutes = [
  GoRoute(
    path: 'backup',
    builder: (context, state) => const PlaceholderScreen('Backup & Sync'),
    routes: [
      GoRoute(
        path: 'restore',
        builder: (context, state) => const PlaceholderScreen('Restore'),
      ),
    ],
  ),
  GoRoute(
    path: 'import-export',
    builder: (context, state) => const PlaceholderScreen('Import & Export'),
  ),
];
