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
///   Drive's appDataFolder FIRST (local data is untouched unless every
///   Drive file went), then erases locally and revokes the grant. Failures
///   are [AccountActionFailure]s that say exactly what happened ("Deleted
///   3 of 5 files… local data was not erased"); running it again resumes.
/// * Remove device — forgets it from the account's device list; its Drive
///   backups stay unless the user also chose to delete them.
/// Sign-out and erase also forget the Drive sync bookkeeping (merged
/// backups, last sync time).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/cloud_account_controller.dart';
import 'package:focusflow/core/sync/local_data_eraser.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/features/auth/presentation/providers/account_providers.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

enum AccountAction { signOut, erase, deleteAccount, removeDevice, photo }

/// A danger-zone action stopped part-way; [message] says exactly what
/// was and wasn't done (shown verbatim).
class AccountActionFailure implements Exception {
  const AccountActionFailure(this.message);

  final String message;

  @override
  String toString() => 'AccountActionFailure: $message';
}

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

  /// Unlinks another device from the Drive device list. Its backups stay
  /// in Drive (restorable) unless [deleteBackups].
  Future<void> removeDevice(String deviceId, {bool deleteBackups = false}) =>
      _run(AccountAction.removeDevice, () async {
        await ref
            .read(driveSyncProvider)
            .removeDevice(deviceId, deleteBackups: deleteBackups);
        ref.invalidate(linkedDevicesProvider);
      });

  Future<void> eraseLocalData() =>
      _run(AccountAction.erase, () => _eraseEverything(revoke: false));

  /// Throws [AccountActionFailure] with exactly what happened when it
  /// stops part-way; local data is only erased once Drive is empty.
  Future<void> deleteAccountAndDriveData() =>
      _run(AccountAction.deleteAccount, () async {
        final account = ref.read(cloudAccountProvider);
        var driveFiles = 0;
        if (account?.hasDrive ?? false) {
          try {
            driveFiles = await ref.read(driveSyncProvider).deleteAllCloudData();
          } on CloudDeleteIncomplete catch (e) {
            throw AccountActionFailure(
              tr(
                'Deleted {deleted} of {total} files from Google Drive; '
                '{remaining} could not be deleted. Your local data was not '
                'erased. Try again to finish.',
                {
                  'deleted': e.deleted,
                  'total': e.total,
                  'remaining': e.remaining,
                },
              ),
            );
          } on Object {
            throw AccountActionFailure(
              tr(
                "Couldn't reach Google Drive — nothing was deleted and your "
                'local data was not erased. Try again when online.',
              ),
            );
          }
        }
        try {
          await _eraseEverything(revoke: true);
        } on Object {
          throw AccountActionFailure(
            tr(
              '{count, plural, one {# file was} other {# files were}} '
              'deleted from Google Drive, but erasing this device did not '
              'finish. Try again to finish.',
              {'count': driveFiles},
            ),
          );
        }
      });

  Future<void> _eraseEverything({required bool revoke}) async {
    try {
      await ref.read(vaultSessionProvider.notifier).wipe();
    } on Object catch (e) {
      debugPrint('Vault wipe during erase failed: ${e.runtimeType}');
    }
    await ref.read(localDataEraserProvider).eraseAll();
    await forgetSyncState(ref);
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
