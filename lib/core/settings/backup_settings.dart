/// ============================================================
/// BACKUP SETTINGS — the app's configuration inside a `.ffbackup`
/// ============================================================
///
/// What: the value stored as `settings.json` in a backup — every
/// [AppSettings] field that belongs to the *user* (appearance, notification
/// rules, layout, gestures, security & backup preferences …) plus the few
/// view preferences that live outside [AppSettings] ([BackedUpPreferences])
/// — and the rules for putting it back on a device ([applyTo],
/// [preferencesToWrite]).
///
/// Why a separate type: data restores are decided row by row, settings are
/// decided field by field, and a restore must never hand a phone someone
/// else's *identity*:
///
///  * [deviceBound] fields describe this install, this sign-in or this
///    phone (onboarding seen, Google account mode, last sync time, search
///    history, visual-effects mode) — never written to a backup, never read
///    from one.
///  * **Replace** takes every field the backup has; **Merge** only fills in
///    fields still at their default, so what the user already changed on
///    this phone wins (the same "keep local work" promise as for items).
///  * **App lock** can be switched on by a restore but never off — turning
///    it off needs the device owner (Settings › App lock), see
///    `AppLockController.setEnabled`.
///
/// Fields the backup lacks (older app version) keep their local value; values
/// are sanitised through [AppSettings.fromJson] (clamped; one it cannot read
/// falls back to the default), so a damaged or hand-edited file can't put an
/// impossible setting in effect.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/settings/app_settings.dart';

/// SharedPreferences keys that hold a *view preference* outside
/// [AppSettings] but that the user would call "my settings" (they are
/// carried in backups like the rest). Add a key here when a feature stores
/// a preference in SharedPreferences directly; keep transient state (asked
/// flags, caches, "last run" stamps) out.
abstract final class BackedUpPreferences {
  /// Tasks list order (`TaskSort.name`).
  static const String tasksSort = 'tasks.sort';

  /// Tasks list / board (`TaskView.name`).
  static const String tasksView = 'tasks.view';

  static const List<String> keys = [tasksSort, tasksView];
}

@immutable
class BackupSettings {
  const BackupSettings({required this.settings, this.preferences = const {}});

  /// The settings of [s] as a backup carries them.
  factory BackupSettings.of(
    AppSettings s, {
    Map<String, String> preferences = const {},
  }) => BackupSettings(
    settings: {
      for (final e in s.toJson().entries)
        if (!deviceBound.contains(e.key)) e.key: e.value,
    },
    preferences: {
      for (final e in preferences.entries)
        if (BackedUpPreferences.keys.contains(e.key)) e.key: e.value,
    },
  );

  static const int currentVersion = 1;

  /// [AppSettings] JSON keys that stay with the device / sign-in.
  /// `performanceMode` is a statement about *this phone* (Reduced chosen on a
  /// 2 GB handset must not follow a backup onto a flagship).
  static const Set<String> deviceBound = {
    'onboardingSeen',
    'accountMode',
    'lastSyncAt',
    'recentSearches',
    'performanceMode',
  };

  /// The longest preference value taken from a file (they are enum names).
  static const int _maxPreferenceLength = 64;

  /// [AppSettings.toJson] minus [deviceBound].
  final Map<String, Object?> settings;

  /// [BackedUpPreferences] key → stored string.
  final Map<String, String> preferences;

  Map<String, Object?> toJson() => {
    'format': 'ffsettings',
    'version': currentVersion,
    'settings': settings,
    'preferences': preferences,
  };

  /// Reads a decoded `settings.json`. Null when it is not a settings payload
  /// (wrong shape, or written by a newer app whose layout is unknown).
  static BackupSettings? fromJson(Object? json) {
    if (json is! Map || json['format'] != 'ffsettings') return null;
    final version = json['version'];
    if (version is! num || version > currentVersion) return null;
    final settings = json['settings'];
    if (settings is! Map) return null;
    final prefs = json['preferences'];
    return BackupSettings(
      settings: {
        for (final e in settings.entries)
          if (e.key is String) e.key as String: e.value,
      },
      preferences: {
        if (prefs is Map)
          for (final e in prefs.entries)
            if (BackedUpPreferences.keys.contains(e.key) &&
                e.value is String &&
                (e.value as String).length <= _maxPreferenceLength)
              e.key as String: e.value as String,
      },
    );
  }

  /// The settings this device ends up with after restoring [this] over
  /// [current] (see the file header for the rules). [replace] = Replace
  /// restore, otherwise Merge.
  AppSettings applyTo(AppSettings current, {required bool replace}) {
    final local = current.toJson();
    final defaults = const AppSettings().toJson();
    // Sanitised copy of the backup's values (clamped, enums validated);
    // only the keys the backup really has are used from it.
    final clean = AppSettings.fromJson(settings).toJson();
    const same = DeepCollectionEquality();
    final merged = {...local};
    for (final key in settings.keys) {
      if (deviceBound.contains(key) || !clean.containsKey(key)) continue;
      if (replace || same.equals(local[key], defaults[key])) {
        merged[key] = clean[key];
      }
    }
    merged['appLockEnabled'] =
        current.appLockEnabled || merged['appLockEnabled'] == true;
    return AppSettings.fromJson(merged);
  }

  /// The preferences to write, given what [local] holds now (key → value,
  /// only keys that are set): Replace takes all of them, Merge only those
  /// this device has not set yet.
  Map<String, String> preferencesToWrite(
    Map<String, String> local, {
    required bool replace,
  }) => {
    for (final e in preferences.entries)
      if (replace || !local.containsKey(e.key)) e.key: e.value,
  };
}
