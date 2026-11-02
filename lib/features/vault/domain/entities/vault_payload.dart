/// ============================================================
/// VAULT PAYLOAD — the secret part of a vault item (plaintext, in memory)
/// ============================================================
///
/// Everything that must never reach the database in clear: username,
/// password, URL, TOTP secret, notes, card and Wi-Fi fields, the typed
/// [VaultPayload.fields] of the schema types (bank account, passport, server
/// …) and custom fields. Serialised to compact JSON and sealed with AES-256-GCM by
/// VaultPayloadCodec into `VaultItemRecord.encryptedPayload`.
///
/// Instances exist only while the vault is unlocked and only as long as a
/// screen needs them. [toString] is redacted — never log a payload.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_schema.dart';

/// One user-defined field ("Security question", "Recovery email").
@immutable
class VaultCustomField {
  const VaultCustomField({
    required this.label,
    required this.value,
    this.hidden = false,
  });

  factory VaultCustomField.fromJson(Map<String, Object?> json) =>
      VaultCustomField(
        label: json['l'] as String? ?? '',
        value: json['v'] as String? ?? '',
        hidden: json['h'] as bool? ?? false,
      );

  final String label;
  final String value;

  /// Masked like a password in the detail screen.
  final bool hidden;

  Map<String, Object?> toJson() => {
    'l': label,
    'v': value,
    if (hidden) 'h': true,
  };

  @override
  bool operator ==(Object other) =>
      other is VaultCustomField &&
      other.label == label &&
      other.value == value &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(label, value, hidden);

  @override
  String toString() => 'VaultCustomField($label, <redacted>)';
}

@immutable
class VaultPayload {
  const VaultPayload({
    this.username = '',
    this.password = '',
    this.url = '',
    this.totpSecret,
    this.notes = '',
    this.cardholder = '',
    this.cardNumber = '',
    this.cardExpiry = '',
    this.cardCvv = '',
    this.cardPin = '',
    this.wifiSsid = '',
    this.wifiSecurity = '',
    this.fields = const {},
    this.customFields = const [],
  });

  /// Longest stored value / key and most entries of [fields] — a payload
  /// from a corrupt or hostile backup cannot balloon memory.
  static const int maxFieldValue = 20000;
  static const int maxFieldKey = 64;
  static const int maxFieldCount = 256;

  /// Lenient decoder: unknown keys are ignored, missing ones default.
  factory VaultPayload.fromJson(Map<String, Object?> json) {
    String s(String k) => json[k] as String? ?? '';
    final custom = json['cf'];
    final typed = json['f'];
    return VaultPayload(
      username: s('u'),
      password: s('p'),
      url: s('url'),
      totpSecret: json['totp'] as String?,
      notes: s('n'),
      cardholder: s('ch'),
      cardNumber: s('cn'),
      cardExpiry: s('ce'),
      cardCvv: s('cv'),
      cardPin: s('cp'),
      wifiSsid: s('ws'),
      wifiSecurity: s('wt'),
      fields: typed is Map ? _cleanFields(typed) : const {},
      customFields: custom is List
          ? [
              for (final f in custom)
                if (f is Map) VaultCustomField.fromJson(f.cast()),
            ]
          : const [],
    );
  }

  static const VaultPayload empty = VaultPayload();

  final String username;
  final String password;
  final String url;

  /// Base32 secret or `otpauth://` URI (null = no 2FA code).
  final String? totpSecret;
  final String notes;

  // Card
  final String cardholder;
  final String cardNumber;

  /// `MM/YY`.
  final String cardExpiry;
  final String cardCvv;
  final String cardPin;

  // Wi-Fi (password lives in [password])
  final String wifiSsid;

  /// "WPA2", "WPA3", "WEP", "None".
  final String wifiSecurity;

  /// Typed values of the schema types (key → text; see
  /// VaultItemTypeSchema). Empty for login / card / Wi-Fi / secure note.
  final Map<String, String> fields;

  final List<VaultCustomField> customFields;

  /// Compact JSON (empty fields omitted).
  Map<String, Object?> toJson() {
    final m = <String, Object?>{};
    void put(String k, String v) {
      if (v.isNotEmpty) m[k] = v;
    }

    put('u', username);
    put('p', password);
    put('url', url);
    if (totpSecret != null && totpSecret!.isNotEmpty) m['totp'] = totpSecret;
    put('n', notes);
    put('ch', cardholder);
    put('cn', cardNumber);
    put('ce', cardExpiry);
    put('cv', cardCvv);
    put('cp', cardPin);
    put('ws', wifiSsid);
    put('wt', wifiSecurity);
    final typed = {
      for (final e in fields.entries)
        if (e.value.isNotEmpty) e.key: e.value,
    };
    if (typed.isNotEmpty) m['f'] = typed;
    if (customFields.isNotEmpty) {
      m['cf'] = [for (final f in customFields) f.toJson()];
    }
    return m;
  }

