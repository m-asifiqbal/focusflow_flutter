/// ============================================================
/// DRIVE SYNC STATE — which other-device backups were merged (prefs)
/// ============================================================
///
/// Two small prefs entries drive the merge step of "Sync now":
/// * [mergedKey] — deviceId → createdAt of that device's newest backup
///   already handled (merged, skipped as damaged, or baselined by "Start
///   fresh"); only newer backups are merged next time.
/// * [decisionKey] — set when sign-in found existing Drive backups and
///   the user has not yet chosen Restore or Start fresh: until then sync
///   still uploads but merges nothing (after a reinstall the user's own
///   old backups count as "another device" — merging them must be the
///   user's choice).
/// Sign-out, erase and a Replace restore reset this state so it never
/// describes data that is no longer on the device.
/// ============================================================
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DriveSyncState {
  DriveSyncState(this.prefs);

  final SharedPreferences prefs;

  /// Prefs: deviceId → createdAt (ISO) of that device's last handled backup.
  static const String mergedKey = 'drive_sync_merged_v1';

  /// Prefs: true while the Restore / Start fresh choice is outstanding.
  static const String decisionKey = 'drive_sync_merge_decision_pending_v1';

  /// The handled-backup map (empty when unreadable).
  Map<String, DateTime> merged() {
    try {
      final raw = prefs.getString(mergedKey);
      if (raw == null) return {};
      final out = <String, DateTime>{};
      for (final e in (jsonDecode(raw) as Map).entries) {
        final t = DateTime.tryParse('${e.value}');
        if (t != null) out['${e.key}'] = t;
      }
      return out;
    } on Object {
      return {};
    }
  }

  Future<void> saveMerged(Map<String, DateTime> m) => prefs.setString(
    mergedKey,
    jsonEncode({
      for (final e in m.entries) e.key: e.value.toUtc().toIso8601String(),
    }),
  );

  /// Marks [deviceId]'s backup of [createdAt] (and older) as handled.
  Future<void> markHandled(String deviceId, DateTime createdAt) async {
    final m = merged();
    final cur = m[deviceId];
    if (cur == null || createdAt.isAfter(cur)) {
      m[deviceId] = createdAt;
      await saveMerged(m);
    }
  }

  bool get decisionPending => prefs.getBool(decisionKey) ?? false;

  Future<void> setDecisionPending(bool pending) =>
      pending ? prefs.setBool(decisionKey, true) : prefs.remove(decisionKey);

  /// Forgets everything (sign-out, erase, a different account).
  Future<void> clear() async {
    await prefs.remove(mergedKey);
    await prefs.remove(decisionKey);
  }
}
