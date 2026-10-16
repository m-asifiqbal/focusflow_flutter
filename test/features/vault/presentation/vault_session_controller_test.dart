/// Vault session: set-up / unlock / lock, key only in memory while
/// unlocked, failed-PIN back-off + optional wipe, biometrics, auto-lock,
/// lock on background, PIN change, recovery, vaultStatusProvider.
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/biometric_auth.dart';
import 'package:focusflow/core/crypto/pin_kdf.dart';
import 'package:focusflow/core/crypto/secure_clipboard.dart';
import 'package:focusflow/core/crypto/vault_cipher.dart';
import 'package:focusflow/core/crypto/vault_key_manager.dart';
import 'package:focusflow/core/crypto/vault_secret_storage.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_pin_pad_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/test_container.dart';
import '../vault_test_helpers.dart';

class _BrokenStorage implements VaultSecretStorage {
  @override
  Future<String?> read(String key) async => throw Exception('no keychain');
  @override
  Future<void> write(String key, String value) async => throw Exception();
  @override
  Future<void> delete(String key) async => throw Exception();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestHarness h;
  late InMemoryVaultStorage store;
  late InMemoryVaultStorage bioStore;
  late InMemoryVaultStorage legacyStore;
  late MemorySecureStore backupSecure;
  late FakeBiometricAuth bio;
  late List<String> clipboard;
  final t0 = DateTime(2026, 6, 13, 9);

  Future<void> create({VaultSecretStorage? storage}) async {
    backupSecure = MemorySecureStore();
    store = InMemoryVaultStorage();
    bioStore = InMemoryVaultStorage();
    legacyStore = InMemoryVaultStorage();
    bio = FakeBiometricAuth();
    clipboard = [];
    h = await TestHarness.create(
      now: t0,
      overrides: [
        // An honest monotonic clock: advances with the fake wall clock.
        pinMonotonicClockProvider.overrideWithValue(
          () => h.clock.now().difference(t0),
        ),
        vaultStorageProvider.overrideWithValue(storage ?? store),
        vaultBiometricStorageProvider.overrideWithValue(bioStore),
        vaultLegacyBiometricStorageProvider.overrideWithValue(legacyStore),
        backupKeyStoreProvider.overrideWithValue(BackupKeyStore(backupSecure)),
        biometricAuthProvider.overrideWithValue(bio),
        vaultKdfParamsProvider.overrideWithValue(KdfParams.testing),
        pinKdfProvider.overrideWithValue(const Argon2PinKdf(useIsolate: false)),
        secureClipboardProvider.overrideWithValue(
          SecureClipboard(writer: (t) async => clipboard.add(t)),
        ),
      ],
    );
  }

  VaultSessionController session() => h.read(vaultSessionProvider.notifier);
  VaultSessionState state() => h.read(vaultSessionProvider);

  Future<void> settings(AppSettings Function(AppSettings) change) =>
      h.read(settingsProvider.notifier).update(change);

  Future<void> setUpVault([String pin = '123456']) async {
    await session().ready;
    await session().setUp(pin);
  }

  void lifecycle(List<AppLifecycleState> states) {
    for (final s in states) {
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(s);
    }
  }

  setUp(() => create());
  tearDown(() => h.dispose());

  test('starts not set up; set-up unlocks; lock drops the key', () async {
    await session().ready;
    expect(state().phase, VaultPhase.notSetUp);
    expect(h.read(vaultStatusProvider), VaultStatus.notSetUp);

    await session().setUp('123456');
    expect(h.read(vaultStatusProvider), VaultStatus.unlocked);
    final key = state().requireKey();
    expect(state().biometricsReady, isTrue);
    expect(bioStore.values, contains(VaultKeyManager.biometricKey));
    expect(state().toString(), isNot(contains('key')));

    await h
        .read(secureClipboardProvider)
        .copy('pw', clearAfter: const Duration(seconds: 30));
    await session().lock();
    expect(h.read(vaultStatusProvider), VaultStatus.locked);
    expect(state().key, isNull);
    expect(key.isDestroyed, isTrue);
    expect(() => state().requireKey(), throwsA(isA<VaultLockedException>()));
    expect(clipboard, ['pw', '']);
  });

