/// VaultCipher (AES-256-GCM, nonce ‖ ciphertext ‖ tag) + CryptoBytes +
/// VaultKey fingerprints.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/crypto_bytes.dart';
import 'package:focusflow/core/crypto/vault_cipher.dart';
import 'package:focusflow/core/crypto/vault_key.dart';

void main() {
  SecretKey key() => SecretKeyData(CryptoBytes.random(32));

  group('VaultCipher', () {
    test('round-trips and uses the nonce(12) ‖ ct ‖ mac(16) layout', () async {
      final k = key();
      final blob = await VaultCipher.sealString(k, 'hunter2 ✓');
      expect(blob.length, 12 + utf8.encode('hunter2 ✓').length + 16);
      expect(await VaultCipher.openString(k, blob), 'hunter2 ✓');
    });

    test('empty plaintext round-trips', () async {
      final k = key();
      final blob = await VaultCipher.seal(k, const []);
      expect(blob.length, 28);
      expect(await VaultCipher.open(k, blob), isEmpty);
    });

    test('every seal draws a fresh nonce', () async {
      final k = key();
      final nonces = <String>{};
      final blobs = <String>{};
      for (var i = 0; i < 200; i++) {
        final blob = await VaultCipher.sealString(k, 'same');
        nonces.add(CryptoBytes.toHex(blob.sublist(0, 12)));
        blobs.add(CryptoBytes.toHex(blob));
      }
      expect(nonces.length, 200);
      expect(blobs.length, 200);
    });

    test('tampering with any byte fails authentication', () async {
      final k = key();
      final blob = await VaultCipher.sealString(k, 'secret payload');
      for (final i in [0, 11, 12, blob.length - 17, blob.length - 1]) {
        final bad = Uint8List.fromList(blob)..[i] ^= 0x01;
        await expectLater(
          VaultCipher.open(k, bad),
          throwsA(isA<VaultCryptoException>()),
        );
      }
    });

    test('wrong key, wrong aad and truncated blobs are rejected', () async {
      final k = key();
      final blob = await VaultCipher.sealString(k, 'x', aad: VaultAad.item);
      await expectLater(
        VaultCipher.open(key(), blob, aad: VaultAad.item),
        throwsA(isA<VaultCryptoException>()),
      );
      await expectLater(
        VaultCipher.open(k, blob, aad: VaultAad.history),
        throwsA(isA<VaultCryptoException>()),
      );
      await expectLater(
        VaultCipher.open(k, blob.sublist(0, 20)),
        throwsA(isA<VaultCryptoException>()),
      );
      expect(await VaultCipher.openString(k, blob, aad: VaultAad.item), 'x');
    });
  });

  group('CryptoBytes', () {
    test('base32 round-trips arbitrary lengths', () {
      for (var n = 0; n < 40; n++) {
        final bytes = CryptoBytes.random(n);
        expect(
          CryptoBytes.fromBase32(CryptoBytes.toBase32(bytes)),
          bytes,
          reason: 'length $n',
        );
      }
      expect(CryptoBytes.toBase32(utf8.encode('foobar')), 'MZXW6YTBOI');
      expect(utf8.decode(CryptoBytes.fromBase32('mzxw-6ytb oi==')), 'foobar');
      expect(() => CryptoBytes.fromBase32('MZ1'), throwsFormatException);
    });

    test('constant-time compare and wipe', () {
      expect(CryptoBytes.constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(CryptoBytes.constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
      expect(CryptoBytes.constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
      final b = Uint8List.fromList([9, 9, 9]);
      CryptoBytes.wipe(b);
      expect(b, [0, 0, 0]);
    });

    test('random bytes differ', () {
      expect(CryptoBytes.random(32), isNot(CryptoBytes.random(32)));
    });
  });

  group('VaultKey', () {
    test('fingerprints are keyed, deterministic and redacted', () async {
      final a = await VaultKey.generate();
      final b = await VaultKey.fromBytes(a.exportBytes());
      final c = await VaultKey.generate();
      expect(a.fingerprint('pw'), b.fingerprint('pw'));
      expect(a.fingerprint('pw'), isNot(a.fingerprint('pw2')));
      expect(a.fingerprint('pw'), isNot(c.fingerprint('pw')));
      expect(a.fingerprint('pw'), hasLength(64));
      expect(a.toString(), isNot(contains(CryptoBytes.toHex(a.exportBytes()))));
    });

    test('destroy zeroes and disables the key', () async {
      final k = await VaultKey.generate();
      k.destroy();
      expect(k.isDestroyed, isTrue);
      expect(() => k.secretKey, throwsStateError);
      expect(() => k.fingerprint('x'), throwsStateError);
    });

    test('rejects keys that are not 256 bits', () {
      expect(() => VaultKey.fromBytes(List.filled(16, 1)), throwsArgumentError);
    });
  });
}
