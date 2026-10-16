/// CloudAccountController — Google / Apple sign-in with fake gateways:
/// the profile (never tokens) goes to the keychain, Settings' account mode
/// follows, cancel is not an error, sign-out forgets the profile.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/account_store.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/cloud_account_controller.dart';
import 'package:focusflow/core/sync/google_account.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../helpers/test_container.dart';
import 'sync_fixtures.dart';
import 'drive_fakes.dart';

void main() {
  late MemorySecureStore secure;
  late FakeGoogleAuth google;
  late FakeAppleAuth apple;

  Future<TestHarness> harness({
    GoogleConfig config = const ConfiguredGoogle(),
  }) async {
    final h = await TestHarness.create(
      now: syncNow,
      overrides: [
        secureStoreProvider.overrideWithValue(secure),
        googleConfigProvider.overrideWithValue(config),
        googleAuthGatewayProvider.overrideWithValue(google),
        appleAuthGatewayProvider.overrideWithValue(apple),
      ],
    );
    addTearDown(h.dispose);
    return h;
  }

  setUp(() {
    secure = MemorySecureStore();
    google = FakeGoogleAuth();
    apple = FakeAppleAuth();
  });

  test('Google is unavailable without client ids', () async {
    final h = await harness(config: const GoogleConfig());
    final c = h.read(cloudAccountControllerProvider);
    expect(c.googleAvailable, isFalse);
    await expectLater(c.signInWithGoogle(), throwsA(isA<CloudAuthException>()));
  });

  test(
    'Google sign-in stores the profile and switches the account mode',
    () async {
      final h = await harness();
      final account = await h
          .read(cloudAccountControllerProvider)
          .signInWithGoogle();
      expect(account?.email, 'sam@example.com');
      expect(account?.hasDrive, isTrue);
      expect(h.read(cloudAccountProvider)?.email, 'sam@example.com');
      expect(h.read(settingsProvider).accountMode, AccountMode.google);
      expect(h.read(settingsProvider).displayName, 'Sam Lee');
      final stored = secure.values[AccountStore.storageKey]!;
      expect(AccountStore.decode(stored)?.email, 'sam@example.com');
      expect(stored.toLowerCase(), isNot(contains('token')));
    },
  );

  test('cancelling Google sign-in is not an error', () async {
    google.profile = null;
    final h = await harness();
    expect(
      await h.read(cloudAccountControllerProvider).signInWithGoogle(),
      isNull,
    );
    expect(h.read(cloudAccountProvider), isNull);
    expect(secure.values, isEmpty);
  });

  test('Apple keeps the email it only shares the first time', () async {
    final h = await harness();
    final c = h.read(cloudAccountControllerProvider);
    apple.result = (email: 'me@icloud.com', name: 'Sam Lee', userId: 'u1');
    await c.signInWithApple();
    apple.result = (email: null, name: null, userId: 'u1');
    final again = await c.signInWithApple();
    expect(again?.email, 'me@icloud.com');
    expect(again?.hasDrive, isFalse);
    expect(h.read(settingsProvider).accountMode, AccountMode.apple);
  });

  test('a stored profile is loaded at start; sign-out forgets it', () async {
    secure.values[AccountStore.storageKey] = AccountStore.encode(
      const CloudAccount(provider: CloudProvider.google, email: 'a@b.co'),
    );
    final h = await harness();
    expect(h.read(cloudAccountProvider), isNull); // still loading
    await h.read(cloudAccountProvider.notifier).loaded;
    expect(h.read(cloudAccountProvider)?.email, 'a@b.co');

    await h.read(cloudAccountControllerProvider).signOut(revoke: true);
    expect(h.read(cloudAccountProvider), isNull);
    expect(secure.values, isEmpty);
    expect(google.signOuts, [true]);
    expect(h.read(settingsProvider).accountMode, AccountMode.offline);
  });

  test('AccountStore ignores anything that is not a profile', () {
    expect(AccountStore.decode('not json'), isNull);
    expect(AccountStore.decode('{"provider":"dropbox","email":"x"}'), isNull);
  });
}
