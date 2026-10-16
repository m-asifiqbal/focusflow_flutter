/// Security hardening of core/crypto + backup key: unreadable key bundle
/// is not "absent", PIN reset repairs it, weak PINs, two-phase recovery
/// codes, OS-gated biometric copy + legacy migration, monotonic PIN
/// back-off, TOTP 7 digits, persisted clipboard clear, backup re-key.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/pin_attempt_guard.dart';
import 'package:focusflow/core/crypto/pin_kdf.dart';
import 'package:focusflow/core/crypto/secure_clipboard.dart';
import 'package:focusflow/core/crypto/totp.dart';
import 'package:focusflow/core/crypto/vault_cipher.dart';
import 'package:focusflow/core/crypto/vault_key_manager.dart';
import 'package:focusflow/core/crypto/vault_secret_storage.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';

import '../../features/vault/vault_test_helpers.dart' show MemorySecureStore;

void main() {
  late InMemoryVaultStorage store;

  VaultKeyManager manager({
    VaultSecretStorage? bio,
    VaultSecretStorage? legacy,
  }) => VaultKeyManager(
    storage: store,
    biometricStorage: bio ?? InMemoryVaultStorage(),
    legacyBiometricStorage: legacy,
    kdf: const Argon2PinKdf(useIsolate: false),
    targetParams: KdfParams.testing,
  );

  setUp(() => store = InMemoryVaultStorage());

  group('key bundle status', () {
    test('a corrupt bundle is unreadable, never "not set up"', () async {
      final m = manager();
      expect(await m.status(), VaultKeyStatus.absent);
      await m.setUp('582914');
      expect(await m.status(), VaultKeyStatus.ready);

      store.values[VaultKeyManager.bundleKey] = '{"v":1,"kdf":'; // damaged
      expect(await m.status(), VaultKeyStatus.unreadable);
      expect(await m.isSetUp(), isTrue);
      await expectLater(m.setUp('582914'), throwsStateError);
      await expectLater(
        m.unlockWithPin('582914'),
        throwsA(isA<VaultKeyUnreadableException>()),
      );
      expect(await m.exportBundle(), isNull);
    });

    test('recovery code + resetPin repairs an unreadable bundle', () async {
      final m = manager();
      final key = await m.setUp('582914');
      final blob = await VaultCipher.sealString(key.secretKey, 'secret');
      final kid = await m.keyId();
      final code = await m.createRecoveryCode(key);
      final raw = store.values[VaultKeyManager.bundleKey]!;
      // Keep the key id readable, break the wrapped key's structure.
      store.values[VaultKeyManager.bundleKey] = jsonEncode({
        'kid': kid,
        'dek': 42,
      });
      expect(raw, isNot(store.values[VaultKeyManager.bundleKey]));

      final recovered = await m.unlockWithRecoveryCode(code);
      expect(recovered, isNotNull);
      await m.resetPin(recovered!, '730461');
      expect(await m.status(), VaultKeyStatus.ready);
      expect(await m.keyId(), kid, reason: 'backups still match this key');
      final again = await m.unlockWithPin('730461');
      expect(await VaultCipher.openString(again!.secretKey, blob), 'secret');
    });
  });

  test('weak PINs are recognised', () {
    for (final pin in [
      '000000',
      '111111',
      '123456',
      '654321',
      '890123',
      '987654',
      '121212',
      '123123',
    ]) {
      expect(VaultKeyManager.weakPinReason(pin), isNotNull, reason: pin);
    }
    for (final pin in ['582914', '246810', '730461', '193748']) {
      expect(VaultKeyManager.weakPinReason(pin), isNull, reason: pin);
    }
    expect(VaultKeyManager.weakPinReason('12345'), isNotNull);
  });

  test('recovery code is two-phase: old code works until commit', () async {
    final m = manager();
    final key = await m.setUp('582914');
    final oldCode = await m.createRecoveryCode(key);
    final pending = await m.prepareRecoveryCode(key);
    expect(pending.toString(), isNot(contains(pending.code)));
    expect(await m.unlockWithRecoveryCode(oldCode), isNotNull);
    expect(await m.unlockWithRecoveryCode(pending.code), isNull);

    await m.commitRecoveryCode(pending);
    expect(await m.unlockWithRecoveryCode(oldCode), isNull);
    expect(await m.unlockWithRecoveryCode(pending.code), isNotNull);
  });

  group('biometric copy', () {
    test('OS-gated copy: marker only, read is the prompt, cancel keeps '
        'it', () async {
      final gated = FakeOsGatedVaultStorage();
      final m = manager(bio: gated);
      final key = await m.setUp('582914');
      expect(await m.hasBiometricCopy(), isFalse);
      expect(await m.enableBiometrics(key), isTrue);
      expect(store.values[VaultKeyManager.biometricMarkerKey], '1');
      expect(await m.hasBiometricCopy(), isTrue);
      expect(gated.prompts, 0, reason: 'existence check never prompts');
      expect(await m.biometricReadNeedsAppGate(), isFalse);

      final read = await m.readBiometricCopy();
      expect(read.status, BiometricCopyStatus.unlocked);
      expect(read.key!.exportBytes(), key.exportBytes());
      expect(gated.prompts, 1);

      gated.allow = false;
      expect(
        (await m.readBiometricCopy()).status,
        BiometricCopyStatus.cancelled,
      );
      expect(gated.values, contains(VaultKeyManager.biometricKey));

      await m.disableBiometrics();
      expect(gated.values, isEmpty);
      expect(store.values, isNot(contains(VaultKeyManager.biometricMarkerKey)));
    });

    test('OS refusal stores nothing', () async {
      final gated = FakeOsGatedVaultStorage(writePrompts: true)
        ..failWrites = true;
      final m = manager(bio: gated);
      final key = await m.setUp('582914');
      expect(await m.enableBiometrics(key), isFalse);
      expect(await m.hasBiometricCopy(), isFalse);
      expect(m.biometricWritePrompts, isTrue);
    });

    test('a legacy app-gated copy still unlocks, then migrates', () async {
      final gated = FakeOsGatedVaultStorage();
      final legacy = InMemoryVaultStorage();
      final m = manager(bio: gated, legacy: legacy);
      final key = await m.setUp('582914');
      // As written by older versions.
      await legacy.write(
        VaultKeyManager.biometricKey,
        base64Encode(key.exportBytes()),
      );
      expect(await m.hasBiometricCopy(), isTrue);
      expect(await m.biometricReadNeedsAppGate(), isTrue);
      final read = await m.readBiometricCopy();
      expect(read.status, BiometricCopyStatus.unlocked);
      expect(gated.prompts, 0);

      expect(await m.enableBiometrics(read.key!), isTrue);
      expect(legacy.values, isEmpty, reason: 'legacy copy deleted');
      expect(await m.biometricReadNeedsAppGate(), isFalse);
    });
  });

  group('PinAttemptGuard (monotonic)', () {
    final t = DateTime(2026, 6, 1, 9);

    test('moving the clock forward does not end a lock-out', () async {
      var mono = Duration.zero;
      final guard = PinAttemptGuard(store, monotonic: () => mono);
      for (var i = 0; i < 5; i++) {
        await guard.recordAttempt(t);
      }
      expect((await guard.load(t)).isLockedOut(t), isTrue);
      final later = t.add(const Duration(days: 1)); // clock moved forward
      expect((await guard.load(later)).isLockedOut(later), isTrue);
      mono = const Duration(seconds: 31); // real time while running
      expect((await guard.load(later)).isLockedOut(later), isFalse);
    });

    test('moving the clock backwards does not extend it forever', () async {
      var mono = Duration.zero;
      final guard = PinAttemptGuard(store, monotonic: () => mono);
      for (var i = 0; i < 5; i++) {
        await guard.recordAttempt(t);
      }
      final earlier = t.subtract(const Duration(days: 30));
      final s = await guard.load(earlier);
      expect(s.isLockedOut(earlier), isTrue);
      expect(s.remaining(earlier), const Duration(seconds: 30));
      mono = const Duration(seconds: 31);
      final after = earlier.add(const Duration(seconds: 31));
      expect((await guard.load(after)).isLockedOut(after), isFalse);
    });

    test('time while the app was not running does not count', () async {
      for (var i = 0; i < 5; i++) {
        await PinAttemptGuard(
          store,
          monotonic: () => Duration.zero,
        ).recordAttempt(t);
      }
      // "Relaunch" with a fresh process clock 1 h later on the wall clock.
      final relaunch = PinAttemptGuard(
        store,
        monotonic: () => const Duration(hours: 5),
      );
      final at = t.add(const Duration(hours: 1));
      expect((await relaunch.load(at)).isLockedOut(at), isTrue);
    });

    test('records from older versions keep their remaining time', () async {
      store.values[PinAttemptGuard.storageKey] = jsonEncode({
        'failed': 5,
        'until': t.add(const Duration(seconds: 20)).toIso8601String(),
      });
      final guard = PinAttemptGuard(store, monotonic: () => Duration.zero);
      final s = await guard.load(t);
      expect(s.failed, 5);
      expect(s.remaining(t), const Duration(seconds: 20));
    });
  });

  test('TOTP: 7-digit codes (RFC 6238 vector, SHA-1, T = 59 s)', () {
    final secret = base32Of('12345678901234567890');
    final c = TotpConfig.parse('otpauth://totp/X?secret=$secret&digits=7')!;
    expect(c.digits, 7);
    final code = c.codeAt(DateTime.fromMillisecondsSinceEpoch(59 * 1000));
    expect(code, '4287082'); // last 7 digits of 94287082
    expect(TotpConfig.format(code), '428 7082');
    expect(
      TotpConfig.parse('otpauth://totp/X?secret=$secret&digits=9')!.digits,
      6,
    );
  });

  group('SecureClipboard persistence', () {
    test('a cold start clears a secret whose deadline passed', () async {
      var now = DateTime(2026, 6, 1, 9);
      final writes = <String>[];
      final first = SecureClipboard(
        writer: (t) async => writes.add(t),
        now: () => now,
        store: store,
      );
      await first.copy('hunter2', clearAfter: const Duration(seconds: 30));
      final saved = store.values[SecureClipboard.storageKey]!;
      expect(saved, isNot(contains('hunter2')));
      first.dispose(); // the app is killed

      now = now.add(const Duration(minutes: 5));
      final second = SecureClipboard(
        writer: (t) async => writes.add(t),
        now: () => now,
        store: store,
      );
      await second.restorePending();
      expect(writes, ['hunter2', '']);
      expect(store.values, isNot(contains(SecureClipboard.storageKey)));
    });

    test('a cold start before the deadline re-arms the clear', () async {
      final now = DateTime(2026, 6, 1, 9);
      final writes = <String>[];
      final first = SecureClipboard(
        writer: (t) async => writes.add(t),
        now: () => now,
        store: store,
      );
      await first.copy('pw', clearAfter: const Duration(seconds: 30));
      first.dispose();
      final second = SecureClipboard(
        writer: (t) async => writes.add(t),
        now: () => now,
        store: store,
      );
      await second.restorePending();
      expect(second.clearDeadline, now.add(const Duration(seconds: 30)));
      await second.clearNow();
      expect(writes, ['pw', '']);
      second.dispose();
    });
  });

  test('BackupKeyStore.rekey: new PIN, same salt; no-op when off', () async {
    final keys = BackupKeyStore(MemorySecureStore());
    expect(await keys.rekey('730461'), isFalse);
    expect(await keys.hasKey(), isFalse);

    final params = BackupKdfParams.generate(memoryKiB: 64, iterations: 1);
    final old = await keys.enable('582914', params: params);
    expect(await keys.rekey('730461'), isTrue);
    final now = (await keys.current())!;
    expect(now.params, old.params, reason: 'shared salt / params kept');
    expect(now.keyBytes, isNot(old.keyBytes));
    final expected = await BackupCipher.deriveKey('730461', params);
    expect(now.keyBytes, expected.keyBytes);
  });
}

/// RFC 4648 base32 of an ASCII string (test vectors).
String base32Of(String ascii) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final bytes = ascii.codeUnits;
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      out.write(alphabet[(buffer >> (bits - 5)) & 31]);
      bits -= 5;
    }
  }
  if (bits > 0) out.write(alphabet[(buffer << (5 - bits)) & 31]);
  return out.toString();
}
