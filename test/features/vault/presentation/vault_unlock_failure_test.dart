/// "The PIN keeps verifying": whatever goes wrong while a PIN is checked —
/// the KDF throws, the phone is out of memory — the session reports a
/// failure WITHOUT counting a wrong PIN, the pad leaves "busy" with a
/// message, and the next (working) attempt opens the vault. Repeated
/// failures never reach a lock-out or the "wipe after failed attempts"
/// erase.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/argon2_runner.dart';
import 'package:focusflow/core/crypto/pin_kdf.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_pin_pad_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../vault_test_helpers.dart';

/// Real (cheap) Argon2 until [broken] is set.
class FlakyKdf implements PinKdf {
  bool broken = false;
  Object error = const Argon2Failure('timed out');

  @override
  Future<SecretKey> deriveKek(String pin, Uint8List salt, KdfParams params) {
    if (broken) throw error;
    return const Argon2PinKdf(useIsolate: false).deriveKek(pin, salt, params);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VaultTestBed bed;
  late FlakyKdf kdf;

  setUp(() async {
    kdf = FlakyKdf();
    bed = await VaultTestBed.create(
      DateTime(2026, 6, 13, 9),
      overrides: [pinKdfProvider.overrideWithValue(kdf)],
    );
    await bed.setUpVault('482916');
    await bed.session.lock();
  });

  tearDown(() => bed.h.dispose());

  test('a check that cannot run is "failed", not a wrong PIN', () async {
    kdf.broken = true;
    for (var i = 0; i < 12; i++) {
      expect(
        await bed.session.unlockWithPin('482916'),
        UnlockResult.failed,
        reason: 'attempt $i',
      );
    }
    final s = bed.h.read(vaultSessionProvider);
    expect(s.attempts.failed, 0);
    expect(s.attempts.isLockedOut(bed.h.clock.now()), isFalse);
    expect(s.isUnlocked, isFalse);

    // The phone recovers: the right PIN opens the vault straight away.
    kdf.broken = false;
    expect(await bed.session.unlockWithPin('482916'), UnlockResult.success);
  });

  test('wrong PINs still count, and failures do not erase them', () async {
    expect(await bed.session.unlockWithPin('000000'), UnlockResult.wrongPin);
    kdf.broken = true;
    expect(await bed.session.unlockWithPin('482916'), UnlockResult.failed);
    expect(bed.h.read(vaultSessionProvider).attempts.failed, 1);
    kdf.broken = false;
    expect(await bed.session.unlockWithPin('482916'), UnlockResult.success);
  });

  test(
    'the erase-after-failures setting is never triggered by failures',
    () async {
      await bed.h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(wipeAfterFailedAttempts: true));
      kdf.broken = true;
      for (var i = 0; i < 15; i++) {
        await bed.session.unlockWithPin('482916');
      }
      kdf.broken = false;
      expect(await bed.session.unlockWithPin('482916'), UnlockResult.success);
    },
  );

  test('verifyPin reports a failed check the same way', () async {
    kdf.broken = true;
    expect(await bed.session.verifyPin('482916'), UnlockResult.failed);
    expect(bed.h.read(vaultSessionProvider).attempts.failed, 0);
  });

  test('the pad leaves "busy" after an exception and then works', () async {
    kdf.broken = true;
    kdf.error = StateError('Segment processing timeout');
    final pad = bed.h.read(vaultPinPadProvider.notifier);
    for (final d in '482916'.split('')) {
      await pad.input(d);
    }
    final s = bed.h.read(vaultPinPadProvider);
    expect(s.busy, isFalse);
    expect(s.length, 0);
    expect(s.message, contains("Couldn't check the PIN"));
    expect(s.errorTick, greaterThan(0));

    kdf.broken = false;
    for (final d in '482916'.split('')) {
      await pad.input(d);
    }
    // On success the pad stays "busy" while the view switches away.
    expect(bed.h.read(vaultSessionProvider).isUnlocked, isTrue);
  });

  test('the pad survives a failing set-up on a new vault', () async {
    final fresh = await VaultTestBed.create(
      DateTime(2026, 6, 13, 9),
      overrides: [pinKdfProvider.overrideWithValue(kdf)],
    );
    addTearDown(fresh.h.dispose);
    await fresh.session.ready;
    kdf.broken = true;
    final pad = fresh.h.read(vaultPinPadProvider.notifier);
    for (final d in '482916482916'.split('')) {
      await pad.input(d);
    }
    final s = fresh.h.read(vaultPinPadProvider);
    expect(s.busy, isFalse);
    expect(s.step, VaultPadStep.create);
    expect(s.message, contains("Couldn't set up"));
  });
}
