/// ============================================================
/// VAULT PAYLOAD — the secret part of a vault item (plaintext, in memory)
/// ============================================================
///
/// Everything that must never reach the database in clear: username,
/// password, URL, TOTP secret, notes, card and Wi-Fi fields and custom
/// fields. Serialised to compact JSON and sealed with AES-256-GCM by
/// VaultPayloadCodec into `VaultItemRecord.encryptedPayload`.
///
/// Instances exist only while the vault is unlocked and only as long as a
/// screen needs them. [toString] is redacted — never log a payload.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';

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
    this.customFields = const [],
  });

  /// Lenient decoder: unknown keys are ignored, missing ones default.
  factory VaultPayload.fromJson(Map<String, Object?> json) {
    String s(String k) => json[k] as String? ?? '';
    final custom = json['cf'];
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
    if (customFields.isNotEmpty) {
      m['cf'] = [for (final f in customFields) f.toJson()];
    }
    return m;
  }

  /// The secret the list's copy button copies for [type]: password for
  /// logins and Wi-Fi, the card number for cards, the note body for secure
  /// notes. Empty when there is nothing to copy.
  String primarySecret(VaultItemType type) => switch (type) {
    VaultItemType.login || VaultItemType.wifi => password,
    VaultItemType.card => cardNumber.replaceAll(' ', ''),
    VaultItemType.secureNote => notes,
  };

  /// The muted second line of a list row (never a secret): username for
  /// logins, masked card number, network name for Wi-Fi.
  String subtitle(VaultItemType type) => switch (type) {
    VaultItemType.login => username,
    VaultItemType.card => maskedCardNumber,
    VaultItemType.wifi => wifiSsid,
    VaultItemType.secureNote => '',
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
    customFields: customFields ?? this.customFields,
  );

  static const _fieldsEq = ListEquality<VaultCustomField>();

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
    _fieldsEq.hash(customFields),
  );

  @override
  String toString() => 'VaultPayload(<redacted>)';
}
