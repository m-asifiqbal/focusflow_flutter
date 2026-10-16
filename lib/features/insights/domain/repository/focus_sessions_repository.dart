/// ============================================================
/// FOCUS SESSIONS REPOSITORY (contract)
/// ============================================================
library;

import 'package:focusflow/features/insights/domain/entities/focus_session.dart';

abstract interface class FocusSessionsRepository {
  /// Records a finished session. Returns its id.
  Future<String> add({
    String? taskId,
    required DateTime startedAt,
    required int durationMinutes,
  });

  /// Sessions that started in [from, to), oldest first.
  Stream<List<FocusSession>> watchRange(DateTime from, DateTime to);

  /// Total focus minutes of sessions that started in [from, to).
  Stream<int> watchTotalMinutes(DateTime from, DateTime to);

  Future<void> delete(String id);
}
