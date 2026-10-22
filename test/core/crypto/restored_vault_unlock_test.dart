/// A vault key that came with a restored backup carries the KDF cost chosen
/// on the OLD phone. On a slower / smaller phone that cost must not leave the
/// PIN "verifying" for ever: the first (slow) unlock re-wraps the key with
/// this phone's own calibrated cost, and an unlock that cannot run reports a
/// failure without counting a wrong PIN.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/argon2_runner.dart';
import 'package:focusflow/core/crypto/pin_attempt_guard.dart';
import 'package:focusflow/core/crypto/pin_kdf.dart';
import 'package:focusflow/core/crypto/vault_key_manager.dart';
import 'package:focusflow/core/crypto/vault_secret_storage.dart';

/// Stand-in KDF: instant, deterministic, and — when [delay] is set — "slow"
/// for every cost of at least [slowAboveKiB] (the heavy bundle AND the
/// calibration probe, like a slow phone would be).
class SlowPhoneKdf implements PinKdf {
  SlowPhoneKdf({this.slowAboveKiB = 1024, this.delay = Duration.zero});

  final int slowAboveKiB;
  final Duration delay;

  @override
  Future<SecretKey> deriveKek(
    String pin,
    Uint8List salt,
    KdfParams params,
  ) async {
    if (params.memoryKiB >= slowAboveKiB && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final hash = await Sha256().hash([...pin.codeUnits, ...salt]);
    return SecretKeyData(hash.bytes);
  }
}

class FailingKdf implements PinKdf {
  @override
  Future<SecretKey> deriveKek(String pin, Uint8List salt, KdfParams params) =>
      throw const Argon2Failure('out of memory');
}

void main() {
  const heavy = KdfParams(memoryKiB: 64 * 1024, iterations: 3);

  test(
    'a heavy restored bundle is re-wrapped lighter after a slow unlock',
    () async {
      // The old phone: fast, picks the strongest cost.
      final old = VaultKeyManager(
        storage: InMemoryVaultStorage(),
        biometricStorage: InMemoryVaultStorage(),
        kdf: SlowPhoneKdf(),
        targetParams: heavy,
      );
      await old.setUp('482916');
      expect(await old.storedParams(), heavy);
      final bundle = (await old.exportBundle())!;

      // The new phone: the same PIN-wrapped bundle arrives with a restore.
      final mine = VaultKeyManager(
        storage: InMemoryVaultStorage(),
        biometricStorage: InMemoryVaultStorage(),
        kdf: SlowPhoneKdf(delay: const Duration(milliseconds: 1700)),
        targetParams: heavy,
        calibrate: true,
      );
      expect(await mine.adoptBundle(bundle), isTrue);
      expect(await mine.storedParams(), heavy);

      // First unlock: slow (it has to be), but it works…
      expect(await mine.unlockWithPin('482916'), isNotNull);
      // …and the stored cost is now this phone's: lighter, not below the
      // floor.
      final after = (await mine.storedParams())!;
      expect(after.isWeakerThan(heavy), isTrue);
      expect(after.isWeakerThan(KdfParams.minimum), isFalse);
      // The same PIN still opens it, and the key id (backups) is unchanged.
      expect(await mine.unlockWithPin('482916'), isNotNull);
      expect(await mine.keyId(), bundle.keyId);
    },
  );

  test('a quick unlock leaves the stored cost alone', () async {
    final m = VaultKeyManager(
      storage: InMemoryVaultStorage(),
      biometricStorage: InMemoryVaultStorage(),
      kdf: SlowPhoneKdf(),
      targetParams: heavy,
      calibrate: true,
    );
    await m.setUp('482916');
    final before = await m.storedParams();
    expect(await m.unlockWithPin('482916'), isNotNull);
    expect(await m.storedParams(), before);
  });

  test(
    'a failing derivation throws (never "wrong PIN") and keeps the key',
    () async {
      final store = InMemoryVaultStorage();
      await VaultKeyManager(
        storage: store,
        biometricStorage: InMemoryVaultStorage(),
        kdf: SlowPhoneKdf(),
        targetParams: KdfParams.testing,
      ).setUp('482916');
      final broken = VaultKeyManager(
        storage: store,
        biometricStorage: InMemoryVaultStorage(),
        kdf: FailingKdf(),
        targetParams: KdfParams.testing,
      );
      await expectLater(
        broken.unlockWithPin('482916'),
        throwsA(isA<Argon2Failure>()),
      );
      expect(await broken.status(), VaultKeyStatus.ready);
    },
  );

  test('PinAttemptGuard.refund hands a counted attempt back', () async {
    final guard = PinAttemptGuard(
      InMemoryVaultStorage(),
      monotonic: () => Duration.zero,
    );
    final now = DateTime(2026, 6, 1, 9);
    for (var i = 0; i < 4; i++) {
      await guard.recordAttempt(now);
    }
    final before = await guard.load(now);
    expect(before.failed, 4);
    final counted = await guard.recordAttempt(now);
    expect(counted.failed, 5);
    await guard.refund(before, now);
    final after = await guard.load(now);
    expect(after.failed, 4);
    expect(after.isLockedOut(now), isFalse);

    // From zero the record simply disappears.
    await guard.reset();
    final zero = await guard.load(now);
    await guard.recordAttempt(now);
    await guard.refund(zero, now);
    expect((await guard.load(now)).failed, 0);
  });
}
