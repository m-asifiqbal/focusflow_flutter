/// ============================================================
/// VAULT SECURITY STORE — last scan time + daily health-score snapshots
/// ============================================================
///
/// Backs "Last scan: today, 8:02 AM" and "+6 since last week" on the
/// Security dashboard (22). Only non-secret numbers live here (a time and
/// one 0–100 score per day, last 60 days) in SharedPreferences; nothing
/// about individual items or passwords.
/// ============================================================
library;

import 'dart:convert';

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VaultSecurityStore {
  VaultSecurityStore(this._prefs);

  static const String lastScanKey = 'vault.security.lastScanAt';
  static const String scoresKey = 'vault.security.scores';
  static const int keepDays = 60;

  final SharedPreferences _prefs;

  DateTime? get lastScanAt {
    final ms = _prefs.getInt(lastScanKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastScanAt(DateTime at) =>
      _prefs.setInt(lastScanKey, at.millisecondsSinceEpoch);

  /// Day key (`yyyy-MM-dd`) → score.
  Map<String, int> get scores {
    final raw = _prefs.getString(scoresKey);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in map.entries) e.key: (e.value as num).toInt()};
    } on Object {
      return const {};
    }
  }

  /// Stores [score] for [day] (keeps the last [keepDays] days).
  Future<void> recordScore(DateTime day, int score) async {
    final key = DateUtilsX.dayKey(day);
    final current = scores;
    if (current[key] == score) return;
    final cutoff = DateUtilsX.dayKey(
      day.subtract(const Duration(days: keepDays)),
    );
    final next = {
      for (final e in current.entries)
        if (e.key.compareTo(cutoff) > 0) e.key: e.value,
      key: score,
    };
    await _prefs.setString(scoresKey, jsonEncode(next));
  }

  /// The newest snapshot at least a week before [today] (null: none).
  int? scoreWeekBefore(DateTime today) {
    final limit = DateUtilsX.dayKey(today.subtract(const Duration(days: 7)));
    final older = scores.entries.where((e) => e.key.compareTo(limit) <= 0);
    if (older.isEmpty) return null;
    return older.reduce((a, b) => a.key.compareTo(b.key) >= 0 ? a : b).value;
  }
}
