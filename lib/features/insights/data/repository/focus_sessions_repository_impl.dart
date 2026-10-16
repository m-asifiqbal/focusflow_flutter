/// ============================================================
/// FOCUS SESSIONS REPOSITORY (Drift implementation)
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/focus_sessions_dao.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/features/insights/domain/entities/focus_session.dart';
import 'package:focusflow/features/insights/domain/repository/focus_sessions_repository.dart';

class FocusSessionsRepositoryImpl extends RepositoryBase
    implements FocusSessionsRepository {
  FocusSessionsRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
  }) : _dao = FocusSessionsDao(db);

  final FocusSessionsDao _dao;

  @override
  Future<String> add({
    String? taskId,
    required DateTime startedAt,
    required int durationMinutes,
  }) async {
    final id = newId();
    await _dao.insertSession(
      FocusSessionsCompanion.insert(
        id: id,
        taskId: Value(taskId),
        startedAt: RepositoryBase.truncateToSeconds(startedAt),
        durationMinutes: durationMinutes < 0 ? 0 : durationMinutes,
      ),
    );
    return id;
  }

  @override
  Stream<List<FocusSession>> watchRange(DateTime from, DateTime to) =>
      db.watchComputed({db.focusSessions}, () async {
        final rows = await _dao.inRange(from, to).get();
        return [
          for (final s in rows)
            FocusSession(
              id: s.id,
              taskId: s.taskId,
              startedAt: s.startedAt,
              durationMinutes: s.durationMinutes,
            ),
        ];
      });

  @override
  Stream<int> watchTotalMinutes(DateTime from, DateTime to) =>
      _dao.totalMinutes(from, to).watchSingle().distinct();

  @override
  Future<void> delete(String id) => _dao.deleteSession(id);
}
