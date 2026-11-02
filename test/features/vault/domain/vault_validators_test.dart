/// Advisory validators of the vault editor: card numbers (Luhn, network,
/// grouping), IBAN (mod-97), BIC, masking and document dates.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/vault/domain/services/vault_validators.dart';

void main() {
  group('VaultCardNumber', () {
    test('Luhn accepts real test numbers and rejects a changed digit', () {
      for (final ok in [
        '4242 4242 4242 4242',
        '4111111111111111',
        '5555-5555-5555-4444',
        '378282246310005', // Amex
        '6011111111111117',
      ]) {
        expect(VaultCardNumber.isValid(ok), isTrue, reason: ok);
      }
      expect(VaultCardNumber.isValid('4242 4242 4242 4241'), isFalse);
      expect(VaultCardNumber.isValid('1234'), isFalse);
      expect(VaultCardNumber.isValid(''), isFalse);
      // Too long to be a card.
      expect(VaultCardNumber.isValid('4' * 25), isFalse);
    });

    test('recognises the network from the issuer prefix', () {
      VaultCardBrand? b(String n) => VaultCardNumber.brand(n);
      expect(b('4242424242424242'), VaultCardBrand.visa);
      expect(b('5555555555554444'), VaultCardBrand.mastercard);
      expect(b('2221000000000009'), VaultCardBrand.mastercard);
      expect(b('378282246310005'), VaultCardBrand.amex);
      expect(b('6011111111111117'), VaultCardBrand.discover);
      expect(b('6212345678901234'), VaultCardBrand.unionPay);
      expect(b('3530111333300000'), VaultCardBrand.jcb);
      expect(b('30569309025904'), VaultCardBrand.diners);
      expect(b('9'), isNull);
      expect(b(''), isNull);
    });

    test('groups digits like the card is printed', () {
      expect(
        VaultCardNumber.format('4242424242424242'),
        '4242 4242 4242 4242',
      );
      expect(VaultCardNumber.format('378282246310005'), '3782 822463 10005');
      expect(VaultCardNumber.format('4242'), '4242');
      expect(VaultCardNumber.format('42424'), '4242 4');
      // Idempotent on already-spaced input.
      expect(
        VaultCardNumber.format('4242 4242 4242 4242'),
        '4242 4242 4242 4242',
      );
    });
  });

  group('VaultIban / VaultBic', () {
    test('mod-97 accepts valid IBANs in any casing and spacing', () {
      for (final ok in [
        'GB82WEST12345698765432',
        'gb82 west 1234 5698 7654 32',
        'DE89 3704 0044 0532 0130 00',
        'FR1420041010050500013M02606',
      ]) {
        expect(VaultIban.isValid(ok), isTrue, reason: ok);
      }
    });

    test('rejects a wrong check digit, bad shape and short input', () {
      expect(VaultIban.isValid('GB83WEST12345698765432'), isFalse);
      expect(VaultIban.isValid('GB82WEST1234569876543'), isFalse);
      expect(VaultIban.isValid('1234567890123456'), isFalse);
      expect(VaultIban.isValid('GB82'), isFalse);
      expect(VaultIban.isValid(''), isFalse);
    });

    test('formats in groups of four', () {
      expect(
        VaultIban.format('gb82 west 1234 5698 7654 32'),
        'GB82 WEST 1234 5698 7654 32',
      );
      expect(VaultIban.format('GB82WEST12345698765432'), 'GB82 WEST 1234 5698 7654 32');
    });

    test('BIC is 8 or 11 characters of the right shape', () {
      expect(VaultBic.isValid('DEUTDEFF'), isTrue);
      expect(VaultBic.isValid('deutdeff500'), isTrue);
      expect(VaultBic.isValid('DEUT DEFF'), isTrue);
      expect(VaultBic.isValid('DEUTDEF'), isFalse);
      expect(VaultBic.isValid('DEUT12FF'), isFalse);
      expect(VaultBic.isValid('DEUTDEFF5'), isFalse);
    });
  });

  group('vaultMaskTail', () {
    test('shows at most the last four characters', () {
      expect(vaultMaskTail('1234 5678 9012'), '•••• 9012');
      expect(vaultMaskTail('42'), '•••• 42');
      expect(vaultMaskTail(''), '');
      expect(vaultMaskTail('   '), '');
    });
  });

  group('VaultDates', () {
    final now = DateTime(2026, 6, 13, 23, 59);

    test('parses only real yyyy-MM-dd days', () {
      expect(VaultDates.tryParse('2027-03-05'), DateTime(2027, 3, 5));
      expect(VaultDates.tryParse(' 2027-03-05 '), DateTime(2027, 3, 5));
      expect(VaultDates.tryParse('2025-02-31'), isNull); // would roll over
      expect(VaultDates.tryParse('2024-02-29'), DateTime(2024, 2, 29));
      expect(VaultDates.tryParse('2026-13-01'), isNull);
      expect(VaultDates.tryParse('05/03/2027'), isNull);
      expect(VaultDates.tryParse(''), isNull);
      expect(VaultDates.key(DateTime(2027, 3, 5, 18)), '2027-03-05');
    });

    test('daysUntil ignores the time of day', () {
      expect(VaultDates.daysUntil('2026-06-13', now), 0);
      expect(VaultDates.daysUntil('2026-06-14', now), 1);
      expect(VaultDates.daysUntil('2026-06-12', now), -1);
      expect(VaultDates.daysUntil('nope', now), isNull);
    });

    test('status flips at today and at the soon window', () {
      VaultExpiryStatus? s(String d) => VaultDates.status(d, now);
      expect(s('2026-06-12'), VaultExpiryStatus.expired);
      expect(s('2026-06-13'), VaultExpiryStatus.soon); // expires today
      expect(s('2026-08-12'), VaultExpiryStatus.soon); // +60 days
      expect(s('2026-08-13'), VaultExpiryStatus.ok); // +61 days
      expect(s(''), isNull);
    });

    test('a card expires at the END of its MM/YY month', () {
      expect(VaultDates.cardExpiryEnd('02/28'), DateTime(2028, 2, 29));
      expect(VaultDates.cardExpiryEnd('12/26'), DateTime(2026, 12, 31));
      expect(VaultDates.cardExpiryEnd('1/2027'), DateTime(2027, 1, 31));
      expect(VaultDates.cardExpiryEnd('13/26'), isNull);
      expect(VaultDates.cardExpiryEnd('0126'), isNull);
      expect(VaultDates.cardExpiryEnd(''), isNull);
    });
  });
}
