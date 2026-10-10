/// ============================================================
/// CORE PROVIDERS — app-wide singletons (Fresh LPG pattern)
/// ============================================================
///
/// Values that need async setup (prefs, DB key, device id) are resolved once
/// in `main()` (lib/bootstrap.dart) and injected with
/// `ProviderScope(overrides: [...])`; un-overridden they throw, so a missing
/// override fails loudly instead of silently using a blank value.
///
/// Tests override [databaseProvider] with an AppDatabase over a temp file /
/// memory executor and [clockProvider] with a FakeClock.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/encrypted_database.dart';
import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main()');
});

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

/// The 64-hex-char SQLite key (resolved in main()).
final databaseKeyProvider = Provider<String>((ref) {
  throw UnimplementedError('Override databaseKeyProvider in main()');
});

/// Stable per-install id written into every row's `deviceId` + backups.
final deviceIdProvider = Provider<String>((ref) {
  throw UnimplementedError('Override deviceIdProvider in main()');
});

/// The single encrypted database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(
    EncryptedDatabase.open(cipherKey: ref.watch(databaseKeyProvider)),
  );
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((ref) => const Clock());

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

/// New uuid v4 — use for every new row id.
String newId(Ref ref) => ref.read(uuidProvider).v4();
