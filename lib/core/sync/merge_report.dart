/// ============================================================
/// MERGE REPORT — what a Merge restore / sync changed
/// ============================================================
///
/// Counted per *row* of the item tables (notes, tasks, reminders, habits,
/// vault items) — child rows (subtasks, tags, logs…) follow their parent
/// and are not counted separately. Shown as "3 items updated from another
/// device" on Backup & Sync (34) and in the restore summary.
/// ============================================================
library;

import 'package:flutter/foundation.dart';

@immutable
class MergeReport {
  const MergeReport({
    this.added = 0,
    this.updated = 0,
    this.keptLocal = 0,
    this.deleted = 0,
    this.skipped = 0,
    this.vaultSkipped = 0,
    this.filesNeeded = const {},
  });

  /// Items that only existed in the incoming backup.
  final int added;

  /// Items whose incoming version was newer and replaced the local one.
  final int updated;

  /// Items that differed but the local version was newer (kept).
  final int keptLocal;

  /// Items removed because the backup carried a newer deletion.
  final int deleted;

  /// Incoming items ignored because this device deleted them later.
  final int skipped;

  /// Vault items not merged because they are encrypted with another
  /// vault key (see VaultBackupBridge).
  final int vaultSkipped;

  /// Attachment / cover paths (relative to app documents) the merged rows
  /// reference — the caller copies them out of the archive.
  final Set<String> filesNeeded;

  /// Rows present on both sides with different content (resolved by
  /// last-write-wins).
  int get conflicts => updated + keptLocal;

  /// Changes applied to this device.
  int get changes => added + updated + deleted;

  MergeReport copyWith({
    int? added,
    int? updated,
    int? keptLocal,
    int? deleted,
    int? skipped,
    int? vaultSkipped,
    Set<String>? filesNeeded,
  }) => MergeReport(
    added: added ?? this.added,
    updated: updated ?? this.updated,
    keptLocal: keptLocal ?? this.keptLocal,
    deleted: deleted ?? this.deleted,
    skipped: skipped ?? this.skipped,
    vaultSkipped: vaultSkipped ?? this.vaultSkipped,
    filesNeeded: filesNeeded ?? this.filesNeeded,
  );

  /// Sum of two reports (several backups merged in one sync).
  MergeReport operator +(MergeReport o) => MergeReport(
    added: added + o.added,
    updated: updated + o.updated,
    keptLocal: keptLocal + o.keptLocal,
    deleted: deleted + o.deleted,
    skipped: skipped + o.skipped,
    vaultSkipped: vaultSkipped + o.vaultSkipped,
    filesNeeded: {...filesNeeded, ...o.filesNeeded},
  );

  @override
  String toString() =>
      'MergeReport(added $added, updated $updated, kept $keptLocal, '
      'deleted $deleted, skipped $skipped, vaultSkipped $vaultSkipped)';
}
