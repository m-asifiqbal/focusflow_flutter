/// A practice added from a tradition is saved under its English name and
/// shown in the active language; a typed name is left alone.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/l10n/app_language.dart';
import 'package:focusflow/core/l10n/l10n.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';

void main() {
  tearDown(L10n.reset);

  test('tradition practices follow the language, typed names do not', () {
    final now = DateTime(2026);
    final fajr = Prayer.draft(
      name: 'Fajr',
      tradition: PrayerTradition.islam,
      now: now,
    );
    final mine = fajr.copyWith(tradition: PrayerTradition.custom);
    expect(fajr.displayName, 'Fajr');
    L10n.activate(AppLanguage.bn, const {'Fajr': 'ফজর'});
    expect(fajr.displayName, 'ফজর');
    expect(mine.displayName, 'Fajr');
    expect(fajr.copyWith(name: 'My dawn prayer').displayName, 'My dawn prayer');
  });
}
