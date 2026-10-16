/// Password strength (score 0–4 + crack time), the generator (entropy,
/// classes, EFF passphrases, PINs) and the failed-PIN back-off.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/password_generator.dart';
import 'package:focusflow/core/crypto/password_strength.dart';
import 'package:focusflow/core/crypto/pin_attempt_guard.dart';
import 'package:focusflow/core/crypto/vault_secret_storage.dart';

void main() {
  group('PasswordStrengthEstimator', () {
    int score(String p) => PasswordStrengthEstimator.estimate(p).score;

    test('common and patterned passwords are very weak', () {
      for (final p in [
        'password',
        'Password1!',
        'qwerty',
        '123456',
        'P@ssw0rd',
        'aaaaaaaa',
      ]) {
        expect(score(p), 0, reason: p);
      }
      expect(PasswordStrengthEstimator.estimate('password').isCommon, isTrue);
      expect(
        PasswordStrengthEstimator.estimate('password').summary,
        'Very weak · could be cracked instantly',
      );
    });

    test('long random passwords are very strong', () {
      final s = PasswordStrengthEstimator.estimate('t7#Kq!vZ2@pLm9\$wX4&');
      expect(s.score, 4);
      expect(s.crackTimeLabel, 'centuries');
      expect(s.hasSymbol && s.hasDigit && s.hasUpper && s.hasLower, isTrue);
    });

    test('scores grow with length', () {
      expect(score('kfzqmw'), lessThan(score('kfzqmwhtrx')));
      expect(score('kfzqmwhtrx'), lessThanOrEqualTo(score('kfzqmwhtrxBn7#Lp')));
      expect(PasswordStrength.empty.summary, 'Enter a password');
      expect(PasswordStrengthEstimator.estimate('').score, 0);
    });

    test('crack-time text', () {
      expect(PasswordStrength.crackTimeText(0.5), 'instantly');
      expect(PasswordStrength.crackTimeText(1), '1 second');
      expect(PasswordStrength.crackTimeText(7200), '2 hours');
      expect(PasswordStrength.crackTimeText(86400 * 3), '3 days');
      expect(PasswordStrength.crackTimeText(86400 * 365 * 5), '5 years');
      expect(PasswordStrength.crackTimeText(1e20), 'centuries');
      expect(PasswordStrength.scoreForBits(98), 4);
      expect(PasswordStrength.scoreForBits(10), 0);
    });

    test('weak reason names what is missing', () {
      expect(
        PasswordStrengthEstimator.estimate('kfzqmwht').weakReason,
        'Only 8 characters, no symbols or numbers',
      );
    });
  });

  group('PasswordGenerator', () {
    final gen = PasswordGenerator();

    test('passwords honour length and contain every enabled class', () {
      for (var i = 0; i < 50; i++) {
        final v = gen.password(const PasswordOptions(length: 12)).value;
        expect(v, hasLength(12));
        expect(v, matches(RegExp('[A-Z]')));
        expect(v, matches(RegExp('[a-z]')));
        expect(v, matches(RegExp('[0-9]')));
        expect(v.split('').any(PasswordGenerator.symbolChars.contains), isTrue);
      }
      expect(
        gen.password(const PasswordOptions(length: 200)).value,
        hasLength(64),
      );
      expect(
        gen.password(const PasswordOptions(length: 1)).value,
        hasLength(8),
      );
    });

    test('class switches and avoid-ambiguous restrict the pool', () {
      const digitsOnly = PasswordOptions(
        length: 30,
        upper: false,
        lower: false,
        symbols: false,
      );
      expect(gen.password(digitsOnly).value, matches(RegExp(r'^\d{30}$')));
      const noAmb = PasswordOptions(length: 64, avoidAmbiguous: true);
      for (var i = 0; i < 20; i++) {
        expect(gen.password(noAmb).value, isNot(matches(RegExp('[Il1O0o]'))));
      }
      final none = gen.password(
        const PasswordOptions(
          upper: false,
          lower: false,
          digits: false,
          symbols: false,
        ),
      );
      expect(none.value, matches(RegExp(r'^[a-z]+$')));
    });

    test('entropy = length × log2(pool)', () {
      final pool = 26 + 26 + 10 + PasswordGenerator.symbolChars.length;
      expect(
        PasswordGenerator.passwordEntropy(const PasswordOptions(length: 16)),
        closeTo(16 * math.log(pool) / math.ln2, 1e-9),
      );
      expect(
        PasswordGenerator.passwordEntropy(
          const PasswordOptions(
            length: 10,
            upper: false,
            symbols: false,
            lower: false,
          ),
        ),
        closeTo(10 * math.log(10) / math.ln2, 1e-9),
      );
      expect(PasswordGenerator.pinEntropy(6), closeTo(19.93, 0.01));
      expect(
        PasswordGenerator.passphraseEntropy(
          const PassphraseOptions(words: 5, includeNumber: false),
          7776,
        ),
        closeTo(64.62, 0.01),
      );
      expect(
        gen.password(const PasswordOptions(length: 16)).entropyBits,
        PasswordGenerator.passwordEntropy(const PasswordOptions(length: 16)),
      );
    });

    test('values differ between calls and toString is redacted', () {
      final a = gen.password(const PasswordOptions());
      expect(a.value, isNot(gen.password(const PasswordOptions()).value));
      expect(a.toString(), isNot(contains(a.value)));
    });

    test('EFF passphrases from the bundled wordlist', () {
      final list = EffWordlist.parse(
        File(EffWordlist.assetPath).readAsStringSync(),
      );
      expect(list.words, hasLength(7776));
      expect(list.words.first, 'abacus');
      final p = gen.passphrase(const PassphraseOptions(words: 6), list);
      final parts = p.value.split('-');
      expect(parts, hasLength(6));
      expect(parts.every((w) => w[0] == w[0].toUpperCase()), isTrue);
      expect(parts.where((w) => RegExp(r'\d$').hasMatch(w)), hasLength(1));
      expect(
        p.entropyBits,
        closeTo(6 * 12.925 + math.log(60) / math.ln2, 0.01),
      );

      final plain = gen.passphrase(
        const PassphraseOptions(
          words: 4,
          separator: ' ',
          capitalize: false,
          includeNumber: false,
        ),
        list,
      );
      final words = plain.value.split(' ');
      expect(words, hasLength(4));
      expect(words.every(list.words.contains), isTrue);
    });

    test('PINs', () {
      expect(gen.pin(6).value, matches(RegExp(r'^\d{6}$')));
      expect(gen.pin(2).value, hasLength(4));
    });
  });

  group('PinAttemptGuard', () {
    test('5 free attempts, then 30 s doubling up to 1 h', () {
      expect(PinAttemptGuard.backoffFor(4), isNull);
      expect(PinAttemptGuard.backoffFor(5), const Duration(seconds: 30));
      expect(PinAttemptGuard.backoffFor(6), const Duration(minutes: 1));
      expect(PinAttemptGuard.backoffFor(8), const Duration(minutes: 4));
      expect(PinAttemptGuard.backoffFor(30), const Duration(hours: 1));
    });

    test('persists failures and lock-out; reset clears', () async {
      final store = InMemoryVaultStorage();
      final guard = PinAttemptGuard(store, monotonic: () => Duration.zero);
      final t = DateTime(2026, 6, 1, 9);
      for (var i = 0; i < 4; i++) {
        expect((await guard.recordFailure(t)).isLockedOut(t), isFalse);
      }
      final fifth = await guard.recordFailure(t);
      expect(fifth.failed, 5);
      expect(fifth.isLockedOut(t), isTrue);
      expect(fifth.remaining(t), const Duration(seconds: 30));
      expect(fifth.isLockedOut(t.add(const Duration(seconds: 31))), isFalse);

      final reloaded = await PinAttemptGuard(store).load(t);
      expect(reloaded, fifth);
      await guard.reset();
      expect(await guard.load(t), PinAttemptState.initial);
    });
  });
}
