/// ============================================================
/// ENCRYPTED DATABASE — encrypted SQLite (SQLite3MultipleCiphers)
/// ============================================================
///
/// pubspec selects the sqlite3mc build (`hooks: user_defines: sqlite3:
/// source: sqlite3mc`), bundled by sqlite3's build hook on every platform.
/// [open] keys each connection with `PRAGMA key` and *verifies* the cipher
/// build is really loaded, so data can never silently be written in
/// plaintext (same guard as Fresh LPG's DatabaseCipher).
///
/// The file lives in the app-support directory (not user-visible, excluded
/// from iTunes file sharing). Queries run on a background isolate.
/// ============================================================
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

abstract final class EncryptedDatabase {
  /// Opens (creating if needed) the encrypted database with [cipherKey]
  /// (64 hex chars from DatabaseKeyStore).
  static QueryExecutor open({
    required String cipherKey,
    String fileName = AppInfo.databaseFileName,
  }) {
    return LazyDatabase(() async {
      final file = await databaseFile(fileName);
      await _quarantineIfUnreadable(file, cipherKey);
      return NativeDatabase.createInBackground(
        file,
        setup: (rawDb) => applyKey(rawDb, cipherKey),
      );
    });
  }

  static Future<File> databaseFile([
    String fileName = AppInfo.databaseFileName,
  ]) async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File(p.join(dir.path, fileName));
  }

  /// Keys the connection and asserts SQLite3MultipleCiphers is active.
  /// Throwing is intentional: a missing cipher must fail loudly.
  static void applyKey(Database rawDb, String cipherKey) {
    try {
      rawDb.select('SELECT sqlite3mc_version()');
    } catch (_) {
      throw StateError(
        'SQLite3MultipleCiphers is not active — refusing to open the '
        'database unencrypted. Check `hooks: user_defines: sqlite3: source: '
        'sqlite3mc` in pubspec.yaml.',
      );
    }
    rawDb.execute("PRAGMA key = '$cipherKey';");
    // Touch the schema so a wrong key fails here, not on the first query.
    rawDb.select('SELECT count(*) FROM sqlite_master');
    rawDb.execute('PRAGMA journal_mode = WAL;');
  }

  /// If [file] exists but cannot be opened with [cipherKey] (key lost —
  /// e.g. a device restore that brought the file but not the keystore),
  /// move it aside instead of crashing on every launch. The user can still
  /// restore from a backup; the unreadable file is kept for support.
  static Future<void> _quarantineIfUnreadable(File file, String key) async {
    if (!await file.exists()) return;
    Database? db;
    try {
      db = sqlite3.open(file.path);
      applyKey(db, key);
      return;
    } on StateError {
      rethrow; // cipher build missing — never "recover" from that
    } catch (e) {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      AppLogger.e('Database unreadable with stored key — quarantining ($e)');
      db?.close();
      db = null;
      for (final suffix in ['', '-wal', '-shm']) {
        final f = File('${file.path}$suffix');
        if (await f.exists()) await f.rename('${f.path}.unreadable-$stamp');
      }
    } finally {
      db?.close();
    }
  }

  /// Deletes the database file (+ WAL/SHM). Used by "Erase local data".
  static Future<void> deleteFiles([
    String fileName = AppInfo.databaseFileName,
  ]) async {
    final file = await databaseFile(fileName);
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${file.path}$suffix');
      if (await f.exists()) await f.delete();
    }
  }
}
