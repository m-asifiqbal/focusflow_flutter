/// Vault session hardening: biometric copy follows the setting, OS-gated
/// reads + legacy migration, attempts counted before the check, monotonic
/// back-off, serialised PIN checks, unreadable key bundle, clipboard on
/// lock / cold start, forgot-PIN flow, two-phase recovery kit, backup
/// re-key on PIN change, item-bound AAD, weak PINs, masked previews.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/biometric_auth.dart';
import 'package:focusflow/core/crypto/pin_attempt_guard.dart';
import 'package:focusflow/core/crypto/pin_kdf.dart';
import 'package:focusflow/core/crypto/secure_clipboard.dart';
import 'package:focusflow/core/crypto/vault_cipher.dart';
import 'package:focusflow/core/crypto/vault_key_manager.dart';
import 'package:focusflow/core/crypto/vault_secret_storage.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/features/vault/data/datasource/recovery_kit_pdf.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_item_service.dart';
import 'package:focusflow/features/vault/domain/services/vault_payload_codec.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_pin_pad_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_security_settings_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/screens/vault_locked_view.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../vault_test_helpers.dart';

/// Real Argon2 (cheap params) that runs [onDerive] before each derivation
/// — i.e. while a PIN is being checked.
class _SpyKdf implements PinKdf {
  Future<void> Function()? onDerive;

  @override
  Future<SecretKey> deriveKek(String pin, Uint8List salt, KdfParams p) async {
    await onDerive?.call();
    return const Argon2PinKdf(useIsolate: false).deriveKek(pin, salt, p);
  }
}

class _FakeShare implements RecoveryKitShare {
  int shares = 0;

  @override
  Future<bool> share(Uint8List pdf, {required String fileName}) async {
    shares++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t0 = DateTime(2026, 6, 13, 9);
  late TestHarness h;
  late InMemoryVaultStorage store;
  late VaultSecretStorage bioStore;
  late InMemoryVaultStorage legacyStore;
  late FakeBiometricAuth bio;
  late MemorySecureStore backupSecure;
  late List<String> clipboard;
  late _SpyKdf kdf;
  late _FakeShare share;
  var mono = Duration.zero;
  var created = false;

  Future<void> create({
    VaultSecretStorage? biometric,
    bool honestClock = true,
    Map<String, String>? storeValues,
    AppSettings Function(AppSettings)? settings,
  }) async {
    store = InMemoryVaultStorage(storeValues);
    bioStore = biometric ?? InMemoryVaultStorage();
    legacyStore = InMemoryVaultStorage();
    bio = FakeBiometricAuth();
    backupSecure = MemorySecureStore();
    clipboard = [];
    kdf = _SpyKdf();
    share = _FakeShare();
    mono = Duration.zero;
    h = await TestHarness.create(
      now: t0,
      overrides: [
        pinMonotonicClockProvider.overrideWithValue(
          () => honestClock ? h.clock.now().difference(t0) : mono,
        ),
        vaultStorageProvider.overrideWithValue(store),
        vaultBiometricStorageProvider.overrideWithValue(bioStore),
        vaultLegacyBiometricStorageProvider.overrideWithValue(legacyStore),
        backupKeyStoreProvider.overrideWithValue(BackupKeyStore(backupSecure)),
        biometricAuthProvider.overrideWithValue(bio),
        vaultKdfParamsProvider.overrideWithValue(KdfParams.testing),
        pinKdfProvider.overrideWithValue(kdf),
        recoveryKitShareProvider.overrideWithValue(share),
        secureClipboardProvider.overrideWithValue(
          SecureClipboard(
            writer: (t) async => clipboard.add(t),
            now: () => h.clock.now(),
            store: store,
          ),
        ),
      ],
    );
    created = true;
    if (settings != null) {
      await h.read(settingsProvider.notifier).update(settings);
    }
  }

  VaultSessionController session() => h.read(vaultSessionProvider.notifier);
  VaultSessionState state() => h.read(vaultSessionProvider);
  VaultKeyManager keys() => h.read(vaultKeyManagerProvider);

  Future<void> setUpVault([String pin = '582914']) async {
    await session().ready;
    await session().setUp(pin);
  }

  Future<void> bioSetting(bool on) async {
    await h
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(vaultBiometrics: on));
    await pumpEventQueue();
  }

