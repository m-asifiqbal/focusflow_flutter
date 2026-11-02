/// ============================================================
/// VAULT FIELD SPEC — the vocabulary of schema-driven item types
/// ============================================================
///
/// A [VaultFieldSpec] describes one field of a vault item type (label,
/// storage key, how it is edited and shown); a [VaultSection] groups them
/// into a card. The per-type lists live in vault_type_schemas.dart and the
/// helpers on `VaultItemType` in vault_item_schema.dart.
///
/// Two kinds are special and map to the payload's own slots so the cached
/// strength / reuse / breach / 2FA metadata keeps working for every type:
/// [VaultFieldKind.password] → `payload.password`, [VaultFieldKind.totp] →
/// `payload.totpSecret`. Everything else is stored in `payload.fields`.
/// Keys are stable storage ids — never rename one.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';

/// How a field is edited and shown.
enum VaultFieldKind {
  text,
  multiline,

  /// Digits only (port, year, seats).
  number,
  email,
  phone,
  url,

  /// Stored as `yyyy-MM-dd`; picked with a date picker.
  date,

  /// One of [VaultFieldSpec.options] (stored as the option's `value`).
  choice,

  /// Hidden like a password (API secret, recovery phrase, licence key).
  secret,

  /// Digits only and hidden (ATM PIN).
  pin,

  /// The item's password (`payload.password`): strength meter, generator,
  /// history, expiry reminder, breach + reuse checks.
  password,

  /// The item's 2FA secret (`payload.totpSecret`): QR scan + live code.
  totp,
}

/// Auto-capitalisation of a text field (mapped to Flutter's in the UI).
enum VaultCaps { none, words, sentences, characters }

/// An advisory format check (a soft warning, never blocks saving).
enum VaultFieldFormat { none, iban, bic }

/// One option of a [VaultFieldKind.choice] field.
@immutable
class VaultOption {
  const VaultOption(this.value, this.label);

  /// Stored, language-independent id ("savings").
  final String value;

  /// Shown text.
  final String label;
}

@immutable
class VaultFieldSpec {
  const VaultFieldSpec(
    this.key,
    this.label, {
    this.kind = VaultFieldKind.text,
    this.hint,
    this.options = const [],
    this.sensitive = false,
    this.expiry = false,
    this.mono = false,
    this.caps = VaultCaps.none,
    this.format = VaultFieldFormat.none,
  });

  /// Stable storage id inside `VaultPayload.fields`.
  final String key;
  final String label;
  final VaultFieldKind kind;

  /// Placeholder (data such as "USD", not prose).
  final String? hint;
  final List<VaultOption> options;

  /// Masked in the detail card and the list subtitle, revealed only through
  /// the eye (re-authentication when the user asked for it) and copied with
  /// auto-clear. Secret / PIN / password kinds are always masked.
  final bool sensitive;

  /// A date after which the item is "expired" (drives the EXPIRED /
  /// EXPIRING badge).
  final bool expiry;
  final bool mono;
  final VaultCaps caps;
  final VaultFieldFormat format;

  /// True when the value is hidden by default.
  bool get masked =>
      sensitive ||
      kind == VaultFieldKind.secret ||
      kind == VaultFieldKind.pin ||
      kind == VaultFieldKind.password;

  /// Lives in `payload.fields` (not the password / 2FA slots).
  bool get isStoredInFields =>
      kind != VaultFieldKind.password && kind != VaultFieldKind.totp;

  /// The text to show for the stored [raw] value: an option's label for
  /// choices, the value itself otherwise.
  String display(String raw) {
    if (kind != VaultFieldKind.choice) return raw;
    for (final o in options) {
      if (o.value == raw) return o.label;
    }
    return raw;
  }
}

/// A titled group of fields (one card in the editor and the detail).
@immutable
class VaultSection {
  const VaultSection(this.title, this.fields);

  final String title;
  final List<VaultFieldSpec> fields;
}

/// How the type picker groups the types.
enum VaultTypeGroup {
  everyday,
  finance,
  identity,
  digital,
  lifestyle;

  /// Heading in the type picker (a getter: follows the active language).
  String get label => switch (this) {
    everyday => tr('Everyday'),
    finance => tr('Finance'),
    identity => tr('Identity & health'),
    digital => tr('Digital & developer'),
    lifestyle => tr('Lifestyle'),
  };
}
