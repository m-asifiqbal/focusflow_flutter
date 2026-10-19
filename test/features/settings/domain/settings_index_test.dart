/// Settings search index: every sub-page row is findable by the words the
/// UI shows, and deep-links to its page.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/settings/domain/entities/settings_entry.dart';
import 'package:focusflow/features/settings/domain/services/settings_index.dart';

void main() {
  final cases = <String, String>{
    'clear cache': AppRoutes.settingsStorage,
    'licences': AppRoutes.settingsAbout,
    'licenses': AppRoutes.settingsAbout,
    'privacy policy': AppRoutes.settingsAbout,
    'terms of use': AppRoutes.settingsAbout,
    'day resets': AppRoutes.settingsModule('habits'),
    'colour of new notes': AppRoutes.settingsModule('notes'),
    'sort by': AppRoutes.settingsModule('notes'),
    'smart lists': AppRoutes.settingsModule('tasks'),
    'show completed': AppRoutes.settingsModule('tasks'),
    'default list': AppRoutes.settingsModule('tasks'),
    'in-app sounds': AppRoutes.settingsSoundsHaptics,
    'try haptics': AppRoutes.settingsSoundsHaptics,
    'haptic feedback': AppRoutes.settingsSoundsHaptics,
    'swipe left': AppRoutes.settingsGestures,
    'swipe right': AppRoutes.settingsGestures,
    'show item counts': AppRoutes.settingsHomeLayout,
    'lock focus': AppRoutes.settingsAppLock,
    'merge': AppRoutes.settingsTagsFolders,
    'date format': AppRoutes.settingsGeneral,
    'date & time': AppRoutes.settingsGeneral,
    'keep alarms running': AppRoutes.settingsNotifications,
    'swipe away': AppRoutes.settingsNotifications,
    'visual effects': AppRoutes.settingsAppearance,
    'lag': AppRoutes.settingsAppearance,
  };

  for (final MapEntry(key: query, value: route) in cases.entries) {
    test('"$query" finds a row on $route', () {
      final hits = searchSettings(SettingsIndex.all, query);
      expect(hits, isNotEmpty);
      expect(hits.first.route, route);
    });
  }

  test('every entry has a destination', () {
    for (final e in SettingsIndex.all) {
      expect(e.route != null || e.action != null, isTrue, reason: e.title);
    }
  });
}
