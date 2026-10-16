/// ============================================================
/// VAULT ITEM RECORD — a stored vault item, ciphertext only
/// ============================================================
///
/// What the database knows about a vault item: plaintext title / type /
/// organisation fields plus cached security metadata, and the opaque
/// AES-256-GCM [encryptedPayload] (nonce ‖ ciphertext ‖ mac of the JSON
/// with username, password, url, TOTP secret, notes, card / Wi-Fi fields).
/// Decryption happens only in the vault feature, in memory, while unlocked.
/// Never log or display [encryptedPayload].
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';

/// Stored as 0 login · 1 card · 2 wifi · 3 secure note ([index]).
enum VaultItemType {
  login('Login', 'Logins'),
  card('Card', 'Cards'),
  wifi('Wi-Fi', 'Wi-Fi'),
  secureNote('Secure note', 'Secure notes');

  const VaultItemType(this.label, this.plural);

  final String label;
  final String plural;

  static VaultItemType fromValue(int v) =>
      v >= 0 && v < values.length ? values[v] : VaultItemType.login;
}

@immutable
class VaultItemRecord {
  const VaultItemRecord({
    required this.id,
    required this.type,
    required this.title,
    this.iconKey,
    this.colorHex,
    this.folderId,
    this.folderName,
    this.tags = const [],
    required this.encryptedPayload,
    this.passwordStrength,
    this.passwordUpdatedAt,
    this.passwordFingerprint,
    this.breachCount,
    this.breachCheckedAt,
    this.hasTotp = false,
    this.expiryDays,
    this.isFavorite = false,
    this.isPinned = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
  });

  final String id;
  final VaultItemType type;

  /// Plaintext title — the only searchable field.
  final String title;

  /// Brand / icon key (letter avatar fallback).
  final String? iconKey;
  final String? colorHex;
  final String? folderId;
  final String? folderName;
  final List<Tag> tags;

  /// AES-256-GCM blob; opaque to everything outside the vault crypto.
  final Uint8List encryptedPayload;

  /// Cached 0–4 strength of the current password (null = no password).
  final int? passwordStrength;
  final DateTime? passwordUpdatedAt;

  /// HMAC of the password under a vault-derived key (reuse detection).
  final String? passwordFingerprint;

  /// HIBP result: null = never checked, 0 = clean, >0 = times seen.
  final int? breachCount;
  final DateTime? breachCheckedAt;
  final bool hasTotp;

  /// Password expiry reminder in days (null = off).
  final int? expiryDays;
  final bool isFavorite;
  final bool isPinned;
  final double sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;

  ItemRef get ref => ItemRef(ItemType.vault, id);
  bool get isNew => id.isEmpty;
  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => archivedAt == null && deletedAt == null;
  bool get isBreached => (breachCount ?? 0) > 0;

  /// Cached strength ≤ 1 on the 0–4 scale.
  bool get isWeak => passwordStrength != null && passwordStrength! <= 1;

  /// Password older than [expiryDays] (false when expiry is off).
  bool isExpired(DateTime now) {
    final days = expiryDays, changed = passwordUpdatedAt;
    if (days == null || changed == null) return false;
    return now.difference(changed).inDays >= days;
  }

  VaultItemRecord copyWith({
    String? id,
    VaultItemType? type,
    String? title,
    String? iconKey,
    String? colorHex,
    bool clearColor = false,
    String? folderId,
    bool clearFolder = false,
    List<Tag>? tags,
    Uint8List? encryptedPayload,
    int? passwordStrength,
    DateTime? passwordUpdatedAt,
    String? passwordFingerprint,
    int? breachCount,
    DateTime? breachCheckedAt,
    bool? hasTotp,
    int? expiryDays,
    bool clearExpiry = false,
    bool? isFavorite,
    bool? isPinned,
    double? sortOrder,
  }) => VaultItemRecord(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    iconKey: iconKey ?? this.iconKey,
    colorHex: clearColor ? null : (colorHex ?? this.colorHex),
    folderId: clearFolder ? null : (folderId ?? this.folderId),
    folderName: clearFolder ? null : folderName,
    tags: tags ?? this.tags,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
    passwordStrength: passwordStrength ?? this.passwordStrength,
    passwordUpdatedAt: passwordUpdatedAt ?? this.passwordUpdatedAt,
    passwordFingerprint: passwordFingerprint ?? this.passwordFingerprint,
    breachCount: breachCount ?? this.breachCount,
    breachCheckedAt: breachCheckedAt ?? this.breachCheckedAt,
    hasTotp: hasTotp ?? this.hasTotp,
    expiryDays: clearExpiry ? null : (expiryDays ?? this.expiryDays),
    isFavorite: isFavorite ?? this.isFavorite,
    isPinned: isPinned ?? this.isPinned,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
  );