  tearDown(() async {
    if (!created) return;
    created = false;
    await h.dispose();
  });

  group('biometric copy follows the setting', () {
    test('off: never written; on: written; off again: deleted', () async {
      await create(settings: (s) => s.copyWith(vaultBiometrics: false));
      await setUpVault();
      expect((bioStore as InMemoryVaultStorage).values, isEmpty);
      expect(state().biometricsReady, isFalse);

      await bioSetting(true);
      expect(
        (bioStore as InMemoryVaultStorage).values,
        contains(VaultKeyManager.biometricKey),
      );
      expect(state().biometricsReady, isTrue);

      await legacyStore.write(VaultKeyManager.biometricKey, 'old');
      await bioSetting(false);
      expect((bioStore as InMemoryVaultStorage).values, isEmpty);
      expect(legacyStore.values, isEmpty);
      expect(state().biometricsReady, isFalse);
    });

    test('a stale copy is deleted on start when the setting is off', () async {
      await create(settings: (s) => s.copyWith(vaultBiometrics: false));
      await bioStore.write(VaultKeyManager.biometricKey, 'stale');
      await legacyStore.write(VaultKeyManager.biometricKey, 'stale');
      await session().ready;
      expect((bioStore as InMemoryVaultStorage).values, isEmpty);
      expect(legacyStore.values, isEmpty);
    });

    test('OS-gated: no app prompt; cancel keeps the copy; invalidated '
        'copy falls back to the PIN', () async {
      final gated = FakeOsGatedVaultStorage();
      await create(biometric: gated);
      await setUpVault();
      expect(store.values[VaultKeyManager.biometricMarkerKey], '1');
      await session().lock();

      expect(await session().unlockWithBiometrics(), UnlockResult.success);
      expect(bio.prompts, 0, reason: 'the keystore read is the prompt');
      expect(gated.prompts, 1);

      await session().lock();
      gated.allow = false;
      expect(await session().unlockWithBiometrics(), UnlockResult.cancelled);
      expect(gated.values, contains(VaultKeyManager.biometricKey));

      gated
        ..allow = true
        ..values.clear(); // re-enrolled fingerprint: OS dropped the item
      expect(await session().unlockWithBiometrics(), UnlockResult.unavailable);
      expect(state().biometricsReady, isFalse);
      expect(store.values, isNot(contains(VaultKeyManager.biometricMarkerKey)));
    });

    test('legacy copy: unlocks after local_auth, then migrates', () async {
      final gated = FakeOsGatedVaultStorage();
      await create(biometric: gated);
      await setUpVault();
      final raw = gated.values[VaultKeyManager.biometricKey]!;
      // Simulate an install from before OS gating.
      await keys().disableBiometrics();
      await legacyStore.write(VaultKeyManager.biometricKey, raw);
      await session().lock();
      await session().refresh();
      expect(state().biometricsReady, isTrue);

      expect(await session().unlockWithBiometrics(), UnlockResult.success);
      expect(bio.prompts, 1, reason: 'legacy copy is app-gated');
      expect(legacyStore.values, isEmpty);
      expect(gated.values, contains(VaultKeyManager.biometricKey));
      expect(await keys().biometricReadNeedsAppGate(), isFalse);
    });

    test('settings toggle reports an OS refusal', () async {
      final gated = FakeOsGatedVaultStorage(writePrompts: true);
      await create(
        biometric: gated,
        settings: (s) => s.copyWith(vaultBiometrics: false),
      );
      await setUpVault();
      gated.failWrites = true;
      final c = h.read(vaultSecuritySettingsControllerProvider);
      expect(await c.setBiometrics(true), isFalse);
      expect(h.read(settingsProvider).vaultBiometrics, isFalse);
      gated.failWrites = false;
      expect(await c.setBiometrics(true), isTrue);
      expect(h.read(settingsProvider).vaultBiometrics, isTrue);
    });

    test('unlockWithPin does not auto-enroll biometrics when copy is missing', () async {
      final gated = FakeOsGatedVaultStorage(writePrompts: true);
      await create(
        biometric: gated,
        settings: (s) => s.copyWith(vaultBiometrics: true),
      );
      await setUpVault();
      // Drop biometric copy to simulate recovered database without device-local biometric key
      await keys().disableBiometrics();
      await session().lock();
      await session().refresh();
      expect(await keys().hasBiometricCopy(), isFalse);

      // PIN unlock should succeed immediately without prompting or writing biometric copy
      expect(await session().unlockWithPin('582914'), UnlockResult.success);
      expect(state().isUnlocked, isTrue);
      expect(gated.values, isEmpty, reason: 'PIN unlock should never auto-enroll biometrics');
    });

    test('concurrent biometric and PIN unlock preserves active session key', () async {
      final gated = FakeOsGatedVaultStorage();
      await create(biometric: gated);
      await setUpVault();
      await session().lock();

      // Start biometric unlock but do not await immediately
      final bioUnlockFuture = session().unlockWithBiometrics();

      // User enters PIN while biometrics is in-flight
      final pinResult = await session().unlockWithPin('582914');
      expect(pinResult, UnlockResult.success);
      final activeKey = state().requireKey();
      expect(activeKey.isDestroyed, isFalse);

      // Complete biometrics
      final bioResult = await bioUnlockFuture;
      expect(bioResult, UnlockResult.success);

      // Active key must NOT have been destroyed or corrupted
      expect(state().isUnlocked, isTrue);
      expect(state().requireKey().isDestroyed, isFalse);
      expect(identical(state().requireKey(), activeKey), isTrue);
    });
  });

