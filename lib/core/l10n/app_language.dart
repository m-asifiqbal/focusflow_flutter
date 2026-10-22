/// ============================================================
/// APP LANGUAGE — the languages FocusFlow can speak
/// ============================================================
///
/// What: the fixed list of languages, with the facts the app needs about
/// each (stored code, names, Locale, writing direction, plural rules, where
/// its pack lives).
/// Why: English is the source language (the text in the code *is* the key),
/// so it needs no pack and is always available. The other six packs are
/// bundled as small JSON files (`assets/l10n/<code>.json`) but stay unused
/// until the user adds one in Settings › Language — see language_service.dart.
/// ============================================================
library;

import 'package:flutter/widgets.dart';

enum AppLanguage {
  en('en', 'English', 'English'),
  bn('bn', 'Bangla', 'বাংলা'),
  ar('ar', 'Arabic', 'العربية', rtl: true),
  zh('zh', 'Chinese (Simplified)', '简体中文'),
  hi('hi', 'Hindi', 'हिन्दी'),
  de('de', 'German', 'Deutsch'),
  es('es', 'Spanish', 'Español');

  const AppLanguage(
    this.code,
    this.englishName,
    this.nativeName, {
    this.rtl = false,
  });

  /// Stored in the settings (`AppSettings.languageCode`) and the pack's file name.
  final String code;
  final String englishName;

  /// The language's own name for itself — what the picker shows.
  final String nativeName;

  /// Written right to left (the layout mirrors).
  final bool rtl;

  static const AppLanguage fallback = AppLanguage.en;

  /// Whether documents drawn with the app's Latin-only PDF fonts (Helvetica,
  /// Nunito) can show this language. Bangla, Arabic, Chinese and Hindi need a
  /// font with those glyphs; their printed documents stay English instead of
  /// showing empty boxes.
  bool get printable => this == en || this == de || this == es;

  Locale get locale => Locale(code);

  /// Bundled translation pack. English has none: its text is the key.
  String? get assetPath => this == en ? null : 'assets/l10n/$code.json';

  /// The language for a stored [code]; English for anything unknown.
  static AppLanguage fromCode(String? code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return fallback;
  }

  /// Plural category of the whole number [n] (CLDR cardinal rules for the
  /// bundled languages; Western digits throughout the app).
  String pluralCategory(int n) {
    final a = n.abs();
    switch (this) {
      case AppLanguage.en:
      case AppLanguage.de:
      case AppLanguage.es:
        return a == 1 ? 'one' : 'other';
      case AppLanguage.hi:
      case AppLanguage.bn:
        return a <= 1 ? 'one' : 'other';
      case AppLanguage.zh:
        return 'other';
      case AppLanguage.ar:
        if (a == 0) return 'zero';
        if (a == 1) return 'one';
        if (a == 2) return 'two';
        final m = a % 100;
        if (m >= 3 && m <= 10) return 'few';
        if (m >= 11) return 'many';
        return 'other';
    }
  }
}
