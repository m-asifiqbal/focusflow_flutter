/// ============================================================
/// VAULT PAYLOAD CODEC — VaultPayload ⇄ AES-256-GCM blob
/// ============================================================
///
/// The only place that turns a [VaultPayload] into the ciphertext stored in
/// `VaultItemRecord.encryptedPayload` and back. Uses the vault data key and
/// an item AAD bound to the row id ([VaultAad.itemFor]), so a blob from
/// another table (history, generator), another vault OR another vault row
/// cannot be swapped in. Blobs written before the id binding (legacy
/// [VaultAad.item]) still open via a fallback and are re-sealed with the
/// id-bound AAD the next time the item is saved. Pure Dart; no logging.
/// ============================================================
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:focusflow/core/crypto/vault_cipher.dart';
import 'package:focusflow/core/crypto/vault_key.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';

abstract final class VaultPayloadCodec {
  /// Encrypts [payload] under [key], bound to [itemId] (null = the legacy,
  /// unbound label — only for tests / fixtures of old data).
  static Future<Uint8List> seal(
    VaultKey key,
    VaultPayload payload, {
    String? itemId,
  }) => VaultCipher.sealString(
    key.secretKey,
    jsonEncode(payload.toJson()),
    aad: itemId == null ? VaultAad.item : VaultAad.itemFor(itemId),
  );

  /// Decrypts a blob made by [seal]. With [itemId] the id-bound AAD is
  /// tried first, then the legacy one. Throws VaultCryptoException when the
  /// blob was tampered with or sealed by another key / for another item.
  /// An empty blob (item without secrets) decodes to [VaultPayload.empty].
  static Future<VaultPayload> open(
    VaultKey key,
    Uint8List blob, {
    String? itemId,
  }) async {
    if (blob.isEmpty) return VaultPayload.empty;
    String json;
    if (itemId != null && itemId.isNotEmpty) {
      try {
        json = await VaultCipher.openString(
          key.secretKey,
          blob,
          aad: VaultAad.itemFor(itemId),
        );
      } on VaultCryptoException {
        json = await VaultCipher.openString(
          key.secretKey,
          blob,
          aad: VaultAad.item,
        );
      }
    } else {
      json = await VaultCipher.openString(
        key.secretKey,
        blob,
        aad: VaultAad.item,
      );
    }
    final decoded = jsonDecode(json);
    return decoded is Map
        ? VaultPayload.fromJson(decoded.cast<String, Object?>())
        : VaultPayload.empty;
  }
}
