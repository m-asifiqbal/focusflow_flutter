/// The translation catalogue stays complete: every text the app translates
/// (`tr('…')` calls + static_keys.dart) is in assets/l10n/en.json and in every
/// language pack, with the same placeholders and valid plural forms. Fails
/// the build when a new string is added without translating it:
///
///   dart run --packages=.dart_tool/package_config.json tool/l10n/extract.dart
///   (then add the new keys to the six packs)
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/l10n/app_language.dart';
import 'package:focusflow/core/l10n/l10n.dart';

import '../../../tool/l10n/catalog.dart';

Map<String, String> _pack(String code) {
  final raw = File('assets/l10n/$code.json').readAsStringSync();
  return (jsonDecode(raw) as Map).cast<String, String>();
}

/// Index of the `}` closing the `{` at [open], or -1.
int _close(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '{') depth++;
    if (s[i] == '}' && --depth == 0) return i;
  }
  return -1;
}

/// Walks the template: placeholder names (plural selector variables too) and
/// the selectors (`one`, `other`, `=0` …) of every plural block.
void _walk(String text, Set<String> names, Set<String> selectors) {
  var i = 0;
  while (i < text.length) {
    if (text[i] != '{') {
      i++;
      continue;
    }
    final end = _close(text, i);
    if (end < 0) return;
    final body = text.substring(i + 1, end);
    final comma = body.indexOf(',');
    if (comma < 0) {
      names.add(body.trim());
    } else {
      names.add(body.substring(0, comma).trim());
      final branches = body
          .substring(comma + 1)
          .trimLeft()
          .replaceFirst(RegExp(r'^plurals*,'), '');
      var j = 0;
      while (j < branches.length) {
        final open = branches.indexOf('{', j);
        if (open < 0) break;
        final close = _close(branches, open);
        if (close < 0) break;
        selectors.add(branches.substring(j, open).trim());
        _walk(branches.substring(open + 1, close), names, selectors);
        j = close + 1;
      }
    }
    i = end + 1;
  }
}

Set<String> _placeholders(String text) {
  final names = <String>{};
  _walk(text, names, <String>{});
  return names;
}

/// Selectors used by the plural blocks of [text].
Set<String> _pluralCategories(String text) {
  final selectors = <String>{};
  _walk(text, <String>{}, selectors);
  return selectors;
}

void main() {
  late CatalogScan scan;
  late List<String> keys;

  setUpAll(() {
    scan = scanCatalog();
    keys = scan.keys.keys.toList()..sort();
  });

  test('every tr() key is a plain literal', () {
    expect(
      scan.interpolated,
      isEmpty,
      reason: 'use {name} placeholders, not \$interpolation',
    );
  });

  test('dynamic tr(variable) calls only translate registered keys', () {
    // `tr(entry.label)` is fine: the label is registered in static_keys.dart.
    // This guards against a runaway count of unregistered dynamic calls.
    expect(scan.dynamicCalls.length, lessThan(60));
  });

  test('en.json is the sorted list of every key', () {
    final en =
        (jsonDecode(File('assets/l10n/en.json').readAsStringSync()) as Map)
            .cast<String, String>();
    expect(
      en.keys.toList(),
      keys,
      reason:
          'run: dart run --packages=.dart_tool/package_config.json tool/l10n/extract.dart',
    );
    expect(en.entries.every((e) => e.key == e.value), isTrue);
  });

  for (final language in AppLanguage.values.where((l) => l != AppLanguage.en)) {
    group('pack ${language.code}', () {
      late Map<String, String> pack;
      setUpAll(() => pack = _pack(language.code));

      test('has every key, and nothing else', () {
        final missing = [
          for (final k in keys)
            if ((pack[k] ?? '').trim().isEmpty) k,
        ];
        expect(
          missing,
          isEmpty,
          reason: '${missing.length} untranslated, first: ${missing.take(5)}',
        );
        final extra = pack.keys
            .where((k) => !scan.keys.containsKey(k))
            .toList();
        expect(extra, isEmpty, reason: 'stale keys: ${extra.take(5)}');
      });

      test('keeps the placeholders of the English text', () {
        final bad = <String>[];
        for (final k in keys) {
          final v = pack[k];
          if (v == null) continue;
          if (!_sameSet(_placeholders(k), _placeholders(v))) bad.add(k);
        }
        expect(
          bad,
          isEmpty,
          reason: 'placeholder mismatch, first: ${bad.take(5)}',
        );
      });

      test(
        'uses only plural categories the language has, and always `other`',
        () {
          const allowed = {
            'one', 'other', // en de es hi bn
            'zero', 'two', 'few', 'many', // ar
          };
          final languageCategories = {
            for (final n in List.generate(300, (i) => i))
              language.pluralCategory(n),
            'other',
          };
          final bad = <String>[];
          for (final k in keys) {
            final v = pack[k];
            if (v == null) continue;
            if (!RegExp(r'\{\s*\w+\s*,\s*plural\s*,').hasMatch(v)) continue;
            final cats = _pluralCategories(v);
            final ok =
                cats.contains('other') &&
                cats.every(
                  (c) => allowed.contains(c) || RegExp(r'^=\d+$').hasMatch(c),
                ) &&
                cats
                    .where((c) => allowed.contains(c))
                    .every(languageCategories.contains);
            if (!ok) bad.add(k);
          }
          expect(
            bad,
            isEmpty,
            reason: 'bad plural block, first: ${bad.take(5)}',
          );
        },
      );

      test('every value formats without error', () {
        for (final k in keys) {
          final v = pack[k];
          if (v == null) continue;
          final args = {for (final n in _placeholders(k)) n: 3};
          expect(
            () => L10n.format(v, args, language),
            returnsNormally,
            reason: k,
          );
        }
      });
    });
  }
}

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
