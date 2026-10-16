/// ============================================================
/// RECENT SEARCHES STORE — Global search history in the Keychain/Keystore
/// ============================================================
///
/// What: the "RECENT SEARCHES" pills of screen 06 (newest first, max 10,
/// deduplicated case-insensitively), persisted as one JSON list under
/// [storageKey] in [SecureStore], plus the pure list rules ([push],
/// [merge]) the controller applies.
/// Why: search terms reveal what the user keeps in an encrypted app
/// ("divorce lawyer", a bank name), so they must not sit in plaintext
/// SharedPreferences (where `AppSettings.recentSearches` used to keep
/// them — migrated once by `RecentSearchesController`). Terms are never
/// logged. Storage failures (no Keychain in tests, a locked device) are
/// swallowed: history is a convenience and must never break search.
/// ============================================================
library;

import 'dart:convert';

import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/core/utils/app_logger.dart';

class RecentSearchesStore {
  const RecentSearchesStore(this._secure);

  final SecureStore _secure;

  static const String storageKey = 'search.recent';

  /// Pills kept (prompt 06: "Recent searches stored (max 10)").
  static const int max = 10;

  /// The stored history, newest first; empty when nothing is stored or the
  /// secure store can't be read.
  Future<List<String>> read() async {
    try {
      final raw = await _secure.read(storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return normalize(decoded.whereType<String>());
    } catch (e) {
      AppLogger.w('Recent searches unreadable (${e.runtimeType})');
      return const [];
    }
  }

  /// Persists [terms]; false when the secure store refused the write.
  Future<bool> write(List<String> terms) async {
    try {
      final list = normalize(terms);
      if (list.isEmpty) {
        await _secure.delete(storageKey);
      } else {
        await _secure.write(storageKey, jsonEncode(list));
      }
      return true;
    } catch (e) {
      AppLogger.w('Recent searches not saved (${e.runtimeType})');
      return false;
    }
  }

  /// Forgets the whole history.
  Future<bool> clear() => write(const []);

  /// [term] moved to the front of [list] (trimmed, deduplicated
  /// case-insensitively, at most [max]). Blank terms change nothing.
  static List<String> push(List<String> list, String term) {
    final t = term.trim();
    if (t.isEmpty) return normalize(list);
    return normalize([t, ...list]);
  }

  /// [newer] first, then the [older] terms it doesn't already contain.
  static List<String> merge(List<String> newer, List<String> older) =>
      normalize([...newer, ...older]);

  /// Trimmed, non-blank, first occurrence wins (case-insensitive), max 10.
  static List<String> normalize(Iterable<String> terms) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in terms) {
      final t = raw.trim();
      if (t.isEmpty || !seen.add(t.toLowerCase())) continue;
      out.add(t);
      if (out.length == max) break;
    }
    return List.unmodifiable(out);
  }
}