  test('wrong PINs back off after 5; right PIN resets the counter', () async {
    await setUpVault();
    await session().lock();
    for (var i = 1; i <= 4; i++) {
      expect(await session().unlockWithPin('000000'), UnlockResult.wrongPin);
      expect(state().attempts.failed, i);
    }
    expect(await session().unlockWithPin('000000'), UnlockResult.wrongPin);
    expect(state().attempts.isLockedOut(h.clock.now()), isTrue);
    expect(await session().unlockWithPin('123456'), UnlockResult.lockedOut);
    expect(state().isUnlocked, isFalse);

    h.clock.advance(const Duration(seconds: 31));
    expect(await session().unlockWithPin('123456'), UnlockResult.success);
    expect(state().attempts.failed, 0);
    expect(store.values, isNot(contains('vault.attempts')));
  });

  Future<UnlockResult> failTimes(int n) async {
    var last = UnlockResult.success;
    for (var i = 0; i < n; i++) {
      h.clock.advance(const Duration(hours: 2));
      last = await session().unlockWithPin('999999');
    }
    return last;
  }

  test('10th failure wipes the vault when the setting is on', () async {
    await settings((s) => s.copyWith(wipeAfterFailedAttempts: true));
    await setUpVault();
    final repo = h.read(vaultRepositoryProvider);
    final blob = await VaultCipher.sealString(
      state().requireKey().secretKey,
      's',
    );
    await repo.save(
      VaultItemRecord(
        id: '',
        type: VaultItemType.login,
        title: 'Bank',
        encryptedPayload: Uint8List.fromList(blob),
        createdAt: t0,
        updatedAt: t0,
      ),
    );
    await session().lock();

    expect(await failTimes(9), UnlockResult.wrongPin);
    expect(await failTimes(1), UnlockResult.wiped);
    expect(h.read(vaultStatusProvider), VaultStatus.notSetUp);
    expect(store.values, isEmpty);
    expect(bioStore.values, isEmpty);
    expect(await repo.allItemIds(), isEmpty);
    // Local-only: the wipe must not sync to the backup / other devices.
    final tombs = await h.db
        .customSelect("SELECT * FROM tombstones WHERE entity = 'vault'")
        .get();
    expect(tombs, isEmpty);
  });

  test('without the wipe setting, failures never erase', () async {
    await setUpVault();
    await session().lock();
    expect(await failTimes(12), UnlockResult.wrongPin);
    expect(state().phase, VaultPhase.locked);
    h.clock.advance(const Duration(hours: 2));
    expect(await session().unlockWithPin('123456'), UnlockResult.success);
  });

  test('biometric unlock, cancel, and turning the setting off', () async {
    await setUpVault();
    await session().lock();
    expect(await session().unlockWithBiometrics(), UnlockResult.success);
    expect(bio.prompts, 1);

    await session().lock();
    bio.result = false;
    expect(await session().unlockWithBiometrics(), UnlockResult.cancelled);

    await settings((s) => s.copyWith(vaultBiometrics: false));
    await pumpEventQueue();
    expect(bioStore.values, isEmpty);
    expect(state().biometricsReady, isFalse);
    expect(await session().unlockWithBiometrics(), UnlockResult.unavailable);
  });

  test('auto-lock after the configured idle time; 0 = no timer', () async {
    await setUpVault();
    expect(session().autoLockScheduled, isTrue);
    h.clock.advance(const Duration(minutes: 4));
    session().touch();
    h.clock.advance(const Duration(minutes: 4));
    await session().checkAutoLock();
    expect(state().isUnlocked, isTrue);
    h.clock.advance(const Duration(minutes: 1));
    await session().checkAutoLock();
    expect(state().isUnlocked, isFalse);

    await settings((s) => s.copyWith(vaultAutoLockMinutes: 0));
    await session().unlockWithPin('123456');
    expect(session().autoLockScheduled, isFalse);
  });

