/// AppSettings JSON: a full round-trip, defaults for missing / unknown
/// values, range clamps against corrupt or hand-edited blobs, Home
/// sections added in newer versions, and lastSyncAt parsing.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_colors.dart';

void main() {
  AppSettings viaJson(AppSettings s) => AppSettings.fromJson(
    (jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, Object?>(),
  );

  test('toJson → fromJson round-trips every field', () {
    final s = const AppSettings().copyWith(
      onboardingSeen: true,
      accountMode: AccountMode.google,
      displayName: 'Asif',
      dailyFocusGoal: 9,
      timeZone: () => 'Asia/Dhaka',
      startScreen: StartScreen.insights,
      weekStartsOn: DateTime.saturday,
      use24HourTime: true,
      dateFormat: 'yyyy-MM-dd',
      themeMode: ThemeMode.dark,
      accent: AccentColor.pink,
      textScale: 1.2,
      listDensity: ListDensity.compact,
      reduceMotion: true,
      useSystemFont: true,
      morningBriefingMinutes: 7 * 60 + 30,
      weeklyReport: true,
      weeklyReportWeekday: DateTime.friday,
      quietHours: true,
      quietStartMinutes: 23 * 60,
      quietEndMinutes: 6 * 60,
      defaultSnoozeMinutes: 30,
      lockScreenVisibility: LockScreenVisibility.hidden,
      badgeMode: BadgeMode.none,
      notesView: NotesView.list,
      notesSort: NotesSort.titleAz,
      notesDefaultColor: () => 'amber',
      tasksDefaultListId: () => 'list-1',
      tasksShowCompleted: false,
      homeSections: [...HomeSection.values.reversed],
      hiddenHomeSections: {HomeSection.notes},
      hiddenLibraryModules: {'vault'},
      libraryModuleOrder: ['tasks', 'notes'],
      swipeLeft: SwipeAction.delete,
      swipeRight: SwipeAction.pin,
      hapticsEnabled: false,
      appLockEnabled: true,
      clipboardClearSeconds: 60,
      vaultAutoLockMinutes: 15,
      backupFrequency: BackupFrequency.weekly,
      backupMinutes: 3 * 60,
      keepBackups: 25,
      localBackupFrequency: LocalBackupFrequency.off,
      lastSyncAt: () => DateTime.utc(2026, 6, 12, 9, 41),
      recentSearches: ['a', 'b'],
    );
    final back = viaJson(s);
    expect(back.toJson(), s.toJson());
    expect(back.lastSyncAt, DateTime.utc(2026, 6, 12, 9, 41));
    expect(back.homeSections, HomeSection.values.reversed.toList());
  });

  test('empty blob gives the defaults', () {
    expect(
      AppSettings.fromJson(const {}).toJson(),
      const AppSettings().toJson(),
    );
  });

  test('unknown enum names and wrong types fall back to defaults', () {
    final s = AppSettings.fromJson(const {
      'themeMode': 'sepia',
      'accent': 'neon',
      'startScreen': 42,
      'listDensity': 'tiny',
      'swipeLeft': 'explode',
      'badgeMode': null,
      'notesSort': true,
      'reduceMotion': 'yes',
      'dailyFocusGoal': '9',
      'textScale': 'huge',
    });
    const d = AppSettings();
    expect(s.themeMode, d.themeMode);
    expect(s.accent, AccentColor.emerald);
    expect(s.startScreen, d.startScreen);
    expect(s.listDensity, d.listDensity);
    expect(s.swipeLeft, d.swipeLeft);
    expect(s.badgeMode, d.badgeMode);
    expect(s.notesSort, d.notesSort);
    expect(s.reduceMotion, d.reduceMotion);
    expect(s.dailyFocusGoal, d.dailyFocusGoal);
    expect(s.textScale, d.textScale);
  });

  test('out-of-range numbers are clamped', () {
    final low = AppSettings.fromJson(const {
      'weekStartsOn': 0,
      'weeklyReportWeekday': -3,
      'dailyFocusGoal': 0,
      'defaultSnoozeMinutes': 0,
      'keepBackups': 0,
      'clipboardClearSeconds': -5,
      'quietStartMinutes': -1,
      'quietEndMinutes': -60,
      'morningBriefingMinutes': -1,
      'eveningReviewMinutes': -1,
      'backupMinutes': -10,
      'habitResetMinutes': -1,
      'vaultAutoLockMinutes': -1,
      'textScale': 0.1,
    });
    expect(low.weekStartsOn, 1);
    expect(low.weeklyReportWeekday, 1);
    expect(low.dailyFocusGoal, 1);
    expect(low.defaultSnoozeMinutes, 1);
    expect(low.keepBackups, 1);
    expect(low.clipboardClearSeconds, 0);
    expect(low.quietStartMinutes, 0);
    expect(low.quietEndMinutes, 0);
    expect(low.morningBriefingMinutes, 0);
    expect(low.eveningReviewMinutes, 0);
    expect(low.backupMinutes, 0);
    expect(low.habitResetMinutes, 0);
    expect(low.vaultAutoLockMinutes, 0);
    expect(low.textScale, 0.85);

    final high = AppSettings.fromJson(const {
      'weekStartsOn': 9,
      'weeklyReportWeekday': 8,
      'dailyFocusGoal': 10000,
      'defaultSnoozeMinutes': 99999,
      'keepBackups': 5000,
      'clipboardClearSeconds': 999999,
      'quietStartMinutes': 2000,
      'quietEndMinutes': 1440,
      'morningBriefingMinutes': 1440,
      'eveningReviewMinutes': 5000,
      'backupMinutes': 1440,
      'habitResetMinutes': 3000,
      'vaultAutoLockMinutes': 100000,
      'textScale': 4.0,
    });
    expect(high.weekStartsOn, 7);
    expect(high.weeklyReportWeekday, 7);
    expect(high.dailyFocusGoal, AppSettings.maxDailyFocusGoal);
    expect(high.defaultSnoozeMinutes, AppSettings.minutesPerDay);
    expect(high.keepBackups, AppSettings.maxKeepBackups);
    expect(high.clipboardClearSeconds, AppSettings.maxClipboardClearSeconds);
    for (final m in [
      high.quietStartMinutes,
      high.quietEndMinutes,
      high.morningBriefingMinutes,
      high.eveningReviewMinutes,
      high.backupMinutes,
      high.habitResetMinutes,
    ]) {
      expect(m, 1439);
    }
    expect(high.vaultAutoLockMinutes, AppSettings.minutesPerDay);
    expect(high.textScale, 1.3);
  });

  test('in-range values are kept as stored', () {
    final s = AppSettings.fromJson(const {
      'weeklyReportWeekday': 3,
      'quietStartMinutes': 1439,
      'clipboardClearSeconds': 0,
      'keepBackups': 100,
      'dailyFocusGoal': 50,
    });
    expect(s.weeklyReportWeekday, 3);
    expect(s.quietStartMinutes, 1439);
    expect(s.clipboardClearSeconds, 0);
    expect(s.keepBackups, 100);
    expect(s.dailyFocusGoal, 50);
  });

  test('Home sections: saved order kept, newer sections appended, '
      'unknown names dropped', () {
    final s = AppSettings.fromJson(const {
      'homeSections': ['habits', 'gone', 'focus'],
      'hiddenHomeSections': ['notes', 'alsoGone'],
    });
    expect(s.homeSections.take(2), [HomeSection.habits, HomeSection.focus]);
    expect(s.homeSections.toSet(), HomeSection.values.toSet());
    expect(s.homeSections, hasLength(HomeSection.values.length));
    expect(s.hiddenHomeSections, {HomeSection.notes});
    expect(s.visibleHomeSections, isNot(contains(HomeSection.notes)));
  });

  test('lastSyncAt: ISO string parsed, garbage / missing → null', () {
    expect(
      AppSettings.fromJson(const {
        'lastSyncAt': '2026-06-12T09:41:00.000Z',
      }).lastSyncAt,
      DateTime.utc(2026, 6, 12, 9, 41),
    );
    expect(
      AppSettings.fromJson(const {'lastSyncAt': 'yesterday'}).lastSyncAt,
      isNull,
    );
    expect(AppSettings.fromJson(const {'lastSyncAt': 12}).lastSyncAt, isNull);
    expect(AppSettings.fromJson(const {}).lastSyncAt, isNull);
  });

  test('recent searches are capped at 10 when read', () {
    final s = AppSettings.fromJson({
      'recentSearches': [for (var i = 0; i < 15; i++) 'q$i'],
    });
    expect(s.recentSearches, hasLength(10));
    expect(s.recentSearches.first, 'q0');
  });
}