  static const _bytesEq = ListEquality<int>();
  static const _tagsEq = ListEquality<Tag>();

  @override
  bool operator ==(Object other) =>
      other is VaultItemRecord &&
      other.id == id &&
      other.type == type &&
      other.title == title &&
      other.iconKey == iconKey &&
      other.colorHex == colorHex &&
      other.folderId == folderId &&
      other.folderName == folderName &&
      _tagsEq.equals(other.tags, tags) &&
      _bytesEq.equals(other.encryptedPayload, encryptedPayload) &&
      other.passwordStrength == passwordStrength &&
      other.passwordUpdatedAt == passwordUpdatedAt &&
      other.passwordFingerprint == passwordFingerprint &&
      other.breachCount == breachCount &&
      other.breachCheckedAt == breachCheckedAt &&
      other.hasTotp == hasTotp &&
      other.expiryDays == expiryDays &&
      other.isFavorite == isFavorite &&
      other.isPinned == isPinned &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.archivedAt == archivedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    type,
    title,
    iconKey,
    colorHex,
    folderId,
    folderName,
    _tagsEq.hash(tags),
    _bytesEq.hash(encryptedPayload),
    passwordStrength,
    passwordUpdatedAt,
    passwordFingerprint,
    breachCount,
    breachCheckedAt,
    hasTotp,
    expiryDays,
    isFavorite,
    isPinned,
    sortOrder,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
  ]);

  /// Never prints the payload.
  @override
  String toString() => 'VaultItemRecord($id, ${type.name}, $title)';
}

/// A previous password of a vault item (encrypted with the vault DEK).
@immutable
class VaultHistoryEntry {
  const VaultHistoryEntry({
    required this.id,
    required this.itemId,
    required this.encryptedPassword,
    required this.changedAt,
  });

  final String id;
  final String itemId;
  final Uint8List encryptedPassword;
  final DateTime changedAt;

  static const _bytesEq = ListEquality<int>();

  @override
  bool operator ==(Object other) =>
      other is VaultHistoryEntry &&
      other.id == id &&
      other.itemId == itemId &&
      _bytesEq.equals(other.encryptedPassword, encryptedPassword) &&
      other.changedAt == changedAt;

  @override
  int get hashCode =>
      Object.hash(id, itemId, _bytesEq.hash(encryptedPassword), changedAt);

  @override
  String toString() => 'VaultHistoryEntry($itemId @ $changedAt)';
}

/// One password-generator result (encrypted; local only, last 10 kept).
@immutable
class GeneratedSecret {
  const GeneratedSecret({
    required this.id,
    required this.encryptedValue,
    required this.mode,
    required this.entropyBits,
    required this.createdAt,
  });

  final String id;
  final Uint8List encryptedValue;

  /// `password` · `passphrase` · `pin`.
  final String mode;
  final int entropyBits;
  final DateTime createdAt;

  static const _bytesEq = ListEquality<int>();

  @override
  bool operator ==(Object other) =>
      other is GeneratedSecret &&
      other.id == id &&
      _bytesEq.equals(other.encryptedValue, encryptedValue) &&
      other.mode == mode &&
      other.entropyBits == entropyBits &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    _bytesEq.hash(encryptedValue),
    mode,
    entropyBits,
    createdAt,
  );

  @override
  String toString() => 'GeneratedSecret($mode, $entropyBits bits)';
}

/// Vault header / category / security tile numbers (active items).
@immutable
class VaultCounts {
  const VaultCounts({
    this.total = 0,
    this.byType = const {},
    this.favourites = 0,
    this.weak = 0,
    this.breached = 0,
    this.withTotp = 0,
  });

  final int total;
  final Map<VaultItemType, int> byType;
  final int favourites;
  final int weak;
  final int breached;
  final int withTotp;

  int of(VaultItemType type) => byType[type] ?? 0;

  @override
  bool operator ==(Object other) =>
      other is VaultCounts &&
      other.total == total &&
      mapEquals(other.byType, byType) &&
      other.favourites == favourites &&
      other.weak == weak &&
      other.breached == breached &&
      other.withTotp == withTotp;

  @override
  int get hashCode => Object.hash(
    total,
    Object.hashAllUnordered(byType.entries.map((e) => (e.key, e.value))),
    favourites,
    weak,
    breached,
    withTotp,
  );
}
