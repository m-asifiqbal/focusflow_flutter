/// SettingsController: loads the persisted blob (defaults when it is
/// missing or corrupt), persists every update, keeps the recent-search
/// history deduplicated and capped, and resets only the preferences.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  Future<ProviderContainer> container([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Map<String, Object?> stored() =>
      (jsonDecode(prefs.getString(SettingsController.prefsKey)!) as Map)
          .cast<String, Object?>();

  test('no blob → defaults', () async {
    final c = await container();
    expect(c.read(settingsProvider).toJson(), const AppSettings().toJson());
  });

  test('corrupt blob → defaults instead of a crash', () async {
    for (final raw in ['{not json', '[1,2,3]', '"text"', 'null']) {
      final c = await container({SettingsController.prefsKey: raw});
      expect(
        c.read(settingsProvider).toJson(),
        const AppSettings().toJson(),
        reason: raw,
      );
    }
  });

  test('stored blob is loaded; update persists', () async {
    final c = await container({
      SettingsController.prefsKey: jsonEncode({'accent': 'blue'}),
    });
    expect(c.read(settingsProvider).accent, AccentColor.blue);
    await c
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(themeMode: ThemeMode.dark));
    expect(c.read(settingsProvider).themeMode, ThemeMode.dark);
    expect(stored()['themeMode'], 'dark');
    expect(stored()['accent'], 'blue');
  });

  test('addRecentSearch trims, ignores blanks, dedupes newest-first, '
      'caps at 10', () async {
    final c = await container();
    final n = c.read(settingsProvider.notifier);
    await n.addRecentSearch('   ');
    expect(c.read(settingsProvider).recentSearches, isEmpty);
    for (var i = 0; i < 12; i++) {
      await n.addRecentSearch('q$i');
    }
    await n.addRecentSearch('  q5 ');
    final list = c.read(settingsProvider).recentSearches;
    expect(list, hasLength(10));
    expect(list.first, 'q5');
    expect(list.where((x) => x == 'q5'), hasLength(1));
    expect(list, isNot(contains('q0')));
    await n.clearRecentSearches();
    expect(c.read(settingsProvider).recentSearches, isEmpty);
  });

  test('resetToDefaults restores preferences but keeps account, security, '
      'vault and backup settings', () async {
    final c = await container();
    final n = c.read(settingsProvider.notifier);
    final synced = DateTime.utc(2026, 6, 12);
    await n.update(
      (s) => s.copyWith(
        onboardingSeen: true,
        accountMode: AccountMode.google,
        displayName: 'Asif',
        accent: AccentColor.orange,
        themeMode: ThemeMode.dark,
        textScale: 1.3,
        notificationsEnabled: false,
        swipeLeft: SwipeAction.none,
        appLockEnabled: true,
        hideInAppSwitcher: false,
        clipboardClearSeconds: 0,
        vaultBiometrics: false,
        vaultAutoLockMinutes: 30,
        autoBackupDrive: false,
        encryptBackups: false,
        keepBackups: 3,
        tasksDefaultListId: () => 'list-1',
        lastSyncAt: () => synced,
      ),
    );
    await n.resetToDefaults();
    final s = c.read(settingsProvider);
    const d = AppSettings();
    // Preferences back to defaults.
    expect(s.accent, d.accent);
    expect(s.themeMode, d.themeMode);
    expect(s.textScale, d.textScale);
    expect(s.notificationsEnabled, d.notificationsEnabled);
    expect(s.swipeLeft, d.swipeLeft);
    // Kept.
    expect(s.onboardingSeen, isTrue);
    expect(s.accountMode, AccountMode.google);
    expect(s.displayName, 'Asif');
    expect(s.appLockEnabled, isTrue);
    expect(s.hideInAppSwitcher, isFalse);
    expect(s.clipboardClearSeconds, 0);
    expect(s.vaultBiometrics, isFalse);
    expect(s.vaultAutoLockMinutes, 30);
    expect(s.autoBackupDrive, isFalse);
    expect(s.encryptBackups, isFalse);
    expect(s.keepBackups, 3);
    expect(s.tasksDefaultListId, 'list-1');
    expect(s.lastSyncAt, synced);
    expect(stored()['accent'], d.accent.name);
  });
}
