/// Shared vault test setup: a TestHarness with in-memory key storage, a
/// fake biometric prompt, fast Argon2 and a recording clipboard / screen
/// protection, plus seeding helpers that encrypt real payloads.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/biometric_auth.dart';
import 'package:focusflow/core/crypto/pin_kdf.dart';
import 'package:focusflow/core/crypto/secure_clipboard.dart';
import 'package:focusflow/core/crypto/vault_secret_storage.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/vault/data/datasource/screen_protection.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_payload_codec.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';

class VaultTestBed {
  VaultTestBed._(this.h, this.bio, this.clipboard, this.protection);

  final TestHarness h;
  final FakeBiometricAuth bio;
  final List<String> clipboard;
  final FakeScreenProtection protection;

  static Future<VaultTestBed> create(
    DateTime now, {
    List<Override> overrides = const [],
  }) async {
    final bio = FakeBiometricAuth(result: false);
    final clipboard = <String>[];
    final protection = FakeScreenProtection();
    // Monotonic time for the PIN back-off follows the fake wall clock
    // (an honest device); tests of clock tampering override it.
    late final TestHarness h;
    final h0 = await TestHarness.create(
      now: now,
      overrides: [
        pinMonotonicClockProvider.overrideWithValue(
          () => h.clock.now().difference(now),
        ),
        vaultStorageProvider.overrideWithValue(InMemoryVaultStorage()),
        vaultBiometricStorageProvider.overrideWithValue(InMemoryVaultStorage()),
        vaultLegacyBiometricStorageProvider.overrideWithValue(null),
        // Keychain stand-in for "Encrypt backups" (re-keyed on PIN change).
        backupKeyStoreProvider.overrideWithValue(
          BackupKeyStore(MemorySecureStore()),
        ),
        biometricAuthProvider.overrideWithValue(bio),
        vaultKdfParamsProvider.overrideWithValue(KdfParams.testing),
        pinKdfProvider.overrideWithValue(const Argon2PinKdf(useIsolate: false)),
        secureClipboardProvider.overrideWithValue(
          SecureClipboard(writer: (t) async => clipboard.add(t)),
        ),
        screenProtectionProvider.overrideWithValue(protection),
        ...overrides,
      ],
    );
    h = h0;
    return VaultTestBed._(h, bio, clipboard, protection);
  }

  VaultSessionController get session => h.read(vaultSessionProvider.notifier);

  /// Creates the vault with [pin] (leaves it unlocked).
  Future<void> setUpVault([String pin = '123456']) async {
    await session.ready;
    await session.setUp(pin);
  }

  /// Saves one encrypted item (vault must be unlocked).
  Future<String> add(
    String title, {
    VaultItemType type = VaultItemType.login,
    String username = '',
    String password = '',
    String? iconKey,
    int? strength,
    int? breaches,
    bool favourite = false,
    String? folderId,
    String? cardNumber,
    DateTime? passwordUpdatedAt,
    bool hasTotp = false,
  }) async {
    final key = h.read(vaultSessionProvider).requireKey();
    final payload = VaultPayload(
      username: username,
      password: password,
      cardNumber: cardNumber ?? '',
    );
    final now = h.clock.now();
    return h
        .read(vaultRepositoryProvider)
        .save(
          VaultItemRecord(
            id: '',
            type: type,
            title: title,
            iconKey: iconKey,
            folderId: folderId,
            encryptedPayload: await VaultPayloadCodec.seal(key, payload),
            passwordStrength: password.isEmpty ? null : strength ?? 4,
            passwordFingerprint: password.isEmpty
                ? null
                : key.fingerprint(password),
            breachCount: breaches,
            isFavorite: favourite,
            passwordUpdatedAt: password.isEmpty
                ? null
                : passwordUpdatedAt ?? now,
            hasTotp: hasTotp,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// The mockup's data: 24 items (16 logins, 3 cards, 2 Wi-Fi, 3 notes),
  /// LinkedIn breached, Netflix reused, Figma weak, Google / GitHub
  /// favourites, folders Work · Personal · Finance.
  Future<void> seedMockup() async {
    final folders = h.read(foldersRepositoryProvider);
    for (final f in ['Work', 'Personal', 'Finance']) {
      await folders.create(ItemType.vault, f);
    }
    await add(
      'Google',
      username: 'asif.design@gmail.com',
      password: 'G00gle-strong-pass!',
      iconKey: 'google',
      favourite: true,
    );
    await add(
      'GitHub',
      username: 'asif-dev',
      password: 'gh-very-strong-1',
      iconKey: 'github',
      favourite: true,
    );
    await add(
      'LinkedIn',
      username: 'asif.iqbal@mgi.org',
      password: 'linked-pass-77',
      iconKey: 'linkedin',
      breaches: 3,
    );
    await add(
      'Netflix',
      username: 'family@home.net',
      password: 'shared-family-pw',
      iconKey: 'netflix',
    );
    await add(
      'Dutch-Bangla Bank',
      username: 'asif_iqbal88',
      password: 'dbbl-strong-pass',
      iconKey: 'bank',
    );
    await add(
      'Figma',
      username: 'asif.design@gmail.com',
      password: 'figma1',
      iconKey: 'figma',
      strength: 1,
    );
    // Ten more logins after "N" so the six above lead the A–Z list.
    for (final t in [
      'Outlook',
      'PayPal',
      'Reddit',
      'Slack',
      'Spotify',
      'Trello',
      'Uber',
      'Vercel',
      'Wise',
      'Zoom',
    ]) {
      await add(
        t,
        username: 'asif@example.com',
        password: t == 'Spotify' ? 'shared-family-pw' : 'pw-$t-strong',
      );
    }
    for (final t in ['Visa Platinum', 'Wise card', 'Zen card']) {
      await add(t, type: VaultItemType.card, cardNumber: '4242 4242 4242 4242');
    }
    for (final t in ['Office Wi-Fi', 'Home Wi-Fi']) {
      await add(t, type: VaultItemType.wifi, password: 'wifi-$t');
    }
    for (final t in ['Passport', 'Recovery codes', 'Server keys']) {
      await add(t, type: VaultItemType.secureNote);
    }
  }
}

/// Unmounts the app and stops vault timers so no fake timer is pending.
Future<void> tearDownVault(WidgetTester tester, VaultTestBed bed) async {
  await bed.session.lock();
  await tester.pumpWidget(const SizedBox());
  // Two frames: auto-dispose providers (2FA ticker, countdown) are disposed
  // on the frame after their last listener left.
  await tester.pump();
  await tester.pump();
}

/// Map-backed [SecureStore] (the real one needs the platform keychain).
class MemorySecureStore extends SecureStore {
  MemorySecureStore([Map<String, String>? values]) : values = {...?values};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
