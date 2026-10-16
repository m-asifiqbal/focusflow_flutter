/// ============================================================
/// CLOUD ACCOUNT — cross-feature contract (implemented in core/sync)
/// ============================================================
///
/// The signed-in Google (Drive) or Apple profile, if any. Read by Settings'
/// account card (30), Account & profile (36), Home's avatar (03) and the
/// Backup & Sync screen (34). Google is the only provider with Drive backup.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/sync/cloud_account_controller.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/sync_controller.dart';

enum CloudProvider { google, apple }

@immutable
class CloudAccount {
  const CloudAccount({
    required this.provider,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final CloudProvider provider;
  final String email;
  final String? displayName;
  final String? photoUrl;

  bool get hasDrive => provider == CloudProvider.google;
}

/// Sync engine status shown on Settings (30) / Backup (34) / Home.
enum SyncPhase { idle, preparing, uploading, downloading, merging, done, error }

@immutable
class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.progress,
    this.lastSyncAt,
    this.message,
    this.conflictsResolved = 0,
    this.failure,
    this.warnings = const [],
    this.needsBackupPin = false,
  });

  final SyncPhase phase;

  /// 0..1 while uploading/downloading.
  final double? progress;
  final DateTime? lastSyncAt;
  final String? message;

  /// "3 items updated from another device".
  final int conflictsResolved;

  /// Why the last sync failed (with [SyncPhase.error]); `authExpired` /
  /// `notSignedIn` mean "sign in again".
  final DriveFailureKind? failure;

  /// Steps a finished sync skipped without failing ("Couldn't read the
  /// backup from Pixel 8", "Update FocusFlow to read …").
  final List<String> warnings;

  /// The sync stopped because "Encrypt backups" is on and no backup PIN
  /// is set (nothing was uploaded unencrypted).
  final bool needsBackupPin;

  bool get isBusy =>
      phase != SyncPhase.idle &&
      phase != SyncPhase.done &&
      phase != SyncPhase.error;
}

/// Sign-in / sign-out actions (screens 02, 30, 34, 36). Implemented by
/// features/backup; UI only calls these.
abstract class CloudAccountController {
  /// Whether Google Drive is configured in this build (OAuth client ids
  /// passed with --dart-define). False → "not set up in this build".
  bool get googleAvailable;

  /// Whether Sign in with Apple is offered on this platform (iOS).
  bool get appleAvailable;

  /// Interactive Google sign-in with the `drive.appdata` scope. Returns the
  /// account, or null when the user cancelled. Throws on real errors.
  Future<CloudAccount?> signInWithGoogle();

  /// Sign in with Apple (profile only — no Drive). Null when cancelled.
  Future<CloudAccount?> signInWithApple();

  /// Forgets the account (local data stays). [revoke] also removes the
  /// app's Drive grant ("Delete account & Drive data").
  Future<void> signOut({bool revoke = false});
}

/// The current account (null = offline / signed out). Loaded from the
/// keychain profile ([AccountStore]); set by [CloudAccountController].
final cloudAccountProvider =
    NotifierProvider<CloudAccountNotifier, CloudAccount?>(
      CloudAccountNotifier.new,
    );

/// Sign-in / sign-out (google_sign_in 7 + Sign in with Apple).
final cloudAccountControllerProvider = Provider<CloudAccountController>(
  GoogleCloudAccountController.new,
);

/// Live sync status; `ref.read(syncStatusProvider.notifier).syncNow()`
/// runs "Sync now" (see SyncController).
final syncStatusProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);
