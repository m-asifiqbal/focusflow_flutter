/// ============================================================
/// BACKGROUND RUNNER — the workmanager isolate's entry point
/// ============================================================
///
/// Runs in a fresh background isolate (no UI, no bootstrap): it opens the
/// encrypted database with the key from the keychain (the same key
/// bootstrap uses — never created here: no key means the app has never
/// run, so there is nothing to back up), builds a ProviderContainer with
/// the usual overrides and runs [BackgroundJobs], then one notification
/// pass ([reconcileInBackground]: fired notifications → inbox, rolling
/// window refilled — iOS keeps only 64 requests and the app may not be
/// opened for weeks — and the running app pinged). The database is closed
/// before the OS is told the task finished. Nothing secret is logged.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/encrypted_database.dart';
import 'package:focusflow/core/notifications/engine/background_reconcile.dart';
import 'package:focusflow/core/notifications/engine/local_notifications_gateway.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/core/sync/background_jobs.dart';
import 'package:focusflow/core/sync/background_tasks.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Prefs key of the per-install device id (written by bootstrap.dart).
const String _deviceIdKey = 'device_id';

/// The notification step of a background task: initializes the plugin
/// for this isolate ([initialize]) and runs one reconcile pass. Never
/// throws — a failure here must not make the OS retry the backup.
Future<bool> runNotificationMaintenance(
  NotificationReader read,
  Future<void> Function() initialize,
) async {
  try {
    await initialize();
    await reconcileInBackground(read, rearm: true);
    return true;
  } catch (e, st) {
    AppLogger.e(
      'Background notification pass failed (${e.runtimeType})',
      stackTrace: st,
    );
    return false;
  }
}

/// Top-level callback handed to `Workmanager().initialize`.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, _) => runBackgroundTask(task));
}

/// Runs one scheduled task; true = done (also when there was nothing to
/// do), false = let the OS retry later.
Future<bool> runBackgroundTask(String task) async {
  AppDatabase? db;
  ProviderContainer? container;
  try {
    final prefs = await SharedPreferences.getInstance();
    final secure = SecureStore();
    final key = await secure.read(SecureStore.databaseKey);
    final deviceId = prefs.getString(_deviceIdKey);
    if (key == null || deviceId == null) return true;
    // quarantine: false — the app may hold the database right now and a
    // secondary opener must never move the user's live file.
    db = AppDatabase(EncryptedDatabase.open(cipherKey: key, quarantine: false));
    final gateway = LocalNotificationsGateway();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(secure),
        databaseKeyProvider.overrideWithValue(key),
        deviceIdProvider.overrideWithValue(deviceId),
        databaseProvider.overrideWithValue(db),
        notificationGatewayProvider.overrideWithValue(gateway),
      ],
    );
    final jobs = BackgroundJobs(container.read);
    await jobs.run(maintenance: true);
    await runNotificationMaintenance(
      container.read,
      gateway.initializeInBackground,
    );
    if (task == BackgroundTasks.backupTask) {
      // iOS processing tasks are one-shot: queue the next one.
      await container.read(backgroundTasksProvider).ensureScheduled();
    }
    return true;
  } catch (e, st) {
    AppLogger.e('Background task failed (${e.runtimeType})', stackTrace: st);
    return false;
  } finally {
    container?.dispose();
    await db?.close();
  }
}