  test('locks when the app goes to the background (setting)', () async {
    await setUpVault();
    lifecycle([AppLifecycleState.resumed, AppLifecycleState.inactive]);
    expect(state().isUnlocked, isTrue, reason: 'inactive ≠ background');
    await session().keepUnlockedDuring(() async {
      lifecycle([AppLifecycleState.hidden]);
      lifecycle([AppLifecycleState.inactive]);
    });
    expect(state().isUnlocked, isTrue, reason: 'held for a system picker');
    lifecycle([AppLifecycleState.hidden]);
    await pumpEventQueue();
    expect(state().isUnlocked, isFalse);
    lifecycle([AppLifecycleState.inactive, AppLifecycleState.resumed]);

    await settings((s) => s.copyWith(vaultLockOnBackground: false));
    await session().unlockWithPin('123456');
    lifecycle([AppLifecycleState.inactive, AppLifecycleState.hidden]);
    await pumpEventQueue();
    expect(state().isUnlocked, isTrue);
    lifecycle([AppLifecycleState.inactive, AppLifecycleState.resumed]);
  });

  test(
    'copy then switch app: background lock keeps the copied secret',
    () async {
      await setUpVault();
      await h
          .read(secureClipboardProvider)
          .copy('pw', clearAfter: const Duration(seconds: 30));
      lifecycle([AppLifecycleState.inactive, AppLifecycleState.hidden]);
      await pumpEventQueue();
      expect(state().isUnlocked, isFalse);
      expect(clipboard, ['pw'], reason: 'user is switching apps to paste');
      expect(h.read(secureClipboardProvider).clearDeadline, isNotNull);
      lifecycle([AppLifecycleState.inactive, AppLifecycleState.resumed]);
      // A manual lock still clears immediately.
      await session().unlockWithPin('123456');
      await session().lock();
      expect(clipboard, ['pw', '']);
    },
  );

  test(
    'change PIN: a lock between steps resets the pad, never hangs',
    () async {
      await setUpVault();
      final sub = h.container.listen(vaultPinPadProvider, (_, _) {});
      final pad = h.read(vaultPinPadProvider.notifier)
        ..startReauth(changePin: true);
      Future<void> type(String pin) async {
        for (final d in pin.split('')) {
          await pad.input(d);
        }
      }

      await type('123456');
      await type('582914');
      expect(h.read(vaultPinPadProvider).step, VaultPadStep.changeConfirm);
      await session().lock();
      await type('582914');
      var s = h.read(vaultPinPadProvider);
      expect(s.busy, isFalse);
      expect(s.step, VaultPadStep.verify);
      expect(s.message, 'The vault locked · try again');
      // Entering the current PIN unlocks again and the change goes through.
      await type('123456');
      expect(state().isUnlocked, isTrue);
      await type('582914');
      await type('582914');
      s = h.read(vaultPinPadProvider);
      expect(s.done, isTrue);
      sub.close();
    },
  );

  test('PIN change keeps the data key; recovery code resets the PIN', () async {
    await setUpVault('111111');
    final key = state().requireKey();
    final blob = await VaultCipher.sealString(key.secretKey, 'item');
    expect(
      await session().changePin('000000', '222222'),
      UnlockResult.wrongPin,
    );
    expect(await session().changePin('111111', '222222'), UnlockResult.success);
    final code = await session().createRecoveryCode();
    await session().lock();

    expect(await session().unlockWithPin('111111'), UnlockResult.wrongPin);
    expect(await session().unlockWithPin('222222'), UnlockResult.success);
    expect(
      await VaultCipher.openString(state().requireKey().secretKey, blob),
      'item',
    );
    await session().lock();

    expect(
      await session().unlockWithRecoveryCode('AAAA'),
      UnlockResult.wrongPin,
    );
    expect(await session().unlockWithRecoveryCode(code), UnlockResult.success);
    await session().resetPin('333333');
    await session().lock();
    expect(await session().unlockWithPin('333333'), UnlockResult.success);
  });

  test('missing secure storage degrades to "locked", never throws', () async {
    await h.dispose();
    await create(storage: _BrokenStorage());
    await session().ready;
    expect(h.read(vaultStatusProvider), VaultStatus.locked);
  });
}
