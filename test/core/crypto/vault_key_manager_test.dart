/// VaultKeyManager + PinKdf: envelope encryption (Argon2id KEK wraps a
/// random DEK), wrong PIN, PIN change re-wraps the DEK only, KDF params
/// stored + upgraded, biometric copy, recovery code, backup bundle, wipe.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/pin_kdf.dart';
import 'package:focusflow/core/crypto/vault_cipher.dart';
import 'package:focusflow/core/crypto/vault_key_manager.dart';
import 'package:focusflow/core/crypto/vault_secret_storage.dart';

/// Counts derivations; real Argon2id with test-cheap parameters.
class CountingKdf implements PinKdf {
  int calls = 0;

  @override
  Future<SecretKey> deriveKek(String pin, Uint8List salt, KdfParams params) {
    calls++;
    return const Argon2PinKdf(useIsolate: false).deriveKek(pin, salt, params);
  }
}

/// Instant, deterministic stand-in (SHA-256 of PIN + salt) that records
/// the parameters it was asked for (calibration tests).
class RecordingKdf implements PinKdf {
  final params = <KdfParams>[];

  @override
  Future<SecretKey> deriveKek(
    String pin,
    Uint8List salt,
    KdfParams params,
  ) async {
    this.params.add(params);
    final hash = await Sha256().hash([...pin.codeUnits, ...salt]);
    return SecretKeyData(hash.bytes);
  }
}

