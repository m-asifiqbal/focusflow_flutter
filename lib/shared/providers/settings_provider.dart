/// ============================================================
/// SETTINGS PROVIDER — read: ref.watch(settingsProvider)
///                     write: ref.read(settingsProvider.notifier).update(...)
/// ============================================================
///
/// Synchronous (prefs are preloaded in main), persisted as one JSON blob.
/// ```dart
/// ref.read(settingsProvider.notifier).update((s) => s.copyWith(accent: AccentColor.blue));
/// ```
/// ============================================================
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

class SettingsController extends Notifier<AppSettings> {
  static const String prefsKey = 'app_settings_v1';

  @override
  AppSettings build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(prefsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } catch (e) {
      AppLogger.w('Settings blob unreadable, using defaults: $e');
      return const AppSettings();
    }
  }

  /// Applies [change] and persists the result.
  Future<void> update(AppSettings Function(AppSettings s) change) async {
    final next = change(state);
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setString(prefsKey, jsonEncode(next.toJson()));
  }

  /// Records a search term (dedup, newest first, max 10).
  ///
  /// Deprecated: recent searches are moving to the search feature's own
  /// (secure-storage) store — see `features/search`. Kept working until
  /// that migration lands; don't add new callers.
  Future<void> addRecentSearch(String term) {
    final t = term.trim();
    if (t.isEmpty) return Future.value();
    return update((s) {
      final list = [t, ...s.recentSearches.where((x) => x != t)];
      return s.copyWith(recentSearches: list.take(10).toList());
    });
  }

  /// Deprecated with [addRecentSearch] (search feature's store).
  Future<void> clearRecentSearches() =>
      update((s) => s.copyWith(recentSearches: const []));

  /// Settings › General › "Reset settings": restores the default
  /// *preferences* (general, appearance, notifications, module defaults,
  /// home & library layout, gestures, sounds).
  ///
  /// Deliberately untouched — each needs its own consent or would surprise:
  /// onboarding/account state; Security & privacy (App lock needs the
  /// device owner, Vault security needs the vault PIN — a reset must not
  /// weaken either); Backup & sync (re-enabling Drive upload would be a
  /// privacy surprise; keep count / schedule are data-retention choices);
  /// data references (default task list, last sync, time zone, history).
  Future<void> resetToDefaults() => update(
    (s) => const AppSettings().copyWith(
      onboardingSeen: s.onboardingSeen,
      accountMode: s.accountMode,
      displayName: s.displayName,
      dailyFocusGoal: s.dailyFocusGoal,
      timeZone: () => s.timeZone,
      tasksDefaultListId: () => s.tasksDefaultListId,
      // Security & privacy.
      appLockEnabled: s.appLockEnabled,
      hideInAppSwitcher: s.hideInAppSwitcher,
      clipboardClearSeconds: s.clipboardClearSeconds,
      vaultBiometrics: s.vaultBiometrics,
      vaultAutoLockMinutes: s.vaultAutoLockMinutes,
      vaultLockOnBackground: s.vaultLockOnBackground,
      vaultBlockScreenshots: s.vaultBlockScreenshots,
      vaultReauthToReveal: s.vaultReauthToReveal,
      breachMonitoring: s.breachMonitoring,
      wipeAfterFailedAttempts: s.wipeAfterFailedAttempts,
      // Backup & sync.
      autoBackupDrive: s.autoBackupDrive,
      backupFrequency: s.backupFrequency,
      backupMinutes: s.backupMinutes,
      backupWifiOnly: s.backupWifiOnly,
      encryptBackups: s.encryptBackups,
      keepBackups: s.keepBackups,
      localBackupFrequency: s.localBackupFrequency,
      lastSyncAt: () => s.lastSyncAt,
      recentSearches: s.recentSearches,
    ),
  );
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
