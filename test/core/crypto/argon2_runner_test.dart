/// Argon2Runner: the one way every PIN is stretched. It must give the SAME
/// bytes as the package's own Argon2id (existing vault bundles and backups
/// depend on it), refuse costs this app never writes (a restored bundle or
/// backup file is untrusted input), end within its time limit and report
/// failures as [Argon2Failure] — never hang, never take the app down.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/argon2_runner.dart';
import 'package:focusflow/core/crypto/pin_kdf.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';

void main() {
  final salt = List<int>.generate(16, (i) => i * 7 + 1);
  final pin = utf8.encode('482916');

  Future<List<int>> reference(int memoryKiB, int iterations) async {
    // The implementation used before: the package default, which spawns its
    // own worker isolate on a shared native buffer for this size.
    final key = await DartArgon2id(
      parallelism: 1,
      memory: memoryKiB,
      iterations: iterations,
      hashLength: 32,
    ).deriveKey(secretKey: SecretKey(pin), nonce: salt);
    return key.extractBytes();
  }

  group('same bytes as before (existing bundles / backups keep opening)', () {
    test('worker isolate == package default (8 MiB · 2)', () async {
      final mine = await Argon2Runner.derive(
        password: pin,
        salt: salt,
        memoryKiB: 8 * 1024,
        iterations: 2,
        inline: false,
      );
      expect(mine, await reference(8 * 1024, 2));
    });

    test('inline == worker == package default (tiny cost)', () async {
      final inline = await Argon2Runner.derive(
        password: pin,
        salt: salt,
        memoryKiB: 256,
        iterations: 2,
      );
      final worker = await Argon2Runner.derive(
        password: pin,
        salt: salt,
        memoryKiB: 256,
        iterations: 2,
        inline: false,
      );
      expect(inline, worker);
      expect(inline, await reference(256, 2));
    });

    test('Argon2PinKdf and BackupCipher go through it', () async {
      final kek = await const Argon2PinKdf().deriveKek(
        '482916',
        Uint8List.fromList(salt),
        KdfParams.testing,
      );
      expect(
        await kek.extractBytes(),
        await reference(KdfParams.testing.memoryKiB, 1),
      );
      final backup = await BackupCipher.deriveKey(
        '482916',
        BackupKdfParams(
          salt: Uint8List.fromList(salt),
          memoryKiB: 256,
          iterations: 1,
        ),
      );
      expect(backup.keyBytes, await reference(256, 1));
    });
  });

  group('untrusted cost', () {
    test('accept() allows what the app writes and nothing wild', () {
      bool ok(int m, int t, [int p = 1]) =>
          Argon2Runner.accept(memoryKiB: m, iterations: t, parallelism: p);
      expect(ok(64 * 1024, 3), isTrue); // KdfParams.recommended
      expect(ok(32 * 1024, 2), isTrue); // KdfParams.minimum
      expect(ok(19 * 1024, 2), isTrue); // backup default
      expect(ok(64, 1), isTrue); // tests
      expect(ok(4 * 1024 * 1024, 3), isFalse); // 4 GiB
      expect(ok(64 * 1024, 100), isFalse);
      expect(ok(64 * 1024, 0), isFalse);
      expect(ok(4, 1), isFalse);
      expect(ok(64 * 1024, 3, 99), isFalse);
    });

    test('derive refuses a huge cost without trying it', () async {
      final watch = Stopwatch()..start();
      await expectLater(
        Argon2Runner.derive(
          password: pin,
          salt: salt,
          memoryKiB: 4 * 1024 * 1024,
          iterations: 3,
        ),
        throwsA(isA<Argon2Failure>()),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test(
      'a stored bundle / a backup manifest with such a cost is rejected',
      () {
        expect(
          () => KdfParams.fromJson({
            'alg': 'argon2id',
            'm': 4 * 1024 * 1024,
            't': 3,
            'p': 1,
          }),
          throwsFormatException,
        );
        expect(
          KdfParams.fromJson(KdfParams.recommended.toJson()),
          KdfParams.recommended,
        );
        final manifest = BackupKdfParams.generate().toJson();
        expect(BackupKdfParams.fromJson(manifest).memoryKiB, 19 * 1024);
        expect(
          () => BackupKdfParams.fromJson({
            ...manifest,
            'memoryKiB': 4 * 1024 * 1024,
          }),
          throwsFormatException,
        );
        expect(
          () => BackupKdfParams.fromJson({...manifest, 'iterations': 500}),
          throwsFormatException,
        );
      },
    );
  });

  group('always ends', () {
    test('a derivation over its time limit fails and frees the worker', () {
      return expectLater(
        Argon2Runner.derive(
          password: pin,
          salt: salt,
          memoryKiB: 64 * 1024,
          iterations: 3,
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(
          isA<Argon2Failure>().having((e) => e.reason, 'reason', 'timed out'),
        ),
      );
    });

    test('the next derivation works after a timed-out one', () async {
      await expectLater(
        Argon2Runner.derive(
          password: pin,
          salt: salt,
          memoryKiB: 64 * 1024,
          iterations: 3,
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<Argon2Failure>()),
      );
      final again = await Argon2Runner.derive(
        password: pin,
        salt: salt,
        memoryKiB: 8 * 1024,
        iterations: 1,
        inline: false,
      );
      expect(again, hasLength(32));
    });
  });
}
