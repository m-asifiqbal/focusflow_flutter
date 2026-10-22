/// ============================================================
/// LANGUAGE SERVICE — loading, adding, removing and switching languages
/// ============================================================
///
/// What: English is always there. Every other language is a bundled pack
/// (`assets/l10n/<code>.json`, text only) that does nothing until the user
/// *adds* it in Settings › Language (`AppSettings.enabledLanguages`); only
/// added languages can be selected, and only the selected pack is ever read
/// into memory. Removing the language in use switches back to English.
/// Why bundled and not downloaded: the app is offline-first (no network code
/// beyond Google Drive, the opt-in breach check and links the user taps) and
/// a text pack is a few dozen kilobytes.
///
/// Switching rebuilds the whole widget tree once ([rebuildEverything]):
/// strings are plain `tr()` calls in `build` methods (const widgets included),
/// so nothing else would re-read them. Dates follow the language through
/// `Intl.defaultLocale`; numbers keep Western digits.
/// ============================================================
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/app_language.dart';
import 'package:focusflow/core/l10n/l10n.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads a language pack from the bundle; throws when it is missing or broken.
Future<Map<String, String>> loadLanguagePack(
  AppLanguage language, {
  AssetBundle? bundle,
}) async {
  final path = language.assetPath;
  if (path == null) return const {};
  final raw = await (bundle ?? rootBundle).loadString(path);
  final json = jsonDecode(raw) as Map<String, Object?>;
  return {
    for (final e in json.entries)
      if (e.value is String && (e.value! as String).isNotEmpty)
        e.key: e.value! as String,
  };
}

/// The language a stored [settings] value stands for: the chosen one if it
/// is English or has been added, otherwise English.
AppLanguage storedLanguage(AppSettings settings) {
  final l = AppLanguage.fromCode(settings.languageCode);
  if (l == AppLanguage.en || settings.enabledLanguages.contains(l.code)) {
    return l;
  }
  return AppLanguage.en;
}

/// Makes [language] the active one (pack + date locale). Falls back to
/// English, loudly in the log, if the pack cannot be read.
Future<AppLanguage> activateLanguage(
  AppLanguage language, {
  AssetBundle? bundle,
}) async {
  var target = language;
  Map<String, String> pack = const {};
  try {
    pack = await loadLanguagePack(language, bundle: bundle);
  } catch (e) {
    AppLogger.w('Language pack ${language.code} unreadable, using English: $e');
    target = AppLanguage.en;
  }
  L10n.activate(target, pack);
  await _useDateLocale(target);
  return target;
}

Future<void> _useDateLocale(AppLanguage language) async {
  // The date symbols ship inside `intl`; this only loads them into memory.
  await initializeDateFormatting(language.code);
  // Numbers in the app are Western digits everywhere: dates match them.
  DateFormat.useNativeDigitsByDefaultFor(language.code, false);
  Intl.defaultLocale = language.code;
}

/// Startup / background isolates: activates the language saved in [prefs].
Future<void> activateLanguageFromPrefs(SharedPreferences prefs) async {
  try {
    final raw = prefs.getString(SettingsController.prefsKey);
    if (raw == null) return;
    final settings = AppSettings.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
    await activateLanguage(storedLanguage(settings));
  } catch (e) {
    AppLogger.w('Saved language unreadable, using English: $e');
  }
}

/// Rebuilds every element of the running app, state kept — the same thing a
/// hot reload does. Only for a language switch (rare, deliberately wide).
void rebuildEverything() {
  final binding = WidgetsBinding.instance;
  final root = binding.rootElement;
  if (root == null) return;
  binding.buildOwner?.reassemble(root);
}

/// What Settings › Language does.
class LanguageController {
  LanguageController(this._ref, {this._bundle});

  final Ref _ref;
  final AssetBundle? _bundle;

  AppSettings get _settings => _ref.read(settingsProvider);

  /// Languages the user may pick right now (English + the added ones).
  List<AppLanguage> get available => [
    for (final l in AppLanguage.values)
      if (l == AppLanguage.en || _settings.enabledLanguages.contains(l.code)) l,
  ];

  /// Adds [language]: checks its pack reads and parses, then offers it in the
  /// picker. Returns false (and changes nothing) when the pack is unusable.
  Future<bool> add(AppLanguage language) async {
    if (language == AppLanguage.en) return true;
    try {
      await loadLanguagePack(language, bundle: _bundle);
    } catch (e) {
      AppLogger.w('Adding ${language.code} failed: $e');
      return false;
    }
    await _ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            enabledLanguages: {...s.enabledLanguages, language.code}.toList()
              ..sort(),
          ),
        );
    return true;
  }

  /// Removes [language] from the picker; the one in use falls back to English.
  Future<void> remove(AppLanguage language) async {
    if (language == AppLanguage.en) return;
    if (AppLanguage.fromCode(_settings.languageCode) == language) {
      await select(AppLanguage.en);
    }
    await _ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            enabledLanguages: s.enabledLanguages
                .where((c) => c != language.code)
                .toList(),
          ),
        );
  }

  /// Switches the app to [language] (English or an added one). Returns the
  /// language that is now active.
  Future<AppLanguage> select(AppLanguage language) async {
    if (language != AppLanguage.en &&
        !_settings.enabledLanguages.contains(language.code)) {
      return L10n.language;
    }
    final active = await activateLanguage(language, bundle: _bundle);
    await _ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(languageCode: active.code));
    // After this frame: the settings write above rebuilds listeners first.
    WidgetsBinding.instance.addPostFrameCallback((_) => rebuildEverything());
    WidgetsBinding.instance.scheduleFrame();
    return active;
  }
}

final languageControllerProvider = Provider<LanguageController>(
  LanguageController.new,
);
