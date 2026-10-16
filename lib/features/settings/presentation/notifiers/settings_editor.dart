/// ============================================================
/// SETTINGS EDITOR — typed writes for the Settings root & sub-pages
/// ============================================================
///
/// What: one method per setting changed from screen 30, 32 and the
/// sub-pages (general, home layout, gestures, sounds, app lock, module
/// defaults), each a
/// thin `settingsProvider.notifier.update(...)`.
/// Why: keeps `copyWith` plumbing (and clamping) out of the widgets; every
/// write persists and takes effect app-wide immediately because the whole
/// app watches [settingsProvider].
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class SettingsEditor {
  const SettingsEditor(this._ref);

  final Ref _ref;

  /// Text-size stops of the Appearance slider (1.0 sits in the middle).
  static const textScaleStops = [0.85, 0.9, 0.95, 1.0, 1.1, 1.2, 1.3];

  Future<void> _set(AppSettings Function(AppSettings s) change) =>
      _ref.read(settingsProvider.notifier).update(change);

  Future<void> setLanguage(String code) =>
      _set((s) => s.copyWith(languageCode: code));

  Future<void> setStartScreen(StartScreen v) =>
      _set((s) => s.copyWith(startScreen: v));

  Future<void> setWeekStart(int weekday) =>
      _set((s) => s.copyWith(weekStartsOn: weekday.clamp(1, 7)));

  Future<void> setUse24Hour(bool v) =>
      _set((s) => s.copyWith(use24HourTime: v));

  Future<void> setHideInAppSwitcher(bool v) =>
      _set((s) => s.copyWith(hideInAppSwitcher: v));

  // Clear clipboard after: a vault security setting, written only by
  // Settings › Vault security after re-auth (VaultSecuritySettingsController).

  Future<void> setThemeMode(ThemeMode v) =>
      _set((s) => s.copyWith(themeMode: v));

  Future<void> setAccent(AccentColor v) => _set((s) => s.copyWith(accent: v));

  /// Snaps to the nearest of [textScaleStops].
  Future<void> setTextScale(double v) {
    var best = textScaleStops.first;
    for (final stop in textScaleStops) {
      if ((stop - v).abs() < (best - v).abs()) best = stop;
    }
    return _set((s) => s.copyWith(textScale: best));
  }

  Future<void> setNotesView(NotesView v) =>
      _set((s) => s.copyWith(notesView: v));

  Future<void> setListDensity(ListDensity v) =>
      _set((s) => s.copyWith(listDensity: v));

  Future<void> setReduceMotion(bool v) =>
      _set((s) => s.copyWith(reduceMotion: v));

  Future<void> setUseSystemFont(bool v) =>
      _set((s) => s.copyWith(useSystemFont: v));

  // ── General ──
  Future<void> setDateFormat(String pattern) =>
      _set((s) => s.copyWith(dateFormat: pattern));

  // ── Home layout ──
  /// Persists the Home section order (hidden sections keep their slot).
  Future<void> setHomeOrder(List<HomeSection> order) =>
      _set((s) => s.copyWith(homeSections: List.unmodifiable(order)));

  Future<void> setHomeSectionVisible(HomeSection section, bool visible) =>
      _set((s) {
        final hidden = {...s.hiddenHomeSections};
        visible ? hidden.remove(section) : hidden.add(section);
        return s.copyWith(hiddenHomeSections: hidden);
      });

  Future<void> resetHomeLayout() => _set(
    (s) => s.copyWith(homeSections: HomeSection.values, hiddenHomeSections: {}),
  );

  Future<void> setDailyFocusGoal(int v) =>
      _set((s) => s.copyWith(dailyFocusGoal: v.clamp(1, 20)));

  Future<void> setLibraryShowCounts(bool v) =>
      _set((s) => s.copyWith(libraryShowCounts: v));

  // ── Gestures, sounds ──
  // (App lock is switched by AppLockController.setEnabled — it needs
  // the device owner.)
  Future<void> setSwipeLeft(SwipeAction v) =>
      _set((s) => s.copyWith(swipeLeft: v));

  Future<void> setSwipeRight(SwipeAction v) =>
      _set((s) => s.copyWith(swipeRight: v));

  Future<void> setSounds(bool v) => _set((s) => s.copyWith(soundsEnabled: v));

  Future<void> setHaptics(bool v) => _set((s) => s.copyWith(hapticsEnabled: v));

  // ── Module defaults ──
  Future<void> setNotesSort(NotesSort v) =>
      _set((s) => s.copyWith(notesSort: v));

  Future<void> setNotesDefaultColor(String? hex) =>
      _set((s) => s.copyWith(notesDefaultColor: () => hex));

  Future<void> setTasksDefaultList(String? id) =>
      _set((s) => s.copyWith(tasksDefaultListId: () => id));

  Future<void> setTasksShowCompleted(bool v) =>
      _set((s) => s.copyWith(tasksShowCompleted: v));

  Future<void> setTasksSmartLists(bool v) =>
      _set((s) => s.copyWith(tasksSmartLists: v));

  Future<void> setDefaultSnooze(int minutes) =>
      _set((s) => s.copyWith(defaultSnoozeMinutes: minutes.clamp(1, 24 * 60)));

  Future<void> setReminderSound(String key) =>
      _set((s) => s.copyWith(remindersDefaultSound: key));

  Future<void> setHabitResetMinutes(int minutes) =>
      _set((s) => s.copyWith(habitResetMinutes: minutes % (24 * 60)));

  /// Index of the slider stop closest to [scale].
  static int stopIndexOf(double scale) {
    var best = 0;
    for (var i = 0; i < textScaleStops.length; i++) {
      if ((textScaleStops[i] - scale).abs() <
          (textScaleStops[best] - scale).abs()) {
        best = i;
      }
    }
    return best;
  }
}

final settingsEditorProvider = Provider<SettingsEditor>(SettingsEditor.new);
