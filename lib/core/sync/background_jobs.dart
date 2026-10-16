/// ============================================================
/// BACKGROUND JOBS — what the scheduled tasks actually do
/// ============================================================
///
/// Shared by the workmanager isolate (background_runner.dart) and the
/// launch-time catch-up (an overdue backup runs when the app opens, since
/// iOS may never grant background time):
/// * auto local backup (Settings › Local backup: daily / weekly);
/// * auto Drive backup + merge, when signed in with Google, "Automatic
///   backup" is on, the chosen time has passed ([BackupSchedule]) and —
///   with "Wi-Fi only" — the device is on Wi-Fi; never interactive;
/// * maintenance (purge Recently Deleted after 30 days).
/// Each step is isolated: one failing never skips the others.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/startup/maintenance.dart';
import 'package:focusflow/core/sync/backup_schedule.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/network_info.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Reads a provider (a ProviderContainer's or a Ref's `read`).
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Which steps ran (for tests and logs).
enum BackgroundStep { localBackup, driveBackup, maintenance }

class BackgroundJobs {
  BackgroundJobs(this._read);

  final ProviderReader _read;

  /// Runs the backup steps (and, with [maintenance], the purge). Returns
  /// the steps that did work.
  Future<Set<BackgroundStep>> run({bool maintenance = true}) async {
    final done = <BackgroundStep>{};
    await _step('local backup', () async {
      final freq = _read(settingsProvider).localBackupFrequency;
      final r = await _read(localBackupsProvider).runAutoIfDue(freq);
      if (r != null) done.add(BackgroundStep.localBackup);
    });
    await _step('drive backup', () async {
      if (await isDriveBackupDue()) {
        final outcome = await _read(
          syncStatusProvider.notifier,
        ).syncNow(isAuto: true, interactive: false);
        if (outcome != null) done.add(BackgroundStep.driveBackup);
      }
    });
    if (maintenance) {
      await _step('maintenance', () async {
        await _read(maintenanceProvider).runIfDue();
        done.add(BackgroundStep.maintenance);
      });
    }
    return done;
  }

  /// Signed in with Google, auto backup on, the slot has passed, and the
  /// network allows it.
  Future<bool> isDriveBackupDue() async {
    final s = _read(settingsProvider);
    if (!s.autoBackupDrive) return false;
    await _read(cloudAccountProvider.notifier).loaded;
    final account = _read(cloudAccountProvider);
    if (account == null || !account.hasDrive) return false;
    if (!_read(cloudAccountControllerProvider).googleAvailable) return false;
    final due = BackupSchedule.isDriveDue(
      now: _read(clockProvider).now(),
      lastSync: _read(syncStatusProvider).lastSyncAt,
      frequency: s.backupFrequency,
      minutesOfDay: s.backupMinutes,
    );
    if (!due) return false;
    final net = _read(networkInfoProvider);
    return s.backupWifiOnly ? net.isOnWifi() : net.isOnline();
  }

  Future<void> _step(String name, Future<void> Function() body) async {
    try {
      await body();
    } catch (e, st) {
      AppLogger.e('Background $name failed (${e.runtimeType})', stackTrace: st);
    }
  }
}
