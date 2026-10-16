/// ============================================================
/// ACCOUNT ACTIVITY — Drift implementation of [AccountActivityRepository]
/// ============================================================
///
/// "Days active" is computed in SQL as the number of distinct local days
/// (`date(..., 'localtime')`) that appear in the item tables' created_at,
/// tasks' completed_at, habit logs with a count and focus sessions. It
/// counts archived / deleted items too: the activity happened.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/features/auth/domain/repository/account_activity_repository.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

class AccountActivityRepositoryImpl implements AccountActivityRepository {
  AccountActivityRepositoryImpl(this.db);

  final AppDatabase db;

  static const String _sql = '''
SELECT COUNT(*) AS c FROM (
  SELECT date(created_at, 'unixepoch', 'localtime') AS d FROM notes
  UNION SELECT date(created_at, 'unixepoch', 'localtime') FROM tasks
  UNION SELECT date(completed_at, 'unixepoch', 'localtime') FROM tasks
    WHERE completed_at IS NOT NULL
  UNION SELECT date(created_at, 'unixepoch', 'localtime') FROM reminders
  UNION SELECT date(created_at, 'unixepoch', 'localtime') FROM habits
  UNION SELECT date(created_at, 'unixepoch', 'localtime') FROM vault_items
  UNION SELECT date FROM habit_logs WHERE count > 0
  UNION SELECT date(started_at, 'unixepoch', 'localtime') FROM focus_sessions
)''';

  @override
  Stream<int> watchDaysActive() => db
      .customSelect(
        _sql,
        readsFrom: {
          db.notes,
          db.tasks,
          db.reminders,
          db.habits,
          db.vaultItems,
          db.habitLogs,
          db.focusSessions,
        },
      )
      .watchSingle()
      .map((r) => r.read<int>('c'));
}

final accountActivityRepositoryProvider = Provider<AccountActivityRepository>(
  (ref) => AccountActivityRepositoryImpl(ref.watch(databaseProvider)),
);