  group('PIN attempts', () {
    test('counted BEFORE the PIN is checked, reset on success', () async {
      await create();
      await setUpVault();
      await session().lock();
      final seen = <int>[];
      kdf.onDerive = () async =>
          seen.add((await h.read(pinAttemptGuardProvider).load(t0)).failed);
      expect(await session().unlockWithPin('582914'), UnlockResult.success);
      expect(seen, [1], reason: 'a kill during the check costs the attempt');
      expect(store.values, isNot(contains(PinAttemptGuard.storageKey)));
    });

    test('moving the clock forward does not end the back-off', () async {
      await create(honestClock: false);
      await setUpVault();
      await session().lock();
      for (var i = 0; i < 5; i++) {
        await session().unlockWithPin('000000');
      }
      h.clock.advance(const Duration(days: 2)); // user changes the clock
      expect(await session().unlockWithPin('582914'), UnlockResult.lockedOut);
      mono = const Duration(seconds: 31); // the lock-out really elapsed
      expect(await session().unlockWithPin('582914'), UnlockResult.success);
    });

    test('concurrent checks are serialised; no count is lost', () async {
      await create();
      await setUpVault();
      final results = await Future.wait([
        session().verifyPin('000000'),
        session().verifyPin('111111'),
        session().verifyPin('222222'),
      ]);
      expect(results, everyElement(UnlockResult.wrongPin));
      expect(state().attempts.failed, 3);
      expect((await h.read(pinAttemptGuardProvider).load(t0)).failed, 3);
    });
  });

  group('unreadable key bundle', () {
    test('is not "not set up": no set-up, no counted attempts', () async {
      await create(storeValues: {VaultKeyManager.bundleKey: 'garbage{'});
      await session().ready;
      expect(state().phase, VaultPhase.unreadable);
      await expectLater(session().setUp('582914'), throwsStateError);
      expect(await session().unlockWithPin('582914'), UnlockResult.unavailable);
      expect(store.values, isNot(contains(PinAttemptGuard.storageKey)));
      expect(store.values[VaultKeyManager.bundleKey], 'garbage{');
    });

    test('items without any key block set-up too', () async {
      await create();
      await h
          .read(vaultRepositoryProvider)
          .save(
            VaultItemRecord(
              id: '',
              type: VaultItemType.login,
              title: 'Orphan',
              encryptedPayload: Uint8List.fromList([1, 2, 3]),
              createdAt: t0,
              updatedAt: t0,
            ),
          );
      await session().ready;
      expect(state().phase, VaultPhase.unreadable);
      await expectLater(session().setUp('582914'), throwsStateError);
      // Only an explicit erase starts over.
      await session().wipe();
      expect(state().phase, VaultPhase.notSetUp);
      await session().setUp('582914');
      expect(state().isUnlocked, isTrue);
    });
  });

