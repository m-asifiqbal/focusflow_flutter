/// ============================================================
/// BACKUP KEY POLICY — which key (if any) seals the next backup
/// ============================================================
///
/// One rule for Drive sync, local backups and `.ffbackup` exports:
/// * "Encrypt backups" off → plaintext (and labelled so).
/// * on + a stored backup key → encrypted with it.
/// * on + no key yet → [BackupPinRequired]: never silently fall back to
///   plaintext. The UI asks for a backup PIN or for an explicit "Back up
///   without encryption" (which turns the setting off).
/// * the keychain could not be read, or the stored entry is damaged →
///   [BackupKeyUnavailable]: the backup fails with an error instead of
///   being downgraded to plaintext.
///
/// [BackupKeyStore.current] answers null both for "no key" and for
/// "keychain error", so the policy reads the raw keychain entry first to
/// tell the two apart (BackupKeyStore itself is owned by the vault work).
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';

/// "Encrypt backups" is on but no backup PIN has been set on this device.
class BackupPinRequired implements Exception {
  const BackupPinRequired();

  String get message => tr(
    'Set a backup PIN to encrypt your backups, or choose to back up '
    'without encryption.',
  );

  @override
  String toString() => 'BackupPinRequired';
}

/// The backup key could not be read from the keychain (or is damaged).
class BackupKeyUnavailable implements Exception {
  const BackupKeyUnavailable([this.detail]);

  /// Technical detail for logs (never a key).
  final String? detail;

  String get message => tr(
    "Couldn't read your backup key from this device's keychain, so "
    'nothing was backed up. Try again, or set your backup PIN again.',
  );

  @override
  String toString() =>
      'BackupKeyUnavailable${detail == null ? '' : ' ($detail)'}';
}

/// What the keychain holds for "Encrypt backups".
enum BackupKeyState {
  /// A usable backup key is stored.
  present,

  /// No backup PIN was ever set (or it was turned off).
  absent,

  /// The keychain failed or the stored entry is damaged.
  unreadable,
}

class BackupKeyPolicy {
  BackupKeyPolicy({required this.keys, required this.secure});

  final BackupKeyStore keys;
  final SecureStore secure;

  /// Reads the keychain. Never throws.
  Future<BackupKeyState> state() async {
    final (state, _) = await _read();
    return state;
  }

  Future<(BackupKeyState, BackupKey?)> _read() async {
    final String? raw;
    try {
      raw = await secure.read(BackupKeyStore.storageKey);
    } on Object {
      return (BackupKeyState.unreadable, null);
    }
    if (raw == null) return (BackupKeyState.absent, null);
    final key = await keys.current();
    if (key == null) return (BackupKeyState.unreadable, null);
    return (BackupKeyState.present, key);
  }

  /// The key that seals a backup when "Encrypt backups" is [encrypt].
  /// Throws [BackupPinRequired] / [BackupKeyUnavailable] (see header).
  Future<BackupKey?> forBackup({required bool encrypt}) async {
    if (!encrypt) return null;
    final (state, key) = await _read();
    return switch (state) {
      BackupKeyState.present => key,
      BackupKeyState.absent => throw const BackupPinRequired(),
      BackupKeyState.unreadable => throw const BackupKeyUnavailable(),
    };
  }

  /// The stored key when there is one, null when none was set; throws
  /// [BackupKeyUnavailable] when the keychain failed (exports encrypt
  /// whenever a key exists, whatever the setting).
  Future<BackupKey?> storedKey() async {
    final (state, key) = await _read();
    if (state == BackupKeyState.unreadable) {
      throw const BackupKeyUnavailable();
    }
    return key;
  }
}
