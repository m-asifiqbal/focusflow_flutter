/// ============================================================
/// HABIT CSV SHARE SERVICE — "Export CSV" of the habit detail (16)
/// ============================================================
///
/// Writes HabitCsv.export into the temporary directory and hands the file
/// to the platform share sheet (share_plus). Nothing leaves the device
/// unless the user picks a share target; contents are never logged. The
/// plaintext file (it holds notes) is deleted as soon as the share sheet
/// completes — Android's share_plus has copied it into its own cache by
/// then and iOS returns once the activity is done — so no unencrypted
/// copy lingers on disk.
/// ============================================================
library;

import 'dart:io';

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class HabitCsvShareService {
  const HabitCsvShareService();

  /// Exports [habit]'s [logs] and opens the share sheet. Returns false when
  /// the user dismissed it.
  Future<bool> share(Habit habit, List<HabitLog> logs) async {
    final dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'exports'),
    );
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, HabitCsv.fileName(habit)));
    try {
      await file.writeAsString(HabitCsv.export(habit, logs), flush: true);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: tr('{name} history', {'name': habit.name}),
        ),
      );
      return result.status != ShareResultStatus.dismissed;
    } finally {
      try {
        if (file.existsSync()) await file.delete();
      } on FileSystemException {
        // Best effort: the OS clears the temporary directory eventually.
      }
    }
  }
}
