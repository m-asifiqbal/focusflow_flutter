/// ============================================================
/// VAULT BACKUP BRIDGE — the vault side of backup / restore / import
/// ============================================================
///
/// Implements core/sync's [VaultBackupBridge] over the vault session:
/// * the backup envelope is the PIN-wrapped key bundle + its stable key
///   id (never a plain key — useless without the PIN);
/// * a restore is accepted when the backup's key id matches this device's
///   vault, or when there is no vault yet (the bundle is then adopted so
///   the old PIN opens the restored items), or when this device's vault is
///   still empty (common: a PIN was created on the new phone before
///   restoring) — its key is then replaced by the backup's, the session
///   locks and the backup's PIN opens the vault. A vault with items of its
///   own is never replaced (the restore reports the rows as skipped);
/// * imported logins are sealed one by one with the open session key via
///   [VaultItemService] (strength, reuse fingerprint, 2FA flag) and filed
///   into vault folders by name.
/// Plaintext from imports lives only in memory; nothing here logs.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/crypto_bytes.dart';
import 'package:focusflow/core/crypto/vault_key_manager.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_item_service.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_item_providers.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

class VaultSessionBackupBridge implements VaultBackupBridge {
  VaultSessionBackupBridge(this._ref);

  final Ref _ref;

  /// Envelope format version.
  static const int envelopeVersion = 1;

  VaultKeyManager get _keys => _ref.read(vaultKeyManagerProvider);

  /// The id a bundle is known by (bundles from before key ids existed fall
  /// back to their KDF salt, stable until the PIN changes).
  static String idOf(VaultKeyBundle b) =>
      b.keyId ?? 'salt:${CryptoBytes.toBase64(b.salt)}';

  @override
  Future<bool> hasVault() => _keys.isSetUp();

  @override
  Future<Map<String, Object?>?> exportKeyEnvelope() async {
    final bundle = await _keys.exportBundle();
    if (bundle == null) return null;
    return {
      'v': envelopeVersion,
      'keyId': idOf(bundle),
      'bundle': bundle.encode(),
    };
  }

  @override
  Future<bool> acceptKeyEnvelope(Map<String, Object?>? envelope) async {
    // A backup without vault rows never conflicts.
    if (envelope == null) return true;
    final VaultKeyBundle incoming;
    try {
      incoming = VaultKeyBundle.decode(envelope['bundle']! as String);
    } on Object {
      return false;
    }
    final local = await _keys.exportBundle();
    if (local != null) {
      if (idOf(local) == idOf(incoming)) return true;
      final vault = _ref.read(vaultRepositoryProvider);
      if ((await vault.allItemIds()).isNotEmpty) return false;
      // Nothing to lose locally: use the backup's vault. Generator history
      // was sealed with the old key and would be unreadable.
      final session = _ref.read(vaultSessionProvider.notifier);
      await session.lock();
      await _keys.replaceEmptyVaultKey(incoming);
      await vault.clearGeneratorHistory();
      await session.refresh();
      return true;
    }
    final adopted = await _keys.adoptBundle(incoming);
    if (adopted) await _ref.read(vaultSessionProvider.notifier).refresh();
    return adopted;
  }

  @override
  Future<bool> verifyPin(String pin) async =>
      await _ref.read(vaultSessionProvider.notifier).verifyPin(pin) ==
      UnlockResult.success;

  @override
  Future<int> importLogins(List<ImportedLogin> logins) async {
    final session = _ref.read(vaultSessionProvider);
    if (!session.isUnlocked) {
      throw VaultUnavailable(
        await hasVault()
            ? 'Unlock the vault to import passwords.'
            : 'Password import needs the vault — set up your vault first.',
      );
    }
    final key = session.requireKey();
    final service = _ref.read(vaultItemServiceProvider);
    final folders = _ref.read(foldersRepositoryProvider);
    final existing = await folders.watchFolders(ItemType.vault).first;
    final folderIds = {for (final f in existing) f.name.toLowerCase(): f.id};
    var saved = 0;
    for (final login in logins) {
      if (key.isDestroyed) throw const VaultUnavailable('The vault locked.');
      final folderName = login.folder?.trim() ?? '';
      String? folderId;
      if (folderName.isNotEmpty) {
        folderId = folderIds[folderName.toLowerCase()] ??= await folders.create(
          ItemType.vault,
          folderName,
        );
      }
      final totp = login.totpSecret?.trim();
      await service.save(
        key: key,
        draft: VaultItemDraft(
          type: VaultItemType.login,
          title: titleFor(login),
          folderId: folderId,
          isFavorite: login.isFavorite,
        ),
        payload: VaultPayload(
          username: login.username,
          password: login.password,
          url: login.url,
          notes: login.notes,
          totpSecret: totp == null || totp.isEmpty ? null : totp,
        ),
      );
      saved++;
    }
    _ref.read(vaultSessionProvider.notifier).touch();
    return saved;
  }

  /// The login's title, else its website's host, else "Imported login".
  static String titleFor(ImportedLogin l) {
    if (l.title.trim().isNotEmpty) return l.title.trim();
    final url = l.url.trim();
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
      final host = uri?.host.replaceFirst(RegExp(r'^www\.'), '') ?? '';
      if (host.isNotEmpty) return host;
    }
    return 'Imported login';
  }
}
