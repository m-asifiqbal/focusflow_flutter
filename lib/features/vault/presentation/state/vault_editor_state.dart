/// ============================================================
/// VAULT EDITOR STATE — the item being added / edited (screen 20)
/// ============================================================
///
/// Holds the organisation fields (type, title, icon, folder, tags,
/// favourite, expiry) and the decrypted [VaultPayload] while the editor is
/// open. Lives only in memory, is dropped when the vault locks and its
/// [toString] is redacted — never log it.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/crypto/password_strength.dart';
import 'package:focusflow/core/crypto/totp.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_item_service.dart';

/// Which editor: an existing item ([id]) or a new one of [type].
typedef VaultEditorArgs = ({String? id, VaultItemType type});

/// The item could not be found (deleted elsewhere / bad link).
class VaultItemNotFound implements Exception {
  const VaultItemNotFound();

  @override
  String toString() => 'VaultItemNotFound';
}

/// The stored blob could not be decrypted with the open key.
class VaultItemUndecryptable implements Exception {
  const VaultItemUndecryptable();

  @override
  String toString() => 'VaultItemUndecryptable';
}

@immutable
class VaultEditorState {
  const VaultEditorState({
    required this.type,
    this.original,
    this.previous,
    this.title = '',
    this.iconKey,
    this.colorHex,
    this.folderId,
    this.tags = const [],
    this.isFavorite = false,
    this.expiryDays,
    this.payload = VaultPayload.empty,
    this.dirty = false,
    this.saving = false,
    this.titleError,
  });

  /// The stored record being edited (null = new item).
  final VaultItemRecord? original;

  /// Its payload as loaded (feeds password history on save).
  final VaultPayload? previous;

  final VaultItemType type;
  final String title;
  final String? iconKey;
  final String? colorHex;
  final String? folderId;
  final List<String> tags;
  final bool isFavorite;

  /// Password expiry reminder in days (null = off).
  final int? expiryDays;
  final VaultPayload payload;

  /// Something changed since load (Cancel asks before discarding).
  final bool dirty;
  final bool saving;

  /// "Add a title" after a save attempt without one.
  final String? titleError;

  bool get isNew => original == null;

  /// Logins and Wi-Fi have a password (strength meter, expiry reminder).
  bool get hasPassword =>
      type == VaultItemType.login || type == VaultItemType.wifi;

  /// Live strength of the password being typed.
  PasswordStrength get strength =>
      PasswordStrengthEstimator.estimate(payload.password);

  /// A 2FA secret was entered but can't produce codes.
  bool get totpInvalid {
    final t = payload.totpSecret?.trim() ?? '';
    return t.isNotEmpty && TotpConfig.parse(t) == null;
  }

  /// What [VaultItemService.save] stores next to the sealed payload.
  VaultItemDraft get draft => VaultItemDraft(
    type: type,
    title: title,
    iconKey: iconKey,
    colorHex: colorHex,
    folderId: folderId,
    tagNames: tags,
    isFavorite: isFavorite,
    expiryDays: expiryDays,
  );

  VaultEditorState copyWith({
    VaultItemType? type,
    String? title,
    String? iconKey,
    bool clearIcon = false,
    String? colorHex,
    bool clearColor = false,
    String? folderId,
    bool clearFolder = false,
    List<String>? tags,
    bool? isFavorite,
    int? expiryDays,
    bool clearExpiry = false,
    VaultPayload? payload,
    bool? dirty,
    bool? saving,
    String? titleError,
    bool clearTitleError = false,
  }) => VaultEditorState(
    original: original,
    previous: previous,
    type: type ?? this.type,
    title: title ?? this.title,
    iconKey: clearIcon ? null : (iconKey ?? this.iconKey),
    colorHex: clearColor ? null : (colorHex ?? this.colorHex),
    folderId: clearFolder ? null : (folderId ?? this.folderId),
    tags: tags ?? this.tags,
    isFavorite: isFavorite ?? this.isFavorite,
    expiryDays: clearExpiry ? null : (expiryDays ?? this.expiryDays),
    payload: payload ?? this.payload,
    dirty: dirty ?? this.dirty,
    saving: saving ?? this.saving,
    titleError: clearTitleError ? null : (titleError ?? this.titleError),
  );

  @override
  String toString() => 'VaultEditorState(${type.name}, <redacted>)';
}
