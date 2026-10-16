/// ============================================================
/// BACKGROUND TASKS — cross-feature contract + workmanager scheduling
/// ============================================================
///
/// Registers two workmanager jobs (identifiers also declared in iOS
/// Info.plist › BGTaskSchedulerPermittedIdentifiers and AppDelegate.swift):
/// * [BackgroundTasks.backupTask] — daily at Settings › Backup › time.
///   Android: periodic 24 h with an initial delay to the chosen time and a
///   network constraint (unmetered with "Wi-Fi only"); iOS: a one-shot
///   BGProcessingTask, re-submitted on every launch and after each run.
/// * [BackgroundTasks.maintenanceTask] — every ~12 h: trash purge + the
///   auto local backup (needs no network).
/// The jobs run in background_runner.dart; what they do is BackgroundJobs.
/// [ensureScheduled] also catches up an overdue backup when the app opens.
/// Rescheduling happens automatically when the backup settings or the
/// account change.
/// ============================================================
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/background_jobs.dart';
import 'package:focusflow/core/sync/background_runner.dart';
import 'package:focusflow/core/sync/backup_schedule.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:workmanager/workmanager.dart';

abstract class BackgroundTasks {
  static const String backupTask = 'com.iqballab.focusflow.backup';
  static const String maintenanceTask = 'com.iqballab.focusflow.maintenance';

  /// (Re)schedules jobs to match the current settings. Idempotent.
  Future<void> ensureScheduled();
}

/// What the backup job needs, as a comparable string (re-register only
/// when it changes, so Android's periodic timer is not reset each launch).
@visibleForTesting
String backupSignature(AppSettings s, CloudAccount? account) {
  final drive = s.autoBackupDrive && (account?.hasDrive ?? false);
  final local = s.localBackupFrequency != LocalBackupFrequency.off;
  return [
    drive,
    local,
    s.backupFrequency.name,
    s.backupMinutes,
    s.backupWifiOnly,
  ].join('|');
}

class WorkmanagerBackgroundTasks implements BackgroundTasks {
  WorkmanagerBackgroundTasks(this._ref);

  final Ref _ref;
  Future<void>? _init;
  bool _caughtUp = false;

  static const String _signatureKey = 'background_backup_signature';

  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<void> ensureScheduled() async {
    if (!supported) return;
    await (_init ??= Workmanager().initialize(backgroundDispatcher));
    await _scheduleMaintenance();
    await _scheduleBackup();
    if (!_caughtUp) {
      _caughtUp = true;
      // Launch catch-up (iOS may never grant background time).
      await BackgroundJobs(_ref.read).run(maintenance: false);
    }
  }

  Future<void> _scheduleMaintenance() => Workmanager().registerPeriodicTask(
    BackgroundTasks.maintenanceTask,
    BackgroundTasks.maintenanceTask,
    frequency: const Duration(hours: 12),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: true,
    ),
  );

  Future<void> _scheduleBackup() async {
    final s = _ref.read(settingsProvider);
    final account = _ref.read(cloudAccountProvider);
    final prefs = _ref.read(sharedPreferencesProvider);
    final drive = s.autoBackupDrive && (account?.hasDrive ?? false);
    final local = s.localBackupFrequency != LocalBackupFrequency.off;
    if (!drive && !local) {
      await Workmanager().cancelByUniqueName(BackgroundTasks.backupTask);
      await prefs.remove(_signatureKey);
      return;
    }
    final delay = BackupSchedule.delayUntilNext(
      _ref.read(clockProvider).now(),
      s.backupMinutes,
    );
    final constraints = Constraints(
      networkType: !drive
          ? NetworkType.notRequired
          : s.backupWifiOnly && Platform.isAndroid
          ? NetworkType.unmetered
          : NetworkType.connected,
    );
    if (Platform.isIOS) {
      await Workmanager().registerProcessingTask(
        BackgroundTasks.backupTask,
        BackgroundTasks.backupTask,
        initialDelay: delay,
        constraints: constraints,
      );
      return;
    }
    final signature = backupSignature(s, account);
    final changed = prefs.getString(_signatureKey) != signature;
    await Workmanager().registerPeriodicTask(
      BackgroundTasks.backupTask,
      BackgroundTasks.backupTask,
      frequency: const Duration(days: 1),
      initialDelay: delay,
      constraints: constraints,
      existingWorkPolicy: changed
          ? ExistingPeriodicWorkPolicy.replace
          : ExistingPeriodicWorkPolicy.keep,
    );
    await prefs.setString(_signatureKey, signature);
  }
}

/// The app's scheduler. Re-schedules itself when the backup settings or
/// the account change (Settings screens need not call it).
final backgroundTasksProvider = Provider<BackgroundTasks>((ref) {
  final tasks = WorkmanagerBackgroundTasks(ref);
  void reschedule() {
    if (!WorkmanagerBackgroundTasks.supported) return;
    unawaited(
      tasks.ensureScheduled().catchError(
        (Object e) => AppLogger.w('Reschedule failed (${e.runtimeType})'),
      ),
    );
  }

  ref.listen(
    settingsProvider.select((s) => backupSignature(s, null)),
    (_, _) => reschedule(),
  );
  ref.listen(
    cloudAccountProvider.select((a) => a?.hasDrive ?? false),
    (_, _) => reschedule(),
  );
  return tasks;
});
