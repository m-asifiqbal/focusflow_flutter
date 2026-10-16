/// ============================================================
/// DRIVE STORE — the app's hidden Drive folder (appDataFolder), abstracted
/// ============================================================
///
/// [DriveStore] is all the sync engine needs from Google Drive: upload,
/// list, download and delete files in `appDataFolder` (scope
/// `drive.appdata` — invisible to the user's Drive and to other apps).
/// google_drive_store.dart implements it over googleapis; tests use an
/// in-memory fake. Failures are mapped to [DriveFailure] so the UI can say
/// "offline", "sign in again" or "Drive is full".
/// ============================================================
library;

import 'package:flutter/foundation.dart';

/// A file in appDataFolder.
@immutable
class DriveFile {
  const DriveFile({
    required this.id,
    required this.name,
    required this.createdAt,
    this.sizeBytes = 0,
    this.properties = const {},
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;

  /// Drive `appProperties` (small string metadata, see [DriveBackupFile]).
  final Map<String, String> properties;
}

/// Why a Drive call failed.
enum DriveFailureKind {
  /// No connection / DNS / socket error.
  offline,

  /// The access token was rejected and could not be refreshed silently.
  authExpired,

  /// Drive (or the account's storage) is full.
  quota,

  /// Not signed in with Google, or Drive not set up in this build.
  notSignedIn,

  /// Anything else (5xx, malformed response, …).
  unknown,
}

class DriveFailure implements Exception {
  const DriveFailure(this.kind, [this.detail]);

  final DriveFailureKind kind;

  /// Technical detail for logs (never shown verbatim, never a token).
  final String? detail;

  /// Sentence-case copy for the status box / snackbar.
  String get message => switch (kind) {
    DriveFailureKind.offline =>
      "You're offline. We'll back up when you're connected.",
    DriveFailureKind.authExpired =>
      'Your Google sign-in expired. Sign in again to keep syncing.',
    DriveFailureKind.quota =>
      'Your Google Drive is full. Free up space or keep fewer backups.',
    DriveFailureKind.notSignedIn => 'Connect Google Drive to sync.',
    DriveFailureKind.unknown => "Sync didn't finish. Try again in a moment.",
  };

  @override
  String toString() =>
      'DriveFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}

/// Files in the app's Drive folder. Every method throws [DriveFailure].
abstract interface class DriveStore {
  /// Every file in appDataFolder, newest first.
  Future<List<DriveFile>> list();

  /// Creates a file. [onProgress] gets 0..1 while bytes are sent.
  Future<DriveFile> upload(
    String name,
    Uint8List bytes, {
    Map<String, String> properties = const {},
    String mimeType = 'application/octet-stream',
    void Function(double progress)? onProgress,
  });

  /// Replaces the content of an existing file.
  Future<void> overwrite(String fileId, Uint8List bytes);

  Future<Uint8List> download(String fileId);

  /// Deleting a file that is already gone is not an error.
  Future<void> delete(String fileId);

  /// The account's total Drive storage in bytes ("of 15 GB"); null when
  /// unknown or unlimited.
  Future<int?> storageLimit();
}

/// Opens the account's [DriveStore]; null when not signed in with Google.
/// [interactive] lets google_sign_in show its consent UI if needed.
typedef DriveStoreFactory = Future<DriveStore?> Function({bool interactive});
