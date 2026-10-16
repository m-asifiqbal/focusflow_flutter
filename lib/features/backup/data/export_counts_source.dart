/// ============================================================
/// EXPORT COUNTS SOURCE — live active / archived counts per module
/// ============================================================
///
/// What: one watched SQL query counting the non-deleted items of each
/// module, split into active and archived (the INCLUDE counts on screen 35).
/// Why: the library counts don't split archived items per module; a
/// watched query keeps the numbers live when anything changes elsewhere.
/// ============================================================
library;

import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/features/backup/domain/entities/export_options.dart';

class ExportCountsSource {
  const ExportCountsSource(this.db);

  final AppDatabase db;

  Stream<ExportCounts> watch() {
    final sql = [
      for (final m in ExportModule.values)
        "SELECT '${m.name}' AS module, "
            'SUM(archived_at IS NULL) AS active, '
            'SUM(archived_at IS NOT NULL) AS archived '
            'FROM ${m.table} WHERE deleted_at IS NULL',
    ].join(' UNION ALL ');
    return db
        .customSelect(
          sql,
          readsFrom: {
            db.notes,
            db.tasks,
            db.reminders,
            db.habits,
            db.vaultItems,
          },
        )
        .watch()
        .map((rows) {
          final active = <ExportModule, int>{};
          final archived = <ExportModule, int>{};
          for (final r in rows) {
            final m = ExportModule.values.byName(r.read<String>('module'));
            active[m] = r.read<int?>('active') ?? 0;
            archived[m] = r.read<int?>('archived') ?? 0;
          }
          return ExportCounts(active: active, archived: archived);
        });
  }
}