  group('clipboard', () {
    test('cleared on lock', () async {
      await create();
      await setUpVault();
      await h
          .read(secureClipboardProvider)
          .copy('pw', clearAfter: const Duration(seconds: 30));
      await session().lock();
      expect(clipboard, ['pw', '']);
    });

    test('cold start clears a secret that expired while killed', () async {
      final until = t0.subtract(const Duration(minutes: 1));
      await create(
        storeValues: {
          SecureClipboard.storageKey:
              '{"until":${until.millisecondsSinceEpoch},"sha256":"ab"}',
        },
      );
      await session().ready;
      expect(clipboard, ['']);
      expect(store.values, isNot(contains(SecureClipboard.storageKey)));
    });
  });

  test('forgot PIN: recovery unlock → forced new PIN → new code after '
      'confirmation', () async {
    await create();
    await setUpVault();
    final key = state().requireKey();
    final blob = await VaultCipher.sealString(key.secretKey, 'item');
    final oldCode = await session().createRecoveryCode();
    await session().lock();

    expect(
      await session().unlockWithRecoveryCode(oldCode),
      UnlockResult.success,
    );
    expect(state().pinResetRequired, isTrue);

    final sub = h.container.listen(vaultPinPadProvider, (_, _) {});
    final pad = h.read(vaultPinPadProvider.notifier)..startNewPin();
    Future<void> type(String pin) async {
      for (final d in pin.split('')) {
        await pad.input(d);
      }
    }

    await type('123456'); // too easy
    expect(h.read(vaultPinPadProvider).message, contains('sequence'));
    expect(h.read(vaultPinPadProvider).step, VaultPadStep.changeNew);
    await type('730461');
    await type('730461');
    expect(h.read(vaultPinPadProvider).done, isTrue);
    expect(state().pinResetRequired, isFalse);
    final newCode = session().pendingRecoveryCode!;
    sub.close();

    // Not committed yet: the used code still works, the new one not yet.
    expect(await keys().unlockWithRecoveryCode(oldCode), isNotNull);
    expect(await keys().unlockWithRecoveryCode(newCode), isNull);
    expect(await session().commitRecoveryCode(), isTrue);
    expect(await keys().unlockWithRecoveryCode(oldCode), isNull);
    expect(await keys().unlockWithRecoveryCode(newCode), isNotNull);

    await session().lock();
    expect(await session().unlockWithPin('582914'), UnlockResult.wrongPin);
    expect(await session().unlockWithPin('730461'), UnlockResult.success);
    expect(
      await VaultCipher.openString(state().requireKey().secretKey, blob),
      'item',
    );
  });

  test('recovery kit is two-phase (share, then confirm)', () async {
    await create();
    await setUpVault();
    final oldCode = await session().createRecoveryCode();
    final c = h.read(vaultSecuritySettingsControllerProvider);

    expect(await c.shareRecoveryKit(), isTrue);
    expect(share.shares, 1);
    expect(await keys().unlockWithRecoveryCode(oldCode), isNotNull);
    c.discardRecoveryKit();
    expect(await c.commitRecoveryKit(), isFalse);
    expect(await keys().unlockWithRecoveryCode(oldCode), isNotNull);

    expect(await c.shareRecoveryKit(), isTrue);
    final newCode = session().pendingRecoveryCode!;
    expect(await c.commitRecoveryKit(), isTrue);
    expect(await keys().unlockWithRecoveryCode(oldCode), isNull);
    expect(await keys().unlockWithRecoveryCode(newCode), isNotNull);
  });

  test('changing the PIN re-keys the backup encryption key', () async {
    await create();
    await setUpVault();
    final backup = h.read(backupKeyStoreProvider);
    final params = BackupKdfParams.generate(memoryKiB: 64, iterations: 1);
    await backup.enable('582914', params: params);

    expect(await session().changePin('582914', '730461'), UnlockResult.success);
    final now = (await backup.current())!;
    expect(now.params, params);
    expect(
      now.keyBytes,
      (await BackupCipher.deriveKey('730461', params)).keyBytes,
    );
  });

