/// ============================================================
/// VAULT BRIDGE — what backup / import need from the vault feature
/// ============================================================
///
/// Backups carry vault items as ciphertext only. To make them usable on
/// another device the backup also carries the vault's *wrapped* data key
/// (the "envelope": DEK encrypted under the PIN-derived KEK + KDF salt and
/// a key id) — never a plain key. Importing passwords (Bitwarden /
/// 1Password CSV) must encrypt each entry with the unlocked vault session.
///
/// The vault feature (core/crypto + vault session) implements this
/// interface and overrides [vaultBridgeProvider]; until then the default
/// reports "no vault" and refuses password imports, so nothing is ever
/// stored unencrypted.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/vault/presentation/vault_backup_bridge.dart';

/// A login parsed from a password-manager export (plaintext, in memory
/// only — handed straight to [VaultBackupBridge.importLogins]).
class ImportedLogin {
  const ImportedLogin({
    required this.title,
    this.username = '',
    this.password = '',
    this.url = '',
    this.notes = '',
    this.totpSecret,
    this.folder,
    this.isFavorite = false,
  });

  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final String? totpSecret;
  final String? folder;
  final bool isFavorite;
}

/// Thrown by [VaultBackupBridge.importLogins] when no vault session exists.
class VaultUnavailable implements Exception {
  const VaultUnavailable([this.message = 'The vault is not available']);

  final String message;

  @override
  String toString() => 'VaultUnavailable: $message';
}

abstract interface class VaultBackupBridge {
  /// Whether a vault (master PIN) has been set up on this device.
  Future<bool> hasVault();

  /// The wrapped vault key + id to embed in backups; null without a vault.
  /// Must contain a stable `keyId` entry identifying the data key.
  Future<Map<String, Object?>?> exportKeyEnvelope();

  /// Called before a restore with the backup's envelope. Returns true when
  /// the backup's vault rows can be used on this device: same key id as
  /// the local vault, or no local vault yet (the envelope is then adopted so
  /// the old PIN unlocks the restored items).
  Future<bool> acceptKeyEnvelope(Map<String, Object?>? envelope);

  /// Checks the master PIN (destructive account actions).
  Future<bool> verifyPin(String pin);

  /// Encrypts and stores [logins] in the vault. The caller has already
  /// called `ensureVaultUnlocked`. Returns how many were saved. Throws
  /// [VaultUnavailable] when the vault is locked / not set up.
  Future<int> importLogins(List<ImportedLogin> logins);
}

/// Default until the vault feature overrides it: no vault, no imports.
class NoVaultBackupBridge implements VaultBackupBridge {
  const NoVaultBackupBridge();

  @override
  Future<bool> hasVault() async => false;

  @override
  Future<Map<String, Object?>?> exportKeyEnvelope() async => null;

  @override
  Future<bool> acceptKeyEnvelope(Map<String, Object?>? envelope) async =>
      envelope == null;

  @override
  Future<bool> verifyPin(String pin) async => false;

  @override
  Future<int> importLogins(List<ImportedLogin> logins) async =>
      throw const VaultUnavailable(
        'Password import needs the vault — set up your vault first.',
      );
}

/// The vault session's bridge (features/vault). Tests may override it with
/// [NoVaultBackupBridge].
final vaultBridgeProvider = Provider<VaultBackupBridge>(
  VaultSessionBackupBridge.new,
);
