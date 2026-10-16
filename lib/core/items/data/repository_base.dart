/// ============================================================
/// REPOSITORY BASE — the dependencies every repository impl shares
/// ============================================================
///
/// Repositories are constructed with explicit dependencies (no globals):
/// the database, a [Clock] (fake it in tests), this install's device id
/// (written into every row for sync) and an id generator (uuid v4 in the
/// app, counters in tests). See shared/providers/repository_providers.dart.
/// ============================================================
library;

import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/utils/clock.dart';

/// Returns a new unique row id (uuid v4 in production).
typedef IdGenerator = String Function();

abstract class RepositoryBase {
  RepositoryBase({
    required this.db,
    required this.clock,
    required this.deviceId,
    required this.newId,
  });

  final AppDatabase db;
  final Clock clock;
  final String deviceId;
  final IdGenerator newId;

  /// Stamp for a write happening now.
  WriteStamp stamp([DateTime? at]) => WriteStamp(at ?? now(), deviceId);

  /// The clock's now, truncated to whole seconds (the precision Drift
  /// stores), so values read back compare equal to what was written.
  DateTime now() => truncateToSeconds(clock.now());

  static DateTime truncateToSeconds(DateTime t) =>
      DateTime.fromMillisecondsSinceEpoch(
        t.millisecondsSinceEpoch - t.millisecondsSinceEpoch % 1000,
        isUtc: t.isUtc,
      );
}
