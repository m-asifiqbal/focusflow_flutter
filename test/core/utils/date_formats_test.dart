/// DateFormats.of caches one formatter per pattern and locale (list rows used
/// to build a new one on every rebuild) without changing what is printed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  final day = DateTime(2026, 6, 13, 21, 5);

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  test('the same pattern gives the same formatter', () {
    expect(identical(DateFormats.of('MMM d'), DateFormats.of('MMM d')), isTrue);
    expect(
      identical(DateFormats.of('MMM d'), DateFormats.of('MMM d, y')),
      isFalse,
    );
  });

  test('it prints exactly what a fresh DateFormat prints', () {
    for (final pattern in [
      'MMM d',
      'EEE, MMM d',
      'EEEE, MMMM d',
      'h:mm a',
      'HH:mm',
      'hh:mm a',
      'MMM d, y',
      'd MMM y · h:mm a',
    ]) {
      expect(
        DateFormats.of(pattern).format(day),
        DateFormat(pattern).format(day),
        reason: pattern,
      );
    }
  });

  test('a locale argument is part of the key', () {
    final en = DateFormats.of('EEEE', 'en');
    expect(identical(en, DateFormats.of('EEEE', 'en')), isTrue);
    expect(en.format(day), 'Saturday');
  });

  test('the default locale is part of the key', () {
    final before = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = before);
    Intl.defaultLocale = 'en_GB';
    final gb = DateFormats.of('MMM d');
    Intl.defaultLocale = 'en_US';
    final us = DateFormats.of('MMM d');
    expect(identical(gb, us), isFalse);
  });
}
