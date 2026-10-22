/// Every screen of the app in each added language, at the smallest supported
/// width (360 pt) and the largest text size (1.3): no overflow or other
/// framework error, and Arabic lays out right to left. The real packs are
/// read from assets/l10n, so this also exercises the whole `tr` pipeline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/l10n/app_language.dart';
import 'package:focusflow/core/l10n/language_service.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:intl/intl.dart' show Intl;

import '../helpers/screen_harness.dart';
import '../helpers/test_container.dart';
import 'calendar/calendar_seed.dart';
import 'reminders/isolated_notifications.dart';

/// The screens worth checking: every tab, the editors and the settings pages.
const _routes = <String>[
  AppRoutes.home,
  AppRoutes.library,
  AppRoutes.insights,
  AppRoutes.settings,
  AppRoutes.notes,
  AppRoutes.tasks,
  AppRoutes.reminders,
  AppRoutes.habits,
  AppRoutes.calendar,
  AppRoutes.search,
  AppRoutes.notificationCenter,
  AppRoutes.newTaskPath,
  AppRoutes.newReminderPath,
  AppRoutes.newHabitPath,
  AppRoutes.settingsNotifications,
  AppRoutes.settingsAppearance,
  AppRoutes.settingsGeneral,
  AppRoutes.settingsLanguage,
  AppRoutes.settingsBackup,
  AppRoutes.settingsAppLock,
  AppRoutes.settingsAbout,
];

void main() {
  tearDown(() {
    L10n.reset();
    Intl.defaultLocale = 'en';
  });

  for (final language in AppLanguage.values.where((l) => l != AppLanguage.en)) {
    testWidgets('${language.englishName}: no layout errors on any screen', (
      tester,
    ) async {
      await loadAppFonts();
      final h = (await tester.runAsync(
        () => TestHarness.create(
          now: calendarNow,
          overrides: isolatedNotifications(),
        ),
      ))!;
      addTearDown(() => tester.runAsync(h.dispose));
      // Mockup data: tasks, notes, reminders and habits, so rows are real.
      await tester.runAsync(() => seedCalendarMockup(h));
      await tester.runAsync(() => activateLanguage(language));
      expect(L10n.language, language, reason: 'pack loaded');
      await h.updateSettings(
        (s) => s.copyWith(
          languageCode: language.code,
          enabledLanguages: [language.code],
        ),
      );

      for (final route in _routes) {
        await pumpApp(
          tester,
          h,
          route,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        final error = tester.takeException();
        expect(error, isNull, reason: '${language.code} $route: $error');
        final direction = Directionality.of(
          tester.element(find.byType(Scaffold).first),
        );
        expect(
          direction,
          language.rtl ? TextDirection.rtl : TextDirection.ltr,
          reason: '${language.code} $route',
        );
      }
    });
  }
}
