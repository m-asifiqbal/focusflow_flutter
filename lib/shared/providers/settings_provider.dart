/// ============================================================
/// SETTINGS PROVIDER — read: ref.watch(settingsProvider)
///                     write: ref.read(settingsProvider.notifier).update(...)
/// ============================================================
///
/// Synchronous (prefs are preloaded in main), persisted as one JSON blob.
/// ```dart
/// ref.read(settingsProvider.notifier).update((s) => s.copyWith(accent: AccentColor.blue));
/// ```
/// ============================================================
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

class SettingsController extends Notifier<AppSettings> {
  static const String prefsKey = 'app_settings_v1';

  @override
  AppSettings build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(prefsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } catch (e) {
      AppLogger.w('Settings blob unreadable, using defaults: $e');
      return const AppSettings();
    }
  }

  /// Applies [change] and persists the result.
  Future<void> update(AppSettings Function(AppSettings s) change) async {
    final next = change(state);
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setString(prefsKey, jsonEncode(next.toJson()));
  }

  /// Records a search term (dedup, newest first, max 10).
  Future<void> addRecentSearch(String term) {
    final t = term.trim();
    if (t.isEmpty) return Future.value();
    return update((s) {
      final list = [t, ...s.recentSearches.where((x) => x != t)];
      return s.copyWith(recentSearches: list.take(10).toList());
    });
  }

  Future<void> clearRecentSearches() =>
      update((s) => s.copyWith(recentSearches: const []));

  /// Restores every default but keeps onboarding/account state.
  Future<void> resetToDefaults() => update(
    (s) => const AppSettings().copyWith(
      onboardingSeen: s.onboardingSeen,
      accountMode: s.accountMode,
      displayName: s.displayName,
    ),
  );
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
