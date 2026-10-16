/// ============================================================
/// VAULT REPOSITORY (contract) — ciphertext only
/// ============================================================
///
/// Stores and streams [VaultItemRecord]s; never sees plaintext secrets.
/// Encryption / decryption, strength scoring and HIBP checks belong to the
/// vault feature's services, which call [save], [addHistory] and
/// [updateBreachResult] with already-encrypted bytes / derived metadata.
/// Lifecycle (archive, trash, delete forever incl. history) lives in
/// ItemsRepository.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';

enum VaultSort { az, recent }

@immutable
class VaultQuery {
  const VaultQuery({
    this.type,
    this.folderId,
    this.favouritesOnly = false,
    this.text = '',
    this.sort = VaultSort.az,
  });

  final VaultItemType? type;
  final String? folderId;
  final bool favouritesOnly;

  /// Case-insensitive *title* substring filter (secrets are never
  /// searchable). The vault list additionally matches the decrypted
  /// subtitle (username / SSID) in the presentation layer.
  final String text;
  final VaultSort sort;

  @override
  bool operator ==(Object other) =>
      other is VaultQuery &&
      other.type == type &&
      other.folderId == folderId &&
      other.favouritesOnly == favouritesOnly &&
      other.text == text &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(type, folderId, favouritesOnly, text, sort);
}

abstract interface class VaultRepository {
  /// Active items, pinned first, then A–Z (or most recent).
  Stream<List<VaultItemRecord>> watchItems(VaultQuery query);

  /// One item in any lifecycle state (null when gone).
  Stream<VaultItemRecord?> watchItem(String id);
  Future<VaultItemRecord?> getItem(String id);

  /// Every active item (security report input).
  Future<List<VaultItemRecord>> getAll();

  /// Creates ([VaultItemRecord.isNew]) or updates an item (+ tags by
  /// name). Returns the id.
  Future<String> save(VaultItemRecord record);

  /// Stores a previous password (encrypted) of [itemId].
  Future<void> addHistory(String itemId, Uint8List encryptedPassword);

  /// Previous passwords, newest first.
  Stream<List<VaultHistoryEntry>> watchHistory(String itemId);

  Stream<VaultCounts> watchCounts();

  /// Caches an HIBP result for [id]. Must NOT touch `updatedAt` (a check
  /// is not an edit and must not reorder "Recent"); only the sync
  /// bookkeeping (`syncVersion`, `deviceId`) moves.
  Future<void> updateBreachResult(String id, int count, DateTime checkedAt);

  /// Ids of every vault item in any lifecycle state (vault wipe).
  Future<List<String>> allItemIds();

  /// Runs [delete] (a hard delete of the vault items [ids]) and drops the
  /// sync tombstones it left, in one transaction. Used by the failed-PIN
  /// wipe: erasing the vault on a lost phone must stay on that phone and
  /// never propagate to the Drive backup or other devices.
  Future<void> deleteLocallyOnly(
    List<String> ids,
    Future<void> Function() delete,
  );

  /// Adds a generator result and keeps only the newest 10.
  Future<void> addGeneratorEntry(
    Uint8List encryptedValue, {
    String mode = 'password',
    int entropyBits = 0,
  });

  /// Generator history, newest first (max 10).
  Stream<List<GeneratedSecret>> watchGeneratorHistory();
  Future<void> clearGeneratorHistory();
}
