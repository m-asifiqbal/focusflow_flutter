/// ============================================================
/// FOCUS SESSIONS DAO — focus timer history (Insights › Focus hours)
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/tables.dart';

part 'focus_sessions_dao.g.dart';

@DriftAccessor(tables: [FocusSessions])
class FocusSessionsDao extends DatabaseAccessor<AppDatabase>
    with _$FocusSessionsDaoMixin {
  FocusSessionsDao(super.attachedDatabase);

  /// Sessions that started in [from, to), oldest first.
  SimpleSelectStatement<$FocusSessionsTable, FocusSessionRow> inRange(
    DateTime from,
    DateTime to,
  ) => select(focusSessions)
    ..where(
      (s) =>
          s.startedAt.isBiggerOrEqualValue(from) &
          s.startedAt.isSmallerThanValue(to),
    )
    ..orderBy([(s) => OrderingTerm.asc(s.startedAt)]);

  /// Total minutes of sessions that started in [from, to).
  Selectable<int> totalMinutes(DateTime from, DateTime to) {
    final sum = focusSessions.durationMinutes.sum();
    return (selectOnly(focusSessions)
          ..addColumns([sum])
          ..where(
            focusSessions.startedAt.isBiggerOrEqualValue(from) &
                focusSessions.startedAt.isSmallerThanValue(to),
          ))
        .map((r) => r.read(sum) ?? 0);
  }

  Future<void> insertSession(FocusSessionsCompanion row) =>
      into(focusSessions).insert(row);

  Future<int> deleteSession(String id) =>
      (delete(focusSessions)..where((s) => s.id.equals(id))).go();

  /// Detaches sessions from tasks that were permanently deleted (keeps the
  /// minutes for Insights).
  Future<int> detachTasks(Iterable<String> taskIds) =>
      (update(focusSessions)..where((s) => s.taskId.isIn(taskIds))).write(
        const FocusSessionsCompanion(taskId: Value(null)),
      );
}
