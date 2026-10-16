/// ============================================================
/// SYNC CONTROLLER — drives syncStatusProvider ("Sync now", auto backup)
/// ============================================================
///
/// Wraps [DriveSync.syncNow] in a status the UI can render: Preparing… →
/// Uploading 40% → Downloading / Merging → Done ("Last sync 2 min ago",
/// "3 items updated from another device", skipped-backup warnings) or
/// Error with a sentence-case reason (offline / sign in again / Drive full
/// / set a backup PIN). The last successful sync time is kept in prefs so
/// it survives restarts. One sync at a time: a second call while busy
/// returns null, and the busy state is always left (finally), whatever
/// the sync threw.
///
/// Resume hook: the workmanager isolate writes backups, prefs and rows
/// behind the UI's back. When the app comes back after a while, prefs are
/// reloaded, "Last sync" is re-read and every Drift stream is told to
/// re-query, so screens show what the background job did.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/sync/backup_key_policy.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/network_info.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

class SyncController extends Notifier<SyncStatus> {
  /// Prefs key: ISO time of the last successful Drive sync.
  static const String lastSyncKey = 'drive_last_sync_at';

  /// Away at least this long before a resume refreshes from disk (a
  /// background job can't have run in a shorter gap).
  static const Duration resumeRefreshAfter = Duration(seconds: 30);

  DateTime? _hiddenAt;

  @override
  SyncStatus build() {
    _attachResumeHook();
    return SyncStatus(lastSyncAt: _storedLastSync());
  }

  DateTime? _storedLastSync() {
    final raw = ref.read(sharedPreferencesProvider).getString(lastSyncKey);
    return DateTime.tryParse(raw ?? '')?.toLocal();
  }

  void _attachResumeHook() {
    try {
      final listener = AppLifecycleListener(
        onHide: () => _hiddenAt = ref.read(clockProvider).now(),
        onResume: () {
          final hidden = _hiddenAt;
          _hiddenAt = null;
          if (hidden == null) return;
          final away = ref.read(clockProvider).now().difference(hidden);
          if (away >= resumeRefreshAfter) unawaited(refreshFromDisk());
        },
      );
      ref.onDispose(listener.dispose);
    } on Object {
      // No widgets binding (background isolate / unit tests): nothing to
      // resume from.
    }
  }

  /// Picks up what a background run wrote: reloads prefs, re-reads the
  /// last sync time and makes every Drift stream re-query.
  Future<void> refreshFromDisk() async {
    try {
      await ref.read(sharedPreferencesProvider).reload();
    } on Object catch (e) {
      AppLogger.w('Prefs reload failed (${e.runtimeType})');
    }
    final last = _storedLastSync();
    if (!state.isBusy && last != state.lastSyncAt) {
      // A newer successful sync supersedes an old error / done message.
      state = SyncStatus(lastSyncAt: last);
    }
    try {
      final db = ref.read(databaseProvider);
      db.markTablesUpdated(db.allTables);
    } on Object catch (e) {
      AppLogger.w('Stream refresh failed (${e.runtimeType})');
    }
  }

  /// Backs up to Drive and merges other devices' newer backups. Returns
  /// null when it failed (see [SyncStatus.failure]) or a sync was already
  /// running. [interactive] lets Google show its consent sheet if needed
  /// (false for background runs).
  Future<SyncOutcome?> syncNow({
    bool isAuto = false,
    bool interactive = true,
  }) async {
    if (state.isBusy) return null;
    final last = state.lastSyncAt;
    state = SyncStatus(phase: SyncPhase.preparing, lastSyncAt: last);
    void fail(String message, {DriveFailureKind? kind, bool pin = false}) {
      state = SyncStatus(
        phase: SyncPhase.error,
        lastSyncAt: last,
        message: message,
        failure: kind,
        needsBackupPin: pin,
      );
    }

    try {
      if (!await ref.read(networkInfoProvider).isOnline()) {
        throw const DriveFailure(DriveFailureKind.offline);
      }
      final outcome = await ref
          .read(driveSyncProvider)
          .syncNow(
            isAuto: isAuto,
            interactive: interactive,
            onProgress: (phase, progress) {
              if (phase == SyncPhase.done) return;
              state = SyncStatus(
                phase: phase,
                progress: progress,
                lastSyncAt: last,
              );
            },
          );
      // The backup is in Drive: this counts as a successful sync even
      // when some merge step was skipped (warnings), so the scheduler
      // doesn't upload + prune again at every opportunity.
      final now = ref.read(clockProvider).now();
      await ref
          .read(sharedPreferencesProvider)
          .setString(lastSyncKey, now.toUtc().toIso8601String());
      state = SyncStatus(
        phase: SyncPhase.done,
        progress: 1,
        lastSyncAt: now,
        conflictsResolved: outcome.report.changes,
        message: summary(outcome),
        warnings: outcome.warnings,
      );
      if (outcome.report.changes > 0) _replanNotifications();
      return outcome;
    } on DriveFailure catch (f) {
      AppLogger.w('Sync failed: ${f.kind.name}');
      fail(f.message, kind: f.kind);
    } on BackupPinRequired catch (e) {
      AppLogger.w('Sync skipped: backup PIN not set');
      fail(e.message, pin: true);
    } on BackupKeyUnavailable catch (e) {
      AppLogger.w('Sync failed: backup key unreadable');
      fail(e.message);
    } catch (e, st) {
      // Never log payloads: the error type is enough to triage.
      AppLogger.e('Sync failed (${e.runtimeType})', stackTrace: st);
      const f = DriveFailure(DriveFailureKind.unknown);
      fail(f.message, kind: f.kind);
    } finally {
      // Whatever happened above, never leave the UI spinning.
      if (state.isBusy) {
        const f = DriveFailure(DriveFailureKind.unknown);
        fail(f.message, kind: f.kind);
      }
    }
    return null;
  }

  /// Back to idle (dismiss a Done / Error state).
  void reset() {
    if (!state.isBusy) state = SyncStatus(lastSyncAt: state.lastSyncAt);
  }

  /// Sign-out / erase: forget the last sync time (it described another
  /// account's Drive or data that is gone).
  Future<void> forgetLastSync() async {
    await ref.read(sharedPreferencesProvider).remove(lastSyncKey);
    if (!state.isBusy) state = const SyncStatus();
  }

  /// One line for the status box after a successful sync.
  static String summary(SyncOutcome o) {
    final parts = <String>['Backed up to Google Drive'];
    final n = o.report.changes;
    if (n > 0) {
      parts.add('$n ${n == 1 ? 'item' : 'items'} updated from another device');
    }
    if (o.needsPin > 0) {
      parts.add(
        o.needsPin == 1
            ? '1 backup from another device needs its backup PIN'
            : '${o.needsPin} backups from other devices need their backup PIN',
      );
    }
    if (o.mergeDeferred) {
      parts.add('Choose Restore or Start fresh to use your other backups');
    }
    parts.addAll(o.warnings);
    return parts.join(' · ');
  }

  /// Merged reminders/habits may have new times: re-plan notifications.
  void _replanNotifications() {
    unawaited(
      Future(() => ref.read(notificationEngineProvider).onResume()).catchError(
        (Object e) =>
            AppLogger.w('Re-plan after sync failed (${e.runtimeType})'),
      ),
    );
  }
}