  test('payload AAD is bound to the item id; legacy blobs still open and '
      'are re-sealed on save', () async {
    await create();
    await setUpVault();
    final key = state().requireKey();
    final repo = h.read(vaultRepositoryProvider);
    final service = VaultItemService(repo, h.clock.now);
    const payload = VaultPayload(password: 'pw-1');
    const draft = VaultItemDraft(type: VaultItemType.login, title: 'Bank');

    final id = await service.save(key: key, draft: draft, payload: payload);
    final record = (await repo.getItem(id))!;
    expect(
      (await VaultPayloadCodec.open(
        key,
        record.encryptedPayload,
        itemId: id,
      )).password,
      'pw-1',
    );
    // Swapped onto another row it no longer opens.
    await expectLater(
      VaultPayloadCodec.open(key, record.encryptedPayload, itemId: 'other'),
      throwsA(isA<VaultCryptoException>()),
    );

    // A legacy (unbound) blob still opens …
    final legacy = await VaultPayloadCodec.seal(key, payload);
    expect(
      (await VaultPayloadCodec.open(key, legacy, itemId: id)).password,
      'pw-1',
    );
    // … and the next save writes the id-bound AAD.
    await repo.save(record.copyWith(encryptedPayload: legacy));
    final old = (await repo.getItem(id))!;
    await service.save(
      key: key,
      draft: draft,
      payload: payload,
      existing: old,
      previous: payload,
    );
    final resealed = (await repo.getItem(id))!.encryptedPayload;
    await expectLater(
      VaultCipher.open(key.secretKey, resealed, aad: VaultAad.item),
      throwsA(isA<VaultCryptoException>()),
    );
    expect(
      await VaultCipher.openString(
        key.secretKey,
        resealed,
        aad: VaultAad.itemFor(id),
      ),
      contains('pw-1'),
    );
  });

  test('weak PINs are refused when creating the vault', () async {
    await create();
    await session().ready;
    final sub = h.container.listen(vaultPinPadProvider, (_, _) {});
    final pad = h.read(vaultPinPadProvider.notifier);
    expect(h.read(vaultPinPadProvider).step, VaultPadStep.create);
    for (final d in '000000'.split('')) {
      await pad.input(d);
    }
    expect(h.read(vaultPinPadProvider).step, VaultPadStep.create);
    expect(h.read(vaultPinPadProvider).message, contains('choose another'));
    sub.close();
  });

  test('locked previews never show the title', () {
    final masked = maskedPreviewTitle('Dutch-Bangla Bank');
    expect(masked, isNot(contains('Dutch')));
    expect(masked.length, 12);
    expect(maskedPreviewTitle('X').length, 4);
  });

  testWidgets('forgot PIN on the lock screen ends with a new PIN and kit', (
    tester,
  ) async {
    final b = (await tester.runAsync(
      () => VaultTestBed.create(DateTime(2026, 6, 13, 9, 41)),
    ))!;
    addTearDown(() => tester.runAsync(b.h.dispose));
    late String code;
    await tester.runAsync(() async {
      await b.h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(vaultBiometrics: false));
      await b.setUpVault('582914');
      await b.add('Google', username: 'me', password: 'pw');
      code = await b.session.createRecoveryCode();
      await b.session.lock();
    });
    await pumpApp(tester, b.h, AppRoutes.vault);
    expect(find.text('Google'), findsNothing, reason: 'masked preview');
    await tester.tap(find.text('Forgot PIN?'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, code);
    await tester.tap(find.text('Unlock'));
    for (var i = 0; i < 3; i++) {
      await settle(tester);
    }
    expect(find.text('Set a new PIN'), findsOneWidget);
    for (final pin in ['730461', '730461']) {
      for (final d in pin.split('')) {
        await tester.tap(find.bySemanticsLabel(d).last);
        await tester.pump();
      }
      await settle(tester);
    }
    expect(find.text('Your new recovery code'), findsOneWidget);
    await tester.tap(find.text("I've saved it"));
    await settle(tester);
    expect(find.text('Your new recovery code'), findsNothing);
    await tester.runAsync(() async {
      final keys = b.h.read(vaultKeyManagerProvider);
      expect(await keys.unlockWithRecoveryCode(code), isNull);
      await b.session.lock();
      expect(await b.session.unlockWithPin('730461'), UnlockResult.success);
    });
    await tearDownVault(tester, b);
  });
}
