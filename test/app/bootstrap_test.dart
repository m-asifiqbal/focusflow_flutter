/// Bootstrap — a keychain failure on the database key shows a recovery
/// screen ("Can't unlock your data" + Try again) instead of a stuck
/// splash, and a new key is only ever made when none exists: a failed
/// read never replaces the key, a damaged value is kept aside.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/bootstrap.dart';
import 'package:focusflow/core/storage/secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/sync/drive_fakes.dart';

/// Keychain that fails reads (locked before first unlock) or writes.
class _Keychain extends MemorySecureStore {
  _Keychain({
    this.failRead = false,
    this.failWrite = false,
    Map<String, String>? values,
  }) : super(values);

  final bool failRead;
  final bool failWrite;

  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('locked');
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('read-only');
    return super.write(key, value);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('getOrCreateDatabaseKey', () {
    test('creates a key only when none exists', () async {
      final k = _Keychain();
      final key = await k.getOrCreateDatabaseKey();
      expect(key, hasLength(64));
      expect(k.values[SecureStore.databaseKey], key);
      expect(await k.getOrCreateDatabaseKey(), key);
    });

    test('a failed read throws and never writes a new key', () async {
      final k = _Keychain(failRead: true);
      await expectLater(
        k.getOrCreateDatabaseKey(),
        throwsA(isA<DatabaseKeyUnavailable>()),
      );
      expect(k.values, isEmpty);
    });

    test('a new key that cannot be saved is not used', () async {
      final k = _Keychain(failWrite: true);
      await expectLater(
        k.getOrCreateDatabaseKey(),
        throwsA(isA<DatabaseKeyUnavailable>()),
      );
    });

    test(
      'a damaged stored value is kept aside, never overwritten blindly',
      () async {
        final k = _Keychain(values: {SecureStore.databaseKey: 'short'});
        final key = await k.getOrCreateDatabaseKey();
        expect(key, hasLength(64));
        expect(k.values[SecureStore.damagedDatabaseKey], 'short');
      },
    );
  });

  testWidgets('a keychain failure shows the recovery screen; Try again '
      're-runs startup', (tester) async {
    var retries = 0;
    final root = (await tester.runAsync(
      () => buildRoot(
        onRetry: () async => retries++,
        secureStore: _Keychain(failRead: true),
      ),
    ))!;
    expect(root, isA<StartupErrorApp>());
    await tester.pumpWidget(root);
    expect(find.text("Can't unlock your data"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('a readable key starts the app', (tester) async {
    final root = (await tester.runAsync(
      () => buildRoot(onRetry: () async {}, secureStore: _Keychain()),
    ))!;
    expect(root, isA<ProviderScope>());
    expect(root, isNot(isA<StartupErrorApp>()));
    expect(find.byType(MaterialApp), findsNothing);
  });
}
