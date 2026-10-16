/// ============================================================
/// EXPORT FILTER — narrows a DB snapshot to the chosen modules
/// ============================================================
///
/// What: keeps the item rows of the INCLUDE modules (never trash; archived
/// only with "Include archived") plus their children (subtasks, habit
/// logs, tag links, attachments, vault history, focus sessions). Folders
/// and tags travel whole (they are small and referenced by name).
/// Why: an export is a restore point, not a sync stream, so tombstones
/// are dropped — merging a partial export never deletes anything.
/// Pure Dart over raw rows: no Drift, unit-tested directly.
/// ============================================================
library;

import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/features/backup/domain/entities/export_options.dart';

abstract final class ExportFilter {
  /// The rows of [s] that an export with [modules] / [includeArchived]
  /// carries.
  static DbSnapshot apply(
    DbSnapshot s, {
    required Set<ExportModule> modules,
    required bool includeArchived,
  }) {
    bool keepItem(RawRow r) =>
        r['deleted_at'] == null &&
        (includeArchived || r['archived_at'] == null);

    final kept = <String, List<RawRow>>{};
    final ids = <String, Set<Object?>>{};
    for (final m in ExportModule.values) {
      final rows = modules.contains(m)
          ? s.rows(m.table).where(keepItem).toList()
          : <RawRow>[];
      kept[m.table] = rows;
      ids[m.itemType] = {for (final r in rows) r['id']};
    }
    bool parentKept(String type, Object? id) =>
        ids[type]?.contains(id) ?? false;

    return DbSnapshot({
      ...kept,
      'folders': s.rows('folders'),
      'tags': s.rows('tags'),
      'subtasks': [
        for (final r in s.rows('subtasks'))
          if (parentKept('task', r['task_id'])) r,
      ],
      'habit_logs': [
        for (final r in s.rows('habit_logs'))
          if (parentKept('habit', r['habit_id'])) r,
      ],
      'vault_history': [
        for (final r in s.rows('vault_history'))
          if (parentKept('vault', r['item_id'])) r,
      ],
      'item_tags': [
        for (final r in s.rows('item_tags'))
          if (parentKept('${r['item_type']}', r['item_id'])) r,
      ],
      'attachments': [
        for (final r in s.rows('attachments'))
          if (parentKept('${r['item_type']}', r['item_id'])) r,
      ],
      'focus_sessions': modules.contains(ExportModule.tasks)
          ? s.rows('focus_sessions')
          : const [],
      'tombstones': const [],
    });
  }

  /// Items in a filtered snapshot (the "Export N items" count).
  static int itemCount(DbSnapshot s) => [
    for (final m in ExportModule.values) s.rows(m.table).length,
  ].fold(0, (a, b) => a + b);
}