void main() {
  late InMemoryVaultStorage store;
  late InMemoryVaultStorage bio;
  late CountingKdf kdf;

  VaultKeyManager manager({KdfParams params = KdfParams.testing}) =>
      VaultKeyManager(
        storage: store,
        biometricStorage: bio,
        kdf: kdf,
        targetParams: params,
      );

  setUp(() {
    store = InMemoryVaultStorage();
    bio = InMemoryVaultStorage();
    kdf = CountingKdf();
  });

  Map<String, Object?> bundleJson() =>
      (jsonDecode(store.values[VaultKeyManager.bundleKey]!) as Map)
          .cast<String, Object?>();

  group('PinKdf', () {
    test(
      'Argon2id is deterministic per salt and differs across salts',
      () async {
        const kdf = Argon2PinKdf(useIsolate: false);
        final salt = Uint8List(16);
        final a = await kdf.deriveKek('123456', salt, KdfParams.testing);
        final b = await kdf.deriveKek('123456', salt, KdfParams.testing);
        final c = await kdf.deriveKek(
          '123456',
          Uint8List(16)..[0] = 1,
          KdfParams.testing,
        );
        final d = await kdf.deriveKek('123457', salt, KdfParams.testing);
        final bytes = await a.extractBytes();
        expect(bytes, hasLength(32));
        expect(await b.extractBytes(), bytes);
        expect(await c.extractBytes(), isNot(bytes));
        expect(await d.extractBytes(), isNot(bytes));
      },
    );

    test('runs on a background isolate', () async {
      final key = await const Argon2PinKdf().deriveKek(
        '000000',
        Uint8List(16),
        KdfParams.testing,
      );
      final inline = await const Argon2PinKdf(
        useIsolate: false,
      ).deriveKek('000000', Uint8List(16), KdfParams.testing);
      expect(await key.extractBytes(), await inline.extractBytes());
    });

    test('params serialise and compare', () {
      const p = KdfParams.recommended;
      expect(KdfParams.fromJson(p.toJson()), p);
      expect(p.memoryKiB, 64 * 1024);
      expect(KdfParams.testing.isWeakerThan(p), isTrue);
      expect(p.isWeakerThan(KdfParams.testing), isFalse);
      expect(
        () => KdfParams.fromJson({'alg': 'pbkdf2', 'm': 1, 't': 1}),
        throwsFormatException,
      );
    });
  });

  group('set-up and unlock', () {
    test('right PIN unwraps the same DEK; wrong PIN returns null', () async {
      final m = manager();
      expect(await m.isSetUp(), isFalse);
      final key = await m.setUp('123456');
      final blob = await VaultCipher.sealString(key.secretKey, 'secret');

      final again = await m.unlockWithPin('123456');
      expect(again, isNotNull);
      expect(again!.exportBytes(), key.exportBytes());
      expect(await VaultCipher.openString(again.secretKey, blob), 'secret');

      expect(await m.unlockWithPin('654321'), isNull);
      expect(await m.unlockWithPin('12345'), isNull);
      expect(await m.verifyPin('123456'), isTrue);
      expect(await m.verifyPin('000000'), isFalse);
    });

    test('stores params + salt + wrapped key, never the DEK or PIN', () async {
      final m = manager();
      final key = await m.setUp('123456');
      final json = bundleJson();
      expect(json['kdf'], KdfParams.testing.toJson());
      expect(base64Decode(json['salt']! as String), hasLength(16));
      expect(base64Decode(json['dek']! as String), hasLength(12 + 32 + 16));
      final raw = store.values.values.join();
      expect(raw, isNot(contains(base64Encode(key.exportBytes()))));
      expect(raw, isNot(contains('123456')));
      expect(await m.storedParams(), KdfParams.testing);
      expect(await m.keyId(), matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('rejects invalid PINs and double set-up', () async {
      final m = manager();
      expect(() => m.setUp('12ab56'), throwsArgumentError);
      await m.setUp('123456');
      expect(() => m.setUp('123456'), throwsStateError);
    });

    test('tampered wrapped key fails like a wrong PIN', () async {
      final m = manager();
      await m.setUp('123456');
      final json = bundleJson();
      final dek = base64Decode(json['dek']! as String)..[20] ^= 1;
      json['dek'] = base64Encode(dek);
      store.values[VaultKeyManager.bundleKey] = jsonEncode(json);
      expect(await m.unlockWithPin('123456'), isNull);
    });

    test('weaker stored params are upgraded after unlock', () async {
      await manager().setUp('123456');
      const stronger = KdfParams(memoryKiB: 128, iterations: 2);
      final m = manager(params: stronger);
      final key = await m.unlockWithPin('123456');
      expect(key, isNotNull);
      expect(await m.storedParams(), stronger);
      expect(
        (await m.unlockWithPin('123456'))!.exportBytes(),
        key!.exportBytes(),
      );
    });
  });

  group('PIN change', () {
    test(
      're-wraps the same DEK under a new salt; items stay readable',
      () async {
        final m = manager();
        final key = await m.setUp('111111');
        final item = await VaultCipher.sealString(key.secretKey, 'item');
        final oldSalt = bundleJson()['salt'];
        final keyId = await m.keyId();
        final oldWrap = bundleJson()['dek'];

        kdf.calls = 0;
        await m.changePin(key, '222222');
        expect(kdf.calls, 1, reason: 'one derivation for the new PIN only');
        expect(bundleJson()['salt'], isNot(oldSalt));
        expect(bundleJson()['dek'], isNot(oldWrap));
        expect(await m.keyId(), keyId, reason: 'same data key, same id');

        expect(await m.unlockWithPin('111111'), isNull);
        final reopened = await m.unlockWithPin('222222');
        expect(reopened!.exportBytes(), key.exportBytes());
        expect(await VaultCipher.openString(reopened.secretKey, item), 'item');
      },
    );
  });

  group('biometric copy', () {
    test('enable / unlock / disable', () async {
      final m = manager();
      final key = await m.setUp('123456');
      expect(await m.unlockWithBiometricCopy(), isNull);
      await m.enableBiometrics(key);
      expect(await m.hasBiometricCopy(), isTrue);
      expect(store.values.keys, isNot(contains(VaultKeyManager.biometricKey)));
      final viaBio = await m.unlockWithBiometricCopy();
      expect(viaBio!.exportBytes(), key.exportBytes());
      await m.disableBiometrics();
      expect(await m.unlockWithBiometricCopy(), isNull);
    });
  });

  group('recovery code', () {
    test('unlocks with the code; a new code invalidates the old', () async {
      final m = manager();
      final key = await m.setUp('123456');
      final code = await m.createRecoveryCode(key);
      expect(code, matches(RegExp(r'^([A-Z2-7]{4}-){7}[A-Z2-7]{4}$')));
      final viaCode = await m.unlockWithRecoveryCode(code.toLowerCase());
      expect(viaCode!.exportBytes(), key.exportBytes());

      final newer = await m.createRecoveryCode(key);
      expect(await m.unlockWithRecoveryCode(code), isNull);
      expect(await m.unlockWithRecoveryCode(newer), isNotNull);
      expect(await m.unlockWithRecoveryCode('AAAA-BBBB'), isNull);
    });
  });

  group('backup bundle and wipe', () {
    test('import accepts the bundle only with its PIN', () async {
      final m = manager();
      final key = await m.setUp('123456');
      final bundle = (await m.exportBundle())!;

      store = InMemoryVaultStorage();
      bio = InMemoryVaultStorage();
      final other = manager();
      expect(await other.importBundle(bundle, '000000'), isFalse);
      expect(await other.isSetUp(), isFalse);
      expect(await other.importBundle(bundle, '123456'), isTrue);
      expect(
        (await other.unlockWithPin('123456'))!.exportBytes(),
        key.exportBytes(),
      );
    });

    test('wipe removes every piece of key material', () async {
      final m = manager();
      final key = await m.setUp('123456');
      await m.enableBiometrics(key);
      await m.createRecoveryCode(key);
      await m.wipe();
      expect(store.values, isEmpty);
      expect(bio.values, isEmpty);
      expect(await m.isSetUp(), isFalse);
    });
  });

  group('KdfCalibration', () {
    test('picks the strongest candidate that fits ~0.75 s', () {
      KdfParams pick(int ms) =>
          KdfCalibration.choose(Duration(milliseconds: ms));
      expect(pick(60), KdfParams.recommended); // 6 x 60 = 360 ms
      expect(pick(150), const KdfParams(memoryKiB: 64 * 1024, iterations: 2));
      expect(pick(240), const KdfParams(memoryKiB: 48 * 1024, iterations: 2));
      expect(pick(350), KdfParams.minimum);
      expect(pick(2000), KdfParams.minimum); // never below the floor
      expect(
        KdfCalibration.choose(
          const Duration(milliseconds: 1),
          ceiling: const KdfParams(memoryKiB: 48 * 1024, iterations: 2),
        ),
        const KdfParams(memoryKiB: 48 * 1024, iterations: 2),
      );
    });

    test('a calibrating manager probes once, stores the choice and does not '
        'upgrade a bundle at or above the floor', () async {
      final rec = RecordingKdf();
      VaultKeyManager m() => VaultKeyManager(
        storage: store,
        biometricStorage: bio,
        kdf: rec,
        calibrate: true,
      );
      final first = m();
      await first.setUp('123456');
      expect(rec.params.first, KdfCalibration.probe);
      expect(await first.storedParams(), KdfParams.recommended);

      // A slow device's earlier choice (the floor) stays as it is.
      store.values.clear();
      final slow = VaultKeyManager(
        storage: store,
        biometricStorage: bio,
        kdf: rec,
        targetParams: KdfParams.minimum,
      );
      await slow.setUp('123456');
      final before = store.values[VaultKeyManager.bundleKey];
      expect(await m().unlockWithPin('123456'), isNotNull);
      expect(store.values[VaultKeyManager.bundleKey], before);
    });
  });
}
