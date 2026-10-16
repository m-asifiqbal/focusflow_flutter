/// ============================================================
/// SIGN IN CONTROLLER — Sign in / Welcome (screen 02)
/// ============================================================
///
/// State = the method whose button shows a spinner (null = idle); the
/// other buttons are disabled meanwhile. Each action returns a
/// [SignInOutcome] and the screen navigates / shows sheets from it, so the
/// controller stays free of BuildContext.
///
/// * Google → CloudAccountController.signInWithGoogle (drive.appdata), then
///   — unless the user came for a restore — a quiet look in Drive's
///   appDataFolder for backups ("Backup found" sheet). When backups from
///   another device exist (after a reinstall the user's own old ones count
///   as "another device"), automatic merging is held until the user picks
///   Restore or Start fresh ([startFresh] records the baseline).
/// * Apple → profile only (no Drive).
/// * Offline → optional display name, accountMode = offline.
/// * With `?intent=restore` every choice ends in the restore picker, and
///   [restoreFromFile] goes there without an account.
/// Every success also marks onboarding as seen. Cancelling is silent.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_backup_file.dart';
import 'package:focusflow/core/sync/google_account.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

enum SignInMethod { google, apple, offline }

/// What the screen should do after a sign-in attempt.
sealed class SignInOutcome {
  const SignInOutcome();
}

/// The user backed out of the provider's sheet — show nothing.
class SignInCancelled extends SignInOutcome {
  const SignInCancelled();
}

/// Signed in (or offline profile created) — continue into the app.
class SignInDone extends SignInOutcome {
  const SignInDone({this.appleNoDrive = false});

  /// Apple account: tell the user Drive backup needs Google later.
  final bool appleNoDrive;
}

/// Google sign-in found an existing backup in Drive.
class SignInBackupFound extends SignInOutcome {
  const SignInBackupFound(this.newest);

  final DriveBackupFile newest;
}

/// Google sign-in for "intent=restore": open the restore picker.
class SignInRestore extends SignInOutcome {
  const SignInRestore();
}

class SignInFailed extends SignInOutcome {
  const SignInFailed(this.message);

  final String message;
}

class SignInController extends AutoDisposeNotifier<SignInMethod?> {
  @override
  SignInMethod? build() => null;

  CloudAccountController get _cloud => ref.read(cloudAccountControllerProvider);

  bool get googleAvailable => _cloud.googleAvailable;
  bool get appleAvailable => _cloud.appleAvailable;

  /// Continue with Google. [restoreIntent] skips the "Backup found" check.
  Future<SignInOutcome> google({bool restoreIntent = false}) =>
      _run(SignInMethod.google, () async {
        final account = await _cloud.signInWithGoogle();
        if (account == null) return const SignInCancelled();
        await _markSeen();
        final backups = await _driveBackups();
        final deviceId = ref.read(deviceIdProvider);
        if (backups.any((b) => b.deviceId != deviceId)) {
          // Restore vs Start fresh is the user's call: merge nothing yet.
          await _holdMerging();
        }
        if (restoreIntent) return const SignInRestore();
        if (backups.isEmpty) return const SignInDone();
        return SignInBackupFound(
          backups.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b),
        );
      });

  /// Continue with Apple (profile only). [restoreIntent] → restore picker
  /// (local / file backups).
  Future<SignInOutcome> apple({bool restoreIntent = false}) =>
      _run(SignInMethod.apple, () async {
        final account = await _cloud.signInWithApple();
        if (account == null) return const SignInCancelled();
        await _markSeen();
        if (restoreIntent) return const SignInRestore();
        return const SignInDone(appleNoDrive: true);
      });

  /// Use offline with an optional display name. [restoreIntent] →
  /// restore picker (local / file backups).
  Future<SignInOutcome> offline({String? name, bool restoreIntent = false}) =>
      _run(SignInMethod.offline, () async {
        final trimmed = name?.trim() ?? '';
        await ref
            .read(settingsProvider.notifier)
            .update(
              (s) => s.copyWith(
                accountMode: AccountMode.offline,
                onboardingSeen: true,
                displayName: trimmed.isEmpty ? null : trimmed,
              ),
            );
        return restoreIntent ? const SignInRestore() : const SignInDone();
      });

  /// "Restore from a backup file" (sign-in with `?intent=restore`): no
  /// account needed — offline unless one is already set — then the
  /// restore picker ("Choose a backup file…").
  Future<SignInOutcome> restoreFromFile() =>
      _run(SignInMethod.offline, () async {
        await ref
            .read(settingsProvider.notifier)
            .update(
              (s) => s.copyWith(
                onboardingSeen: true,
                accountMode: s.accountMode == AccountMode.none
                    ? AccountMode.offline
                    : null,
              ),
            );
        return const SignInRestore();
      });

  /// "Start fresh" on the Backup found sheet: the Drive backups there now
  /// are not merged automatically (a manual Restore still offers them).
  /// False when Drive couldn't be reached — merging then stays on hold
  /// and Backup & Sync asks again.
  Future<bool> startFresh() async {
    try {
      await ref.read(driveSyncProvider).startFresh();
      return true;
    } on Object catch (e) {
      debugPrint('Start fresh not recorded: ${e.runtimeType}');
      return false;
    }
  }

  Future<void> _holdMerging() async {
    try {
      await ref.read(driveSyncProvider).holdMergeForDecision();
    } on Object {
      // Prefs unavailable: nothing to hold.
    }
  }

  Future<SignInOutcome> _run(
    SignInMethod method,
    Future<SignInOutcome> Function() body,
  ) async {
    if (state != null) return const SignInCancelled();
    state = method;
    final link = ref.keepAlive();
    try {
      return await body();
    } on CloudAuthException catch (e) {
      return SignInFailed(e.message);
    } on Object {
      return const SignInFailed(
        "Couldn't sign in. Check your connection and try again.",
      );
    } finally {
      link.close();
      // The screen may have been popped meanwhile (autoDispose).
      try {
        state = null;
      } on Object {
        // Disposed — nothing to reset.
      }
    }
  }

  Future<void> _markSeen() => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(onboardingSeen: true));

  /// Every backup in Drive (empty when none / Drive unreachable — the
  /// sign-in itself succeeded, so failures here stay quiet).
  Future<List<DriveBackupFile>> _driveBackups() async {
    try {
      return await ref.read(driveSyncProvider).listBackups();
    } on Object catch (e) {
      debugPrint('Drive backup check skipped: ${e.runtimeType}');
      return const [];
    }
  }
}

final signInControllerProvider =
    NotifierProvider.autoDispose<SignInController, SignInMethod?>(
      SignInController.new,
    );
