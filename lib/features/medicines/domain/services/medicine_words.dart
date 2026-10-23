/// ============================================================
/// MEDICINE WORDS — amounts, forms, food timing and schedules as text
/// ============================================================
///
/// One place for every way a medicine is described, in the active language,
/// so the lists, the detail screen and the notifications read the same:
/// "1 tablet", "2.5 ml", "After food", "Mon, Wed, Fri", "6 tablets left".
/// Amounts are numbers of the medicine's form; fractional amounts (½ tablet,
/// 2.5 ml) are shown with up to two decimals and use the plural form.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';

abstract final class MedicineWords {
  /// `1`, `0.5`, `2.25` (no trailing zeros).
  static String number(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    var s = q.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// "1 tablet", "2 tablets", "5 ml", "2 puffs".
  static String amount(double q, MedicineForm form) {
    final whole = q == q.roundToDouble();
    // A fractional amount reads as a plural ("0.5 tablets") everywhere: a
    // large whole number picks the "other" branch in every language.
    final count = whole ? q.toInt() : 100;
    final args = {'count': count, 'q': number(q)};
    return switch (form) {
      MedicineForm.tablet => tr(
        '{count, plural, one {{q} tablet} other {{q} tablets}}',
        args,
      ),
      MedicineForm.capsule => tr(
        '{count, plural, one {{q} capsule} other {{q} capsules}}',
        args,
      ),
      MedicineForm.liquid => tr('{q} ml', args),
      MedicineForm.drops => tr(
        '{count, plural, one {{q} drop} other {{q} drops}}',
        args,
      ),
      MedicineForm.injection => tr(
        '{count, plural, one {{q} injection} other {{q} injections}}',
        args,
      ),
      MedicineForm.inhaler => tr(
        '{count, plural, one {{q} puff} other {{q} puffs}}',
        args,
      ),
      MedicineForm.other => tr(
        '{count, plural, one {{q} dose} other {{q} doses}}',
        args,
      ),
    };
  }

  /// "6 tablets left".
  static String left(double q, MedicineForm form) =>
      tr('{amount} left', {'amount': amount(q, form)});

  static String form(MedicineForm f) => switch (f) {
    MedicineForm.tablet => tr('Tablet'),
    MedicineForm.capsule => tr('Capsule'),
    MedicineForm.liquid => tr('Liquid'),
    MedicineForm.drops => tr('Drops'),
    MedicineForm.injection => tr('Injection'),
    MedicineForm.inhaler => tr('Inhaler'),
    MedicineForm.other => tr('Other'),
  };

  static String food(FoodTiming f) => switch (f) {
    FoodTiming.anyTime => tr('Any time'),
    FoodTiming.beforeFood => tr('Before food'),
    FoodTiming.withFood => tr('With food'),
    FoodTiming.afterFood => tr('After food'),
  };

  /// Food timing for a meta line: lower case and empty for "any time".
  static String? foodNote(FoodTiming f) => switch (f) {
    FoodTiming.anyTime => null,
    FoodTiming.beforeFood => tr('before food'),
    FoodTiming.withFood => tr('with food'),
    FoodTiming.afterFood => tr('after food'),
  };

  /// "Every day", "Mon, Wed, Fri", "Every 3 days", "As needed".
  static String schedule(Medicine m) => switch (m.schedule) {
    MedicineScheduleType.everyDay => tr('Every day'),
    MedicineScheduleType.specificDays => weekdays(m.weekdaysMask),
    MedicineScheduleType.everyNDays => tr(
      '{count, plural, one {Every day} other {Every # days}}',
      {'count': m.everyNDays},
    ),
    MedicineScheduleType.asNeeded => tr('As needed'),
  };

  /// Short weekday names of [mask] (bit 0 = Monday), "Weekdays" for Mon–Fri
  /// and "Every day" for all seven.
  static String weekdays(int mask) {
    final m = mask & 0x7F;
    if (m == 0x7F) return tr('Every day');
    if (m == 0x1F) return tr('Weekdays');
    if (m == 0x60) return tr('Weekends');
    final names = <String>[];
    for (var i = 0; i < 7; i++) {
      if (m & (1 << i) == 0) continue;
      // 2024-01-01 was a Monday.
      names.add(DateFormats.of('EEE').format(DateTime(2024, 1, 1 + i)));
    }
    return names.join(', ');
  }

  /// "2× daily", "3× daily" — how often per scheduled day.
  static String timesPerDay(int n) =>
      tr('{count, plural, one {Once a day} other {#× a day}}', {'count': n});

  /// "500 mg · 1 tablet · after food" — the meta line of one dose.
  static String doseLine(Medicine m, double quantity) => [
    if (m.strength.trim().isNotEmpty) m.strength.trim(),
    amount(quantity, m.form),
    ?foodNote(m.foodTiming),
  ].join(' · ');
}
