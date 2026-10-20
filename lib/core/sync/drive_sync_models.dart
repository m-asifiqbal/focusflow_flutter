/// ============================================================
/// DRIVE SYNC MODELS — results of Sync now / usage / cloud delete
/// ============================================================
///
/// Plain value types returned by DriveSync (drive_sync.dart re-exports
/// this file, so callers keep importing drive_sync.dart).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/sync/drive_backup_file.dart';
import 'package:focusflow/core/sync/merge_report.dart';

/// What one sync did.
@immutable
class SyncOutcome {
  const SyncOutcome({
    this.uploaded,
    this.pruned = 0,
    this.mergedBackups = 0,
    this.report = const MergeReport(),
    this.needsPin = 0,
    this.warnings = const [],
    this.mergeDeferred = false,
  });

  /// The backup this sync uploaded; null when Drive already held this
  /// device's current data and the sync only merged ([DriveSync.syncNow]
  /// with `skipUnchanged`).
  final DriveBackupFile? uploaded;

  /// Old Drive backups of this device removed ("Keep last N").
  final int pruned;

  /// Backups of other devices merged into this one.
  final int mergedBackups;

  /// Combined per-item outcome of those merges.
  final MergeReport report;

  /// Other devices' encrypted backups our key could not open.
  final int needsPin;

  /// Sentence-case notes about steps that were skipped without failing
  /// the sync ("Couldn't read the backup from Pixel 8", …).
  final List<String> warnings;

  /// Merging waits for the user's Restore / Start fresh choice.
  final bool mergeDeferred;
}

/// How much of the user's Drive the app folder uses.
@immutable
class DriveUsage {
  const DriveUsage({
    required this.usedBytes,
    this.limitBytes,
    this.backups = 0,
  });

  final int usedBytes;

  /// The account's total storage; null when Drive didn't say.
  final int? limitBytes;
  final int backups;

  /// 0..1 of [limitBytes] (0 when unknown).
  double get fraction {
    final l = limitBytes;
    if (l == null || l <= 0) return 0;
    return (usedBytes / l).clamp(0, 1).toDouble();
  }
}

/// "Delete account & Drive data" removed only some of the app's Drive
/// files. Running it again picks up where it stopped (deleting a file
/// that is already gone is not an error).
class CloudDeleteIncomplete implements Exception {
  const CloudDeleteIncomplete({required this.deleted, required this.total});

  /// Files deleted by this attempt.
  final int deleted;

  /// Files that were in the app folder when it started.
  final int total;

  int get remaining => total - deleted;

  @override
  String toString() => 'CloudDeleteIncomplete($deleted of $total)';
}
