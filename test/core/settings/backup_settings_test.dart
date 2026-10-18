/// BackupSettings — what a backup carries of the app's configuration and the
/// rules for putting it back: Replace takes the backup's values, Merge only
/// fills in what is still at its default, device-bound fields and App lock's
/// "off" never travel, values are sanitised, and the real bridge applies the
/// result through the live settings controller.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/settings/backup_settings.dart';
import 'package:focusflow/core/sync/settings_bridge.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const defaults = AppSettings();

  /// A backup holding exactly [settings] (as a decoded file would).
  BackupSettings backup(
    Map<String, Object?> settings, {
    Map<String, String> preferences = const {},
  }) => BackupSettings(settings: settings, preferences: preferences);

  group('carrying', () {
    test('keeps the user preferences, drops device-bound fields', () {
      final b = BackupSettings.of(
        defaults.copyWith(
          accent: AccentColor.blue,
          quietHours: true,
          onboardingSeen: true,
          accountMode: AccountMode.google,
          lastSyncAt: () => DateTime(2026, 5, 1),
          recentSearches: const ['x'],
        ),
        preferences: const {'tasks.view': 'board', 'unrelated': 'nope'},
      );

      expect(b.settings['accent'], 'blue');
      expect(b.settings['quietHours'], true);
      for (final key in BackupSettings.deviceBound) {
        expect(b.settings.containsKey(key), isFalse, reason: key);
      }
      expect(b.preferences, {'tasks.view': 'board'});
    });

    test('the device-bound names are real AppSettings fields', () {
      // A typo here would silently let a device-bound field travel.
      expect(defaults.toJson().keys, containsAll(BackupSettings.deviceBound));
      expect(
        BackupSettings.of(defaults).settings.length,
        defaults.toJson().length - BackupSettings.deviceBound.length,
      );
    });

    test('survives a JSON round trip', () {
      final b = BackupSettings.of(
        defaults.copyWith(
          themeMode: ThemeMode.dark,
          hiddenLibraryModules: {'vault'},
        ),
        preferences: const {'tasks.sort': 'manual'},
      );
      final back = BackupSettings.fromJson(jsonDecode(jsonEncode(b.toJson())))!;

      expect(back.settings, b.settings);
      expect(back.preferences, b.preferences);
    });

    test('anything that is not a settings payload reads as null', () {
      for (final bad in <Object?>[
        null,
        'text',
        <Object?>[],
        {'format': 'other', 'version': 1, 'settings': {}},
        {'format': 'ffsettings', 'settings': {}},
        {'format': 'ffsettings', 'version': 1},
        {'format': 'ffsettings', 'version': 1, 'settings': 'x'},
        {'format': 'ffsettings', 'version': 99, 'settings': {}},
      ]) {
        expect(BackupSettings.fromJson(bad), isNull, reason: '$bad');
      }
    });

    test('only known, short, string preferences are read from a file', () {
      final b = BackupSettings.fromJson({
        'format': 'ffsettings',
        'version': 1,
        'settings': {'accent': 'blue'},
        'preferences': {
          'tasks.view': 'board',
          'tasks.sort': 7,
          'device_id': 'stolen',
          'habits.perfectDayClaimed': '2026-01-01',
          'tasks.sort ': 'manual',
        },
      })!;

      expect(b.preferences, {'tasks.view': 'board'});
      expect(
        BackupSettings.fromJson({
          'format': 'ffsettings',
          'version': 1,
          'settings': <String, Object?>{},
          'preferences': {'tasks.view': 'x' * 500},
        })!.preferences,
        isEmpty,
      );
    });
  });

  group('Replace', () {
    test('takes every field the backup has', () {
      final local = defaults.copyWith(
        accent: AccentColor.indigo,
        themeMode: ThemeMode.light,
        quietHours: true,
        use24HourTime: true,
      );
      final result = backup({
        'accent': 'blue',
        'themeMode': 'dark',
        'quietHours': false,
        'use24HourTime': false,
      }).applyTo(local, replace: true);

      expect(result.accent, AccentColor.blue);
      expect(result.themeMode, ThemeMode.dark);
      expect(result.quietHours, isFalse);
      expect(result.use24HourTime, isFalse);
    });

    test('fields the backup lacks keep their local value', () {
      final local = defaults.copyWith(
        repeatIntervalMinutes: 30,
        accent: AccentColor.indigo,
      );
      // An older app's backup: no repeat settings, knows only the accent.
      final result = backup({'accent': 'blue'}).applyTo(local, replace: true);

      expect(result.accent, AccentColor.blue);
      expect(result.repeatIntervalMinutes, 30);
    });

    test('a restore carries the whole configuration', () {
      final theirs = defaults.copyWith(
        accent: AccentColor.blue,
        themeMode: ThemeMode.dark,
        weekStartsOn: DateTime.sunday,
        quietHours: true,
        quietStartMinutes: 23 * 60,
        repeatIntervalMinutes: 15,
        repeatCount: 5,
        lockScreenVisibility: LockScreenVisibility.hidden,
        homeSections: const [
          HomeSection.tasks,
          HomeSection.focus,
          HomeSection.week,
          HomeSection.upNext,
          HomeSection.notes,
          HomeSection.habits,
        ],
        hiddenHomeSections: const {HomeSection.notes},
        hiddenLibraryModules: const {'vault'},
        libraryModuleOrder: const ['tasks', 'notes'],
        swipeLeft: SwipeAction.delete,
        vaultAutoLockMinutes: 1,
        keepBackups: 3,
        displayName: 'Asif',
      );
      final carried = BackupSettings.fromJson(
        jsonDecode(jsonEncode(BackupSettings.of(theirs).toJson())),
      )!;

      final result = carried.applyTo(defaults, replace: true);

      expect(result.toJson(), theirs.toJson());
    });

    test('device-bound fields stay as they are, even if a file has them', () {
      final local = defaults.copyWith(
        onboardingSeen: true,
        accountMode: AccountMode.offline,
        lastSyncAt: () => DateTime.utc(2026, 3, 3),
        recentSearches: const ['mine'],
      );
      final result = backup({
        'onboardingSeen': false,
        'accountMode': 'google',
        'lastSyncAt': '2020-01-01T00:00:00.000Z',
        'recentSearches': ['theirs'],
        'accent': 'blue',
      }).applyTo(local, replace: true);

      expect(result.onboardingSeen, isTrue);
      expect(result.accountMode, AccountMode.offline);
      expect(result.lastSyncAt, DateTime.utc(2026, 3, 3));
      expect(result.recentSearches, ['mine']);
      expect(result.accent, AccentColor.blue);
    });
  });

  group('Merge', () {
    test('fills in what is still at its default', () {
      final result = backup({
        'accent': 'blue',
        'quietHours': true,
        'swipeLeft': 'delete',
      }).applyTo(defaults, replace: false);

      expect(result.accent, AccentColor.blue);
      expect(result.quietHours, isTrue);
      expect(result.swipeLeft, SwipeAction.delete);
    });

    test('what the user already changed here wins', () {
      final local = defaults.copyWith(accent: AccentColor.indigo);
      final result = backup({
        'accent': 'blue',
        'quietHours': true,
      }).applyTo(local, replace: false);

      expect(result.accent, AccentColor.indigo);
      expect(result.quietHours, isTrue);
    });

    test('a list setting counts as changed when it differs from default', () {
      final local = defaults.copyWith(libraryModuleOrder: const ['tasks']);
      final result = backup({
        'libraryModuleOrder': ['notes', 'tasks'],
        'hiddenLibraryModules': ['vault'],
      }).applyTo(local, replace: false);

      expect(result.libraryModuleOrder, ['tasks']);
      expect(result.hiddenLibraryModules, {'vault'});
    });
  });

  group('App lock', () {
    test('a restore can switch it on', () {
      for (final replace in [true, false]) {
        final result = backup({
          'appLockEnabled': true,
        }).applyTo(defaults, replace: replace);
        expect(result.appLockEnabled, isTrue, reason: 'replace=$replace');
      }
    });

    test('a restore never switches it off', () {
      final local = defaults.copyWith(appLockEnabled: true);
      for (final replace in [true, false]) {
        final result = backup({
          'appLockEnabled': false,
        }).applyTo(local, replace: replace);
        expect(result.appLockEnabled, isTrue, reason: 'replace=$replace');
      }
    });
  });

  group('sanitising', () {
    test('impossible values are clamped, not trusted', () {
      final result = backup({
        'textScale': 9,
        'weekStartsOn': 99,
        'repeatIntervalMinutes': 100000,
        'repeatCount': 0,
        'keepBackups': -4,
        'quietStartMinutes': 5000,
      }).applyTo(defaults, replace: true);

      expect(result.textScale, 1.3);
      expect(result.weekStartsOn, 7);
      expect(
        result.repeatIntervalMinutes,
        AppSettings.maxRepeatIntervalMinutes,
      );
      expect(result.repeatCount, 1);
      expect(result.keepBackups, 1);
      expect(result.quietStartMinutes, AppSettings.minutesPerDay - 1);
    });

    test('unknown values and keys do no harm', () {
      final local = defaults.copyWith(accent: AccentColor.indigo);
      final result = backup({
        'accent': 'ultraviolet',
        'themeMode': 42,
        'somethingNew': 'from a newer app',
      }).applyTo(local, replace: true);

      expect(result.accent, defaults.accent); // unreadable → the default
      expect(result.themeMode, defaults.themeMode);
      expect(result.toJson().containsKey('somethingNew'), isFalse);
    });
  });

  group('preferences', () {
    test('Replace writes all of them, Merge only the ones not set here', () {
      final b = backup(
        const {},
        preferences: const {'tasks.view': 'board', 'tasks.sort': 'manual'},
      );
      final local = {'tasks.sort': 'smart'};

      expect(b.preferencesToWrite(local, replace: true), b.preferences);
      expect(b.preferencesToWrite(local, replace: false), {
        'tasks.view': 'board',
      });
    });
  });

  group('AppSettingsBackupBridge', () {
    late SharedPreferences prefs;

    Future<ProviderContainer> container([
      Map<String, Object> values = const {},
    ]) async {
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

    test('exports the live settings and the view preferences', () async {
      final c = await container({
        'tasks.view': 'board',
        'habits.perfectDayClaimed': '2026-01-01',
      });
      await c
          .read(settingsProvider.notifier)
          .update(
            (s) => s.copyWith(accent: AccentColor.blue, onboardingSeen: true),
          );

      final out = (await c.read(settingsBackupBridgeProvider).export())!;

      expect(out.settings['accent'], 'blue');
      expect(out.settings.containsKey('onboardingSeen'), isFalse);
      expect(out.preferences, {'tasks.view': 'board'});
    });

    test('Replace: settings change on screen and on disk', () async {
      final c = await container({'tasks.sort': 'smart'});
      await c
          .read(settingsProvider.notifier)
          .update(
            (s) => s.copyWith(
              accent: AccentColor.indigo,
              onboardingSeen: true,
              accountMode: AccountMode.google,
            ),
          );
      final seen = <AccentColor>[];
      c.listen(
        settingsProvider.select((s) => s.accent),
        (_, next) => seen.add(next),
      );

      await c
          .read(settingsBackupBridgeProvider)
          .apply(
            backup(
              {'accent': 'blue', 'themeMode': 'dark', 'onboardingSeen': false},
              preferences: const {
                'tasks.view': 'board',
                'tasks.sort': 'manual',
              },
            ),
            replace: true,
          );

      final s = c.read(settingsProvider);
      expect(s.accent, AccentColor.blue);
      expect(s.themeMode, ThemeMode.dark);
      expect(s.onboardingSeen, isTrue);
      expect(s.accountMode, AccountMode.google);
      expect(seen, [AccentColor.blue]); // live, no restart needed
      expect(stored()['accent'], 'blue');
      expect(stored()['themeMode'], 'dark');
      expect(prefs.getString('tasks.view'), 'board');
      expect(prefs.getString('tasks.sort'), 'manual');
    });

    test('Merge keeps what this phone already chose', () async {
      final c = await container({'tasks.sort': 'smart'});
      await c
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(accent: AccentColor.indigo));

      await c
          .read(settingsBackupBridgeProvider)
          .apply(
            backup(
              {'accent': 'blue', 'themeMode': 'dark'},
              preferences: const {
                'tasks.view': 'board',
                'tasks.sort': 'manual',
              },
            ),
            replace: false,
          );

      final s = c.read(settingsProvider);
      expect(s.accent, AccentColor.indigo);
      expect(s.themeMode, ThemeMode.dark);
      expect(prefs.getString('tasks.view'), 'board');
      expect(prefs.getString('tasks.sort'), 'smart');
    });

    test('the device id is never touched', () async {
      final c = await container({'device_id': 'this-phone'});
      await c
          .read(settingsBackupBridgeProvider)
          .apply(
            backup(
              {'accent': 'blue'},
              preferences: const {'tasks.view': 'board'},
            ),
            replace: true,
          );

      expect(prefs.getString('device_id'), 'this-phone');
    });
  });
}
