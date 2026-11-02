/// The schema-driven vault types: the data in vault_type_schemas.dart stays
/// consistent (unique keys, valid primary / subtitle / expiry / website
/// references, frozen storage codes) and the payload round-trips the typed
/// fields safely (size limits, lenient decode, redaction).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_schema.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';

void main() {
  final schemaTypes = [
    for (final t in VaultItemType.values)
      if (t.isSchemaType) t,
  ];

  test('storage codes are frozen (they are in every database and backup)', () {
    // Append-only: if this fails someone reordered the enum, which would
    // silently turn every saved item into another type.
    expect({for (final t in VaultItemType.values) t.name: t.index}, {
      'login': 0,
      'card': 1,
      'wifi': 2,
      'secureNote': 3,
      'bankAccount': 4,
      'cryptoWallet': 5,
      'insurance': 6,
      'identity': 7,
      'passport': 8,
      'driverLicense': 9,
      'nationalId': 10,
      'medical': 11,
      'emailAccount': 12,
      'server': 13,
      'apiKey': 14,
      'softwareLicense': 15,
      'membership': 16,
      'vehicle': 17,
    });
    expect(VaultItemType.fromValue(99), VaultItemType.login);
    expect(VaultItemType.fromValue(-1), VaultItemType.login);
    expect(VaultItemType.fromValue(4), VaultItemType.bankAccount);
  });

  test('only the four built-in types have no schema', () {
    expect(schemaTypes, hasLength(14));
    for (final t in VaultItemType.values) {
      expect(t.sections.isEmpty, !t.isSchemaType, reason: t.name);
    }
  });

  group('every schema type', () {
    for (final t in schemaTypes) {
      group(t.name, () {
        test('has unique keys, labels and sections', () {
          final keys = t.specs.map((f) => f.key).toList();
          expect(keys.toSet(), hasLength(keys.length), reason: 'dup key');
          for (final s in t.sections) {
            expect(s.title, isNotEmpty);
            expect(s.fields, isNotEmpty);
          }
          for (final f in t.specs) {
            expect(f.label, isNotEmpty, reason: f.key);
            expect(f.key.length, lessThanOrEqualTo(VaultPayload.maxFieldKey));
          }
        });

        test('password / 2FA slots match hasPassword / hasTotp', () {
          expect(
            t.specs.any((f) => f.kind == VaultFieldKind.password),
            t.hasPassword,
          );
          expect(
            t.specs.any((f) => f.kind == VaultFieldKind.totp),
            t.hasTotp,
          );
          // The slots are never stored in the typed map.
          expect(t.fieldKeys.contains('password'), isFalse);
          expect(t.fieldKeys.contains('totp'), isFalse);
        });

        test('choices have unique stored values', () {
          for (final f in t.specs) {
            if (f.kind == VaultFieldKind.choice) {
              expect(f.options, isNotEmpty, reason: f.key);
              expect(
                f.options.map((o) => o.value).toSet(),
                hasLength(f.options.length),
                reason: f.key,
              );
            } else {
              expect(f.options, isEmpty, reason: f.key);
            }
          }
        });

        test('primary / subtitle / website / expiry keys exist', () {
          expect(t.primaryKeys, isNotEmpty);
          expect(t.subtitleKeys, isNotEmpty);
          for (final k in [...t.primaryKeys, ...t.subtitleKeys]) {
            expect(t.spec(k), isNotNull, reason: '$k is not a field of $t');
          }
          for (final k in t.websiteKeys) {
            expect(t.spec(k)?.kind, VaultFieldKind.url, reason: k);
          }
          for (final k in t.expiryKeys) {
            expect(t.spec(k)?.kind, VaultFieldKind.date, reason: k);
          }
          // 'password' as a primary needs a password slot.
          if (t.primaryKeys.contains('password')) expect(t.hasPassword, isTrue);
        });

        test('every label has a type name and group', () {
          expect(t.label, isNotEmpty);
          expect(t.plural, isNotEmpty);
          expect(t.group.label, isNotEmpty);
        });
      });
    }
  });

  group('VaultPayload typed fields', () {
    test('round-trips through JSON without empty values', () {
      final p = const VaultPayload(
        password: 'pw',
      ).withField('iban', 'GB82WEST12345698765432').withField('bank', 'HSBC');
      final json = jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>;
      expect(json['f'], {'iban': 'GB82WEST12345698765432', 'bank': 'HSBC'});
      expect(VaultPayload.fromJson(json), p);
      // Setting a field to '' removes it (and the whole key when none left).
      final cleared = p.withField('iban', '').withField('bank', '');
      expect(cleared.fields, isEmpty);
      expect(cleared.toJson().containsKey('f'), isFalse);
    });

    test('the decoder is lenient and bounded', () {
      final p = VaultPayload.fromJson({
        'f': {
          'ok': 'value',
          'num': 5, // not a string: skipped
          '': 'no key',
          'k' * (VaultPayload.maxFieldKey + 1): 'key too long',
          'big': 'x' * (VaultPayload.maxFieldValue + 1),
        },
      });
      expect(p.fields, {'ok': 'value'});
      expect(VaultPayload.fromJson({'f': 'not a map'}).fields, isEmpty);
      // Old payloads (no `f`) still open.
      expect(VaultPayload.fromJson({'u': 'me'}).fields, isEmpty);
      final many = VaultPayload.fromJson({
        'f': {for (var i = 0; i < 1000; i++) 'k$i': 'v'},
      });
      expect(many.fields.length, VaultPayload.maxFieldCount);
    });

    test('equality and hashing include the typed fields', () {
      final a = const VaultPayload().withField('a', '1');
      final b = const VaultPayload().withField('a', '1');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == const VaultPayload().withField('a', '2'), isFalse);
    });

    test('the copy button and subtitle follow the type', () {
      final bank = const VaultPayload()
          .withField('holder', 'Asif Iqbal')
          .withField('number', '1234567890')
          .withField('iban', 'GB82WEST12345698765432');
      // IBAN wins over the account number; the subtitle masks the number.
      expect(bank.primarySecret(VaultItemType.bankAccount), startsWith('GB82'));
      expect(
        bank.subtitle(VaultItemType.bankAccount),
        'Asif Iqbal · •••• 7890',
      );
      final onlyNumber = const VaultPayload().withField('number', '555');
      expect(onlyNumber.primarySecret(VaultItemType.bankAccount), '555');
      expect(const VaultPayload().primarySecret(VaultItemType.passport), '');
      // A server copies its password.
      expect(
        const VaultPayload(password: 'root-pw').primarySecret(VaultItemType.server),
        'root-pw',
      );
      // Built-in types are unchanged.
      expect(
        const VaultPayload(cardNumber: '4242 4242').primarySecret(VaultItemType.card),
        '42424242',
      );
    });

    test('websiteFor picks the type-specific address', () {
      final server = const VaultPayload().withField('console', 'panel.example.com');
      expect(server.websiteFor(VaultItemType.server), 'panel.example.com');
      final bank = const VaultPayload(
        url: 'ignored.example',
      ).withField('url', 'bank.example');
      expect(bank.websiteFor(VaultItemType.bankAccount), 'bank.example');
      expect(
        const VaultPayload(url: 'site.example').websiteFor(VaultItemType.login),
        'site.example',
      );
      expect(
        const VaultPayload(url: 'x.example').websiteFor(VaultItemType.card),
        '',
      );
      expect(const VaultPayload().websiteFor(VaultItemType.apiKey), '');
    });

    test('toString never prints a value', () {
      final p = const VaultPayload().withField('seed', 'abandon ability able');
      expect(p.toString(), isNot(contains('abandon')));
      expect(p.toString(), contains('redacted'));
    });
  });
}
