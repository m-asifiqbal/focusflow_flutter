/// ============================================================
/// VAULT ITEM SCHEMA — what fields each vault item type has
/// ============================================================
///
/// Login, Card, Wi-Fi and Secure note keep their hand-built screens. Every
/// other type (bank account, passport, server, licence key …) is *data*: a
/// list of sections of field specs in vault_type_schemas.dart. One generic
/// editor section and one generic detail card render any of them, so adding
/// a type is a spec list, not new screens.
///
/// Values live in `VaultPayload.fields` (key → text, inside the encrypted
/// payload). Specs are rebuilt by getters (never cached) so their labels
/// follow the active language; the hot paths (`hasPassword`, `primaryKeys`)
/// are plain switches and build nothing.
/// ============================================================
library;

import 'package:focusflow/features/vault/domain/entities/vault_field_spec.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_type_schemas.dart';
import 'package:focusflow/features/vault/domain/services/vault_validators.dart';

export 'package:focusflow/features/vault/domain/entities/vault_field_spec.dart';

extension VaultItemTypeSchema on VaultItemType {
  /// Types 4+ are described by a schema; 0–3 have their own screens.
  bool get isSchemaType => index >= VaultItemType.bankAccount.index;

  VaultTypeGroup get group => switch (this) {
    VaultItemType.login ||
    VaultItemType.card ||
    VaultItemType.wifi ||
    VaultItemType.secureNote => VaultTypeGroup.everyday,
    VaultItemType.bankAccount ||
    VaultItemType.cryptoWallet ||
    VaultItemType.insurance => VaultTypeGroup.finance,
    VaultItemType.identity ||
    VaultItemType.passport ||
    VaultItemType.driverLicense ||
    VaultItemType.nationalId ||
    VaultItemType.medical => VaultTypeGroup.identity,
    VaultItemType.emailAccount ||
    VaultItemType.server ||
    VaultItemType.apiKey ||
    VaultItemType.softwareLicense => VaultTypeGroup.digital,
    VaultItemType.membership ||
    VaultItemType.vehicle => VaultTypeGroup.lifestyle,
  };

  /// The sections of a schema type (empty for the four built-in types).
  List<VaultSection> get sections => vaultSectionsOf(this);

  /// Every field of a schema type, in display order.
  List<VaultFieldSpec> get specs => [for (final s in sections) ...s.fields];

  VaultFieldSpec? spec(String key) {
    for (final s in sections) {
      for (final f in s.fields) {
        if (f.key == key) return f;
      }
    }
    return null;
  }

  /// The keys a saved item of this type may hold in `payload.fields`;
  /// anything else is a leftover of another type and is dropped on save.
  Set<String> get fieldKeys => {
    for (final s in specs)
      if (s.isStoredInFields) s.key,
  };

  /// Has a password: strength meter, generator, history, expiry reminder.
  bool get hasPassword => switch (this) {
    VaultItemType.login ||
    VaultItemType.wifi ||
    VaultItemType.bankAccount ||
    VaultItemType.cryptoWallet ||
    VaultItemType.emailAccount ||
    VaultItemType.server => true,
    _ => false,
  };

  /// Can hold a 2FA secret.
  bool get hasTotp => switch (this) {
    VaultItemType.login ||
    VaultItemType.bankAccount ||
    VaultItemType.cryptoWallet ||
    VaultItemType.emailAccount ||
    VaultItemType.server => true,
    _ => false,
  };

  /// Field keys the list's copy button tries in order (`password` = the
  /// password slot). Empty for the built-in types.
  List<String> get primaryKeys => switch (this) {
    VaultItemType.bankAccount => const ['iban', 'number'],
    VaultItemType.cryptoWallet => const ['address'],
    VaultItemType.insurance => const ['policy'],
    VaultItemType.identity => const ['fullName'],
    VaultItemType.passport => const ['number'],
    VaultItemType.driverLicense => const ['number'],
    VaultItemType.nationalId => const ['number'],
    VaultItemType.medical => const ['memberId'],
    VaultItemType.emailAccount => const ['password'],
    VaultItemType.server => const ['password'],
    VaultItemType.apiKey => const ['key', 'token'],
    VaultItemType.softwareLicense => const ['key'],
    VaultItemType.membership => const ['member'],
    VaultItemType.vehicle => const ['plate'],
    _ => const [],
  };

  /// Field keys that hold the item's address (the first non-empty one is
  /// what "Open website" opens). Empty = nothing to open.
  List<String> get websiteKeys => switch (this) {
    VaultItemType.server => const ['console'],
    VaultItemType.bankAccount ||
    VaultItemType.cryptoWallet ||
    VaultItemType.insurance ||
    VaultItemType.emailAccount ||
    VaultItemType.softwareLicense ||
    VaultItemType.membership => const ['url'],
    _ => const [],
  };

  /// Field keys shown (joined by " · ") under the title in the list.
  List<String> get subtitleKeys => switch (this) {
    VaultItemType.bankAccount => const ['holder', 'number'],
    VaultItemType.cryptoWallet => const ['network', 'name'],
    VaultItemType.insurance => const ['provider', 'policy'],
    VaultItemType.identity => const ['email', 'phone'],
    VaultItemType.passport => const ['fullName', 'nationality'],
    VaultItemType.driverLicense => const ['fullName', 'number'],
    VaultItemType.nationalId => const ['fullName', 'number'],
    VaultItemType.medical => const ['insurer', 'memberId'],
    VaultItemType.emailAccount => const ['address'],
    VaultItemType.server => const ['username', 'host'],
    VaultItemType.apiKey => const ['service'],
    VaultItemType.softwareLicense => const ['licensee', 'version'],
    VaultItemType.membership => const ['org', 'tier'],
    VaultItemType.vehicle => const ['model', 'plate'],
    _ => const [],
  };

  /// The first non-empty of [primaryKeys] (what the copy button copies and
  /// the label of it); `('', null)` when there is nothing to copy.
  ({String value, VaultFieldSpec? spec}) primaryOf(
    Map<String, String> fields,
    String password,
  ) {
    for (final k in primaryKeys) {
      final v = (k == 'password' ? password : fields[k] ?? '').trim();
      if (v.isNotEmpty) return (value: v, spec: spec(k));
    }
    return (value: '', spec: null);
  }

  /// Muted second line of a list row. Masked fields show their last four
  /// characters only; never more than two parts.
  String subtitleOf(Map<String, String> fields) {
    if (!isSchemaType) return '';
    final parts = <String>[];
    for (final k in subtitleKeys) {
      final v = (fields[k] ?? '').trim();
      if (v.isEmpty) continue;
      final masked = spec(k)?.masked ?? false;
      parts.add(masked ? vaultMaskTail(v) : v);
      if (parts.length == 2) break;
    }
    return parts.join(' · ');
  }

  /// The date fields flagged as expiry dates.
  List<String> get expiryKeys => [
    for (final s in specs)
      if (s.expiry) s.key,
  ];
}
