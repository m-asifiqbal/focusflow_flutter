/// ============================================================
/// SETTINGS BRIDGE — what backups need from the app's settings
/// ============================================================
///
/// A backup carries the app's configuration next to the data, so a phone
/// that lost its settings (reinstall, new device, cleared storage) gets them
/// back with a restore. The engine only talks to this interface; the rules
/// for *what* is carried and how it is put back live in
/// core/settings/backup_settings.dart.
///
/// [AppSettingsBackupBridge] (the default of [settingsBackupBridgeProvider])
/// reads and writes through the live settings controller, so a restored
/// theme, quiet-hours rule or Home layout appears on screen at once and
/// the notification engine re-plans on its own. [NoSettingsBackupBridge]
/// carries nothing (engine tests, builds without settings).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/backup_settings.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SettingsBackupBridge {
  /// The configuration to embed in a backup; null = nothing to carry.
  Future<BackupSettings?> export();

  /// Puts [incoming] in effect on this device. [replace] is a Replace
  /// restore (everything the backup has), otherwise a Merge (only what is
  /// still at its default here). Throws when it could not be saved.
  Future<void> apply(BackupSettings incoming, {required bool replace});
}

/// Carries no settings and applies none.
class NoSettingsBackupBridge implements SettingsBackupBridge {
  const NoSettingsBackupBridge();

  @override
  Future<BackupSettings?> export() async => null;

  @override
  Future<void> apply(BackupSettings incoming, {required bool replace}) async {}
}

/// The real settings: [settingsProvider] plus the view preferences in
/// [BackedUpPreferences].
class AppSettingsBackupBridge implements SettingsBackupBridge {
  AppSettingsBackupBridge(this._ref);

  final Ref _ref;

  SharedPreferences get _prefs => _ref.read(sharedPreferencesProvider);

  /// The backed-up view preferences this device has set.
  Map<String, String> _localPreferences() => {
    for (final key in BackedUpPreferences.keys) key: ?_prefs.getString(key),
  };

  @override
  Future<BackupSettings?> export() async => BackupSettings.of(
    _ref.read(settingsProvider),
    preferences: _localPreferences(),
  );

  @override
  Future<void> apply(BackupSettings incoming, {required bool replace}) async {
    final writes = incoming.preferencesToWrite(
      _localPreferences(),
      replace: replace,
    );
    for (final e in writes.entries) {
      await _prefs.setString(e.key, e.value);
    }
    await _ref
        .read(settingsProvider.notifier)
        .update((s) => incoming.applyTo(s, replace: replace));
  }
}

/// The settings carried by backups (tests may override with
/// [NoSettingsBackupBridge]).
final settingsBackupBridgeProvider = Provider<SettingsBackupBridge>(
  AppSettingsBackupBridge.new,
);
