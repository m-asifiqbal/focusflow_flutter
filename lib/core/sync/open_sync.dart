/// ============================================================
/// OPEN SYNC — a quiet Drive sync each time the app is opened
/// ============================================================
///
/// Opening FocusFlow — a cold start, or coming back after at least
/// [OpenSync.resumeAfter] in the background (app_startup.dart) — syncs
/// with Google Drive so edits from the user's other devices show up
/// without waiting for the nightly backup or tapping Sync. It runs only
/// when all of these hold:
/// * Settings › Backup & Sync › "Sync when app opens" is on;
/// * signed in with Google Drive and Drive is set up in this build;
/// * no sync is running and the last one is older than [OpenSync.minGap]
///   (a quick app switch doesn't sync again);
/// * the network allows it — "Wi-Fi only" covers every automatic sync.
///   Offline is a silent skip, not a "Sync paused" error.
/// The sync is never interactive (no Google consent sheet) and passes
/// `skipUnchanged`: when this device's newest Drive backup already holds
/// the current data, nothing is uploaded or pruned — only other devices'
/// newer backups are merged — so opening the app many times a day neither
/// re-uploads identical data nor pushes older restore points out of
/// "Keep last N". Failures land in syncStatusProvider like any sync.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/sync/background_jobs.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/network_info.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class OpenSync {
  OpenSync(this._read);

  final ProviderReader _read;

  /// A sync this recent (any kind) makes another one on open pointless.
  static const Duration minGap = Duration(minutes: 2);

  /// Back from the background after at least this long counts as opening
  /// the app again (shorter: copying a code from another app).
  static const Duration resumeAfter = Duration(minutes: 1);

  /// Pure timing rule: no successful sync yet, or the last one is at least
  /// [minGap] old.
  static bool isStale({required DateTime now, required DateTime? lastSync}) =>
      lastSync == null || now.difference(lastSync) >= minGap;

  /// Whether the open sync should run now (see the file header).
  Future<bool> isDue() async {
    final s = _read(settingsProvider);
    if (!s.syncOnOpen) return false;
    await _read(cloudAccountProvider.notifier).loaded;
    final account = _read(cloudAccountProvider);
    if (account == null || !account.hasDrive) return false;
    if (!_read(cloudAccountControllerProvider).googleAvailable) return false;
    final status = _read(syncStatusProvider);
    if (status.isBusy) return false;
    final now = _read(clockProvider).now();
    if (!isStale(now: now, lastSync: status.lastSyncAt)) return false;
    final net = _read(networkInfoProvider);
    return s.backupWifiOnly ? net.isOnWifi() : net.isOnline();
  }

  /// Syncs when [isDue]. Returns the outcome, or null when it didn't run
  /// or failed (the failure is in syncStatusProvider).
  Future<SyncOutcome?> runIfDue() async {
    if (!await isDue()) return null;
    return _read(
      syncStatusProvider.notifier,
    ).syncNow(isAuto: true, interactive: false, skipUnchanged: true);
  }
}

/// The app's open-sync runner (app_startup.dart calls it on launch and on
/// resume).
final openSyncProvider = Provider<OpenSync>((ref) => OpenSync(ref.read));
