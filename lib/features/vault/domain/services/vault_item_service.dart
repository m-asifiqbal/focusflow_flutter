/// ============================================================
/// VAULT ITEM SERVICE — the one way a decrypted item is written back
/// ============================================================
///
/// Editor saves (screen 20) and password imports (backup bridge) both go
/// through [VaultItemService.save]: it seals the payload with the open
/// vault key, recomputes the cached plaintext metadata (strength score,
/// HMAC fingerprint for reuse detection, "has 2FA"), and when the password
/// changed pushes the previous one — encrypted under the history AAD — to
/// `vault_history` and resets the breach cache. Plaintext never leaves
/// memory; nothing here logs. Pure Dart (no Flutter, no Drift).
/// ============================================================
library;

import 'dart:typed_data';

import 'package:focusflow/core/crypto/password_strength.dart';
import 'package:focusflow/core/crypto/totp.dart';
import 'package:focusflow/core/crypto/vault_cipher.dart';
import 'package:focusflow/core/crypto/vault_key.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/repository/vault_repository.dart';
import 'package:focusflow/features/vault/domain/services/vault_payload_codec.dart';
import 'package:uuid/uuid.dart';

/// The organisation fields the editor owns (everything that is not secret).
class VaultItemDraft {
  const VaultItemDraft({
    required this.type,
    required this.title,
    this.iconKey,
    this.colorHex,
    this.folderId,
    this.tagNames = const [],
    this.isFavorite = false,
    this.expiryDays,
  });

  final VaultItemType type;
  final String title;
  final String? iconKey;
  final String? colorHex;
  final String? folderId;
  final List<String> tagNames;
  final bool isFavorite;

  /// Password expiry reminder in days (null = off).
  final int? expiryDays;
}

class VaultItemService {
  /// [_now] is the injectable clock (`clock.now`); [newId] makes the id of
  /// a new item (uuid v4 by default) — it is needed BEFORE the row exists
  /// because the payload's AAD is bound to it.
  const VaultItemService(this._repo, this._now, {String Function()? newId})
    : _newId = newId; // ignore: prefer_initializing_formals

  final VaultRepository _repo;
  final DateTime Function() _now;
  final String Function()? _newId;

  /// Encrypts and stores one item; returns its id. [existing] is the stored
  /// record being edited (null = create) and [previous] its decrypted
  /// payload (for password history).
  Future<String> save({
    required VaultKey key,
    required VaultItemDraft draft,
    required VaultPayload payload,
    VaultItemRecord? existing,
    VaultPayload? previous,
  }) async {
    final now = _now();
    final clean = _forType(draft.type, payload);
    final password = clean.password;
    final hasPassword = password.isNotEmpty;
    final changed = existing == null || (previous?.password ?? '') != password;
    final totp = clean.totpSecret;
    // Always (re-)sealed with the id-bound AAD: this is also what upgrades
    // legacy blobs (VaultPayloadCodec) on the next save.
    final existingId = existing?.id ?? '';
    final id0 = existingId.isNotEmpty
        ? existingId
        : (_newId?.call() ?? const Uuid().v4());
    final record = VaultItemRecord(
      id: id0,
      type: draft.type,
      title: draft.title.trim(),
      iconKey: draft.iconKey,
      colorHex: draft.colorHex,
      folderId: draft.folderId,
      tags: [
        for (final n in draft.tagNames)
          if (n.trim().isNotEmpty) Tag(id: '', name: n.trim()),
      ],
      encryptedPayload: await VaultPayloadCodec.seal(key, clean, itemId: id0),
      passwordStrength: hasPassword
          ? PasswordStrengthEstimator.estimate(password).score
          : null,
      passwordUpdatedAt: hasPassword
          ? (changed ? now : existing.passwordUpdatedAt ?? now)
          : null,
      passwordFingerprint: hasPassword ? key.fingerprint(password) : null,
      breachCount: changed ? null : existing.breachCount,
      breachCheckedAt: changed ? null : existing.breachCheckedAt,
      hasTotp: totp != null && TotpConfig.parse(totp) != null,
      expiryDays: hasPassword ? draft.expiryDays : null,
      isFavorite: draft.isFavorite,
      isPinned: existing?.isPinned ?? false,
      sortOrder: existing?.sortOrder ?? 0,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      archivedAt: existing?.archivedAt,
      deletedAt: existing?.deletedAt,
    );
    final id = await _repo.save(record);
    final old = previous?.password ?? '';
    if (existing != null && changed && old.isNotEmpty) {
      await _repo.addHistory(id, await sealHistory(key, old));
    }
    return id;
  }

  /// Seals one previous password for `vault_history`.
  static Future<Uint8List> sealHistory(VaultKey key, String password) =>
      VaultCipher.sealString(key.secretKey, password, aad: VaultAad.history);

  /// Opens a `vault_history` blob made by [sealHistory].
  static Future<String> openHistory(VaultKey key, Uint8List blob) =>
      VaultCipher.openString(key.secretKey, blob, aad: VaultAad.history);

  /// Drops the fields another type would have left behind (switching a
  /// Login to a Card in the editor must not keep a hidden password).
  static VaultPayload _forType(VaultItemType type, VaultPayload p) {
    final totp = p.totpSecret?.trim();
    final notes = p.notes.trim();
    final fields = [
      for (final f in p.customFields)
        if (f.label.trim().isNotEmpty || f.value.isNotEmpty) f,
    ];
    return switch (type) {
      VaultItemType.login => VaultPayload(
        username: p.username.trim(),
        password: p.password,
        url: p.url.trim(),
        totpSecret: totp == null || totp.isEmpty ? null : totp,
        notes: notes,
        customFields: fields,
      ),
      VaultItemType.card => VaultPayload(
        cardholder: p.cardholder.trim(),
        cardNumber: p.cardNumber.trim(),
        cardExpiry: p.cardExpiry.trim(),
        cardCvv: p.cardCvv.trim(),
        cardPin: p.cardPin.trim(),
        notes: notes,
        customFields: fields,
      ),
      VaultItemType.wifi => VaultPayload(
        wifiSsid: p.wifiSsid.trim(),
        wifiSecurity: p.wifiSecurity,
        password: p.password,
        notes: notes,
        customFields: fields,
      ),
      VaultItemType.secureNote => VaultPayload(
        notes: p.notes,
        customFields: fields,
      ),
    };
  }
}
