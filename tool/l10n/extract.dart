// Writes assets/l10n/en.json — the catalogue of every translatable text in the
// app (key = the English text) — from the source. The other packs
// (assets/l10n/<code>.json) translate exactly these keys; the catalogue test
// (test/core/l10n/catalog_test.dart) fails when a key is missing from a pack
// or a `tr()` call is not extractable.
//
//   dart run --packages=.dart_tool/package_config.json tool/l10n/extract.dart
//   (add --check to only verify that en.json is up to date)
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'catalog.dart';

void main(List<String> args) {
  final scan = scanCatalog();
  final keys = scan.keys.keys.toList()..sort();
  final json = const JsonEncoder.withIndent('  ').convert({for (final k in keys) k: k});
  final out = File('assets/l10n/en.json');

  if (scan.interpolated.isNotEmpty) {
    print('tr() with an interpolated key (use {name} placeholders):');
    scan.interpolated.forEach(print);
  }
  if (scan.dynamicCalls.isNotEmpty) {
    print('tr() with a non-literal key (register it in static_keys.dart): ${scan.dynamicCalls.length}');
  }

  if (args.contains('--check')) {
    final current = out.existsSync() ? out.readAsStringSync().replaceAll('\r\n', '\n') : '';
    if (current.trim() != json.trim()) {
      print('assets/l10n/en.json is out of date: run tool/l10n/extract.dart');
      exit(1);
    }
    print('en.json is up to date (${keys.length} keys).');
    return;
  }
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('$json\n');
  print('wrote ${keys.length} keys to assets/l10n/en.json');
}
