/// ============================================================
/// ACCOUNT ACTIONS — profile edits and the danger zone (screen 36)
/// ============================================================
///
/// State = the action in progress (null = idle), so the screen can show a
/// spinner on that row and block double taps.
///
/// * Sign out — forgets the account; local data stays.
/// * Erase local data — factory reset of this device: vault key material,
///   backup key, every item / file, settings (back to onboarding). Drive
///   backups are kept, so signing in again can restore them.
/// * Delete account & Drive data — deletes everything FocusFlow stored in
///   Drive's appDataFolder FIRST (fails without touching local data when
///   Drive is unreachable), then erases locally and revokes the grant.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/local_data_eraser.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/features/auth/presentation/providers/account_providers.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

enum AccountAction { signOut, erase, deleteAccount, removeDevice, photo }

class AccountActionsController extends AutoDisposeNotifier<AccountAction?> {
  @override
  AccountAction? build() => null;

  /// Whether a vault exists (the erase dialogs then also ask for its PIN).
  Future<bool> hasVault() async {
    try {
      return await ref.read(vaultBridgeProvider).hasVault();
    } on Object {
      return false;
    }
  }

  /// Checks the vault PIN without unlocking (counts towards back-off).
  Future<bool> verifyVaultPin(String pin) async {
    try {
      return await ref.read(vaultBridgeProvider).verifyPin(pin);
    } on Object {
      return false;
    }
  }

  Future<void> setDisplayName(String name) => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(displayName: name.trim()));

  Future<void> setDailyFocusGoal(int goal) => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(dailyFocusGoal: goal.clamp(1, 50)));

  /// [zone] null = follow the device.
  Future<void> setTimeZone(String? zone) => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(timeZone: () => zone));

  /// Saves (or with null bytes removes) the local profile picture.
  Future<void> setPhoto(Uint8List? bytes) =>
      _run(AccountAction.photo, () async {
        final files = ref.read(appFilesProvider);
        if (bytes == null) {
          await files.delete(profilePhotoPath);
        } else {
          await files.write(profilePhotoPath, bytes);
        }
        ref.invalidate(profilePhotoProvider);
      });

  Future<void> signOut() => _run(
    AccountAction.signOut,
    () => ref.read(cloudAccountControllerProvider).signOut(),
  );

  /// Unlinks another device from the Drive manifest.
  Future<void> removeDevice(String deviceId) =>
      _run(AccountAction.removeDevice, () async {
        await ref.read(driveSyncProvider).removeDevice(deviceId);
        ref.invalidate(linkedDevicesProvider);
      });

  Future<void> eraseLocalData() =>
      _run(AccountAction.erase, () => _eraseEverything(revoke: false));

  /// Throws (DriveFailure, …) before any local change if Drive fails.
  Future<void> deleteAccountAndDriveData() =>
      _run(AccountAction.deleteAccount, () async {
        final account = ref.read(cloudAccountProvider);
        if (account?.hasDrive ?? false) {
          await ref.read(driveSyncProvider).deleteAllCloudData();
        }
        await _eraseEverything(revoke: true);
      });

  Future<void> _eraseEverything({required bool revoke}) async {
    try {
      await ref.read(vaultSessionProvider.notifier).wipe();
    } on Object catch (e) {
      debugPrint('Vault wipe during erase failed: ${e.runtimeType}');
    }
    await ref.read(localDataEraserProvider).eraseAll();
    try {
      await ref.read(backupKeyStoreProvider).disable();
    } on Object {
      // No keychain entry — nothing to forget.
    }
    await ref.read(cloudAccountControllerProvider).signOut(revoke: revoke);
    await ref
        .read(settingsProvider.notifier)
        .update(
          (_) => const AppSettings().copyWith(
            onboardingSeen: false,
            accountMode: AccountMode.none,
          ),
        );
    try {
      await ref.read(notificationEngineProvider).onResume();
    } on Object {
      // Re-planned on next launch anyway.
    }
  }

  Future<void> _run(AccountAction action, Future<void> Function() body) async {
    if (state != null) return;
    state = action;
    // Erasing navigates away (onboarding); finish the job regardless.
    final link = ref.keepAlive();
    try {
      await body();
    } finally {
      link.close();
      try {
        state = null;
      } on Object {
        // Disposed while running.
      }
    }
  }
}

final accountActionsProvider =
    NotifierProvider.autoDispose<AccountActionsController, AccountAction?>(
      AccountActionsController.new,
    );
