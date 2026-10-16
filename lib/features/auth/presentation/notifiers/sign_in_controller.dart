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
///   appDataFolder for backups ("Backup found" sheet).
/// * Apple → profile only (no Drive).
/// * Offline → optional display name, accountMode = offline.
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
        if (restoreIntent) return const SignInRestore();
        final newest = await _newestDriveBackup();
        return newest == null ? const SignInDone() : SignInBackupFound(newest);
      });

  /// Continue with Apple (profile only).
  Future<SignInOutcome> apple() => _run(SignInMethod.apple, () async {
    final account = await _cloud.signInWithApple();
    if (account == null) return const SignInCancelled();
    await _markSeen();
    return const SignInDone(appleNoDrive: true);
  });

  /// Use offline with an optional display name.
  Future<SignInOutcome> offline({String? name}) =>
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
        return const SignInDone();
      });

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

  /// Newest backup in Drive, or null (none / Drive unreachable — the
  /// sign-in itself succeeded, so failures here stay quiet).
  Future<DriveBackupFile?> _newestDriveBackup() async {
    try {
      final backups = await ref.read(driveSyncProvider).listBackups();
      if (backups.isEmpty) return null;
      return backups.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
    } on Object catch (e) {
      debugPrint('Drive backup check skipped: ${e.runtimeType}');
      return null;
    }
  }
}

final signInControllerProvider =
    NotifierProvider.autoDispose<SignInController, SignInMethod?>(
      SignInController.new,
    );
