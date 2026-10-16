/// Test harness: a fully wired Riverpod graph over a real, keyed SQLite
/// file (in-memory DBs can't be keyed — see app_database_test.dart), a
/// [FakeClock], a fixed device id and counter-based ids.
///
/// ```dart
/// final h = await TestHarness.create(now: DateTime(2026, 6, 13, 9));
/// addTearDown(h.dispose);
/// final tasks = h.read(tasksRepositoryProvider);
/// ```
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/encrypted_database.dart';
import 'package:focusflow/core/items/attachment_files.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestHarness {
  TestHarness._(this.container, this.db, this.clock, this._dir);

  final ProviderContainer container;
  final AppDatabase db;
  final FakeClock clock;
  final Directory _dir;

  static const String deviceId = 'test-device';

  static Future<TestHarness> create({
    required DateTime now,
    List<Override> overrides = const [],
    Map<String, Object> prefs = const {},
  }) async {
    final dir = Directory.systemTemp.createTempSync('ff_test');
    final db = AppDatabase(
      NativeDatabase(
        File('${dir.path}/test.db'),
        setup: (raw) => EncryptedDatabase.applyKey(raw, 'a' * 64),
      ),
    );
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final clock = FakeClock(now);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        databaseKeyProvider.overrideWithValue('a' * 64),
        deviceIdProvider.overrideWithValue(deviceId),
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        attachmentFileStoreProvider.overrideWithValue(
          const NoopAttachmentFileStore(),
        ),
        ...overrides,
      ],
    );
    return TestHarness._(container, db, clock, dir);
  }

  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  Future<void> dispose() async {
    container.dispose();
    await db.close();
    _dir.deleteSync(recursive: true);
  }
}