  /// A stored typed value ('' when absent).
  String field(String key) => fields[key] ?? '';

  /// The address "Open website" opens for [type]: the login's website, or
  /// the first non-empty address field of a schema type ('' when none).
  String websiteFor(VaultItemType type) {
    if (!type.isSchemaType) return type == VaultItemType.login ? url : '';
    for (final k in type.websiteKeys) {
      final v = field(k).trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  /// Copy with [key] set to [value] (removed when [value] is empty).
  VaultPayload withField(String key, String value) {
    final next = {...fields};
    if (value.isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return copyWith(fields: next);
  }

  /// The secret the list's copy button copies for [type]: password for
  /// logins and Wi-Fi, the card number for cards, the note body for secure
  /// notes, the type's primary field (IBAN, licence key …) for schema
  /// types. Empty when there is nothing to copy.
  String primarySecret(VaultItemType type) => switch (type) {
    VaultItemType.login || VaultItemType.wifi => password,
    VaultItemType.card => cardNumber.replaceAll(' ', ''),
    VaultItemType.secureNote => notes,
    _ => type.primaryOf(fields, password).value,
  };

  /// The muted second line of a list row (never a secret): username for
  /// logins, masked card number, network name for Wi-Fi.
  String subtitle(VaultItemType type) => switch (type) {
    VaultItemType.login => username,
    VaultItemType.card => maskedCardNumber,
    VaultItemType.wifi => wifiSsid,
    VaultItemType.secureNote => '',
    _ => type.subtitleOf(fields),
  };

  /// "•••• 4242" (empty when there is no number).
  String get maskedCardNumber {
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    final tail = digits.length <= 4
        ? digits
        : digits.substring(digits.length - 4);
    return '•••• $tail';
  }

  VaultPayload copyWith({
    String? username,
    String? password,
    String? url,
    String? totpSecret,
    bool clearTotp = false,
    String? notes,
    String? cardholder,
    String? cardNumber,
    String? cardExpiry,
    String? cardCvv,
    String? cardPin,
    String? wifiSsid,
    String? wifiSecurity,
    Map<String, String>? fields,
    List<VaultCustomField>? customFields,
  }) => VaultPayload(
    username: username ?? this.username,
    password: password ?? this.password,
    url: url ?? this.url,
    totpSecret: clearTotp ? null : (totpSecret ?? this.totpSecret),
    notes: notes ?? this.notes,
    cardholder: cardholder ?? this.cardholder,
    cardNumber: cardNumber ?? this.cardNumber,
    cardExpiry: cardExpiry ?? this.cardExpiry,
    cardCvv: cardCvv ?? this.cardCvv,
    cardPin: cardPin ?? this.cardPin,
    wifiSsid: wifiSsid ?? this.wifiSsid,
    wifiSecurity: wifiSecurity ?? this.wifiSecurity,
    fields: fields ?? this.fields,
    customFields: customFields ?? this.customFields,
  );

  /// Keeps only well-formed string entries within the size limits.
  static Map<String, String> _cleanFields(Map<Object?, Object?> raw) {
    final out = <String, String>{};
    for (final e in raw.entries) {
      final k = e.key, v = e.value;
      if (k is! String || v is! String) continue;
      if (k.isEmpty || k.length > maxFieldKey || v.length > maxFieldValue) {
        continue;
      }
      out[k] = v;
      if (out.length >= maxFieldCount) break;
    }
    return out;
  }

  static const _fieldsEq = ListEquality<VaultCustomField>();
  static const _typedEq = MapEquality<String, String>();

  @override
  bool operator ==(Object other) =>
      other is VaultPayload &&
      other.username == username &&
      other.password == password &&
      other.url == url &&
      other.totpSecret == totpSecret &&
      other.notes == notes &&
      other.cardholder == cardholder &&
      other.cardNumber == cardNumber &&
      other.cardExpiry == cardExpiry &&
      other.cardCvv == cardCvv &&
      other.cardPin == cardPin &&
      other.wifiSsid == wifiSsid &&
      other.wifiSecurity == wifiSecurity &&
      _typedEq.equals(other.fields, fields) &&
      _fieldsEq.equals(other.customFields, customFields);

  @override
  int get hashCode => Object.hash(
    username,
    password,
    url,
    totpSecret,
    notes,
    cardholder,
    cardNumber,
    cardExpiry,
    cardCvv,
    cardPin,
    wifiSsid,
    wifiSecurity,
    _typedEq.hash(fields),
    _fieldsEq.hash(customFields),
  );

  @override
  String toString() => 'VaultPayload(<redacted>)';
}
