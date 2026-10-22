/// ============================================================
/// HABIT FREQUENCY — how often a habit is due
/// ============================================================
///
/// Value object over the four schedule kinds the habit editor offers:
///   • every day
///   • specific weekdays (bit mask, bit 0 = Monday … bit 6 = Sunday)
///   • N times per week (any days; evaluated per week)
///   • every N days (counted from the habit's start date)
///
/// Pattern-match on the sealed subclasses:
/// ```dart
/// switch (habit.frequency) {
///   EveryDayFrequency() => …,
///   SpecificDaysFrequency(:final weekdaysMask) => …,
///   TimesPerWeekFrequency(:final times) => …,
///   EveryNDaysFrequency(:final days) => …,
/// }
/// ```
/// Storage mapping (habits table): frequencyType 0/1/2/3 + weekdaysMask /
/// timesPerWeek / everyNDays — see [typeCode].
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';

@immutable
sealed class HabitFrequency {
  const HabitFrequency();

  const factory HabitFrequency.everyDay() = EveryDayFrequency;

  /// [weekdaysMask]: bit 0 = Monday … bit 6 = Sunday.
  const factory HabitFrequency.specificDays(int weekdaysMask) =
      SpecificDaysFrequency;
  const factory HabitFrequency.timesPerWeek(int times) = TimesPerWeekFrequency;
  const factory HabitFrequency.everyNDays(int days) = EveryNDaysFrequency;

  /// Monday–Friday.
  static const HabitFrequency weekdays = SpecificDaysFrequency(0x1F);

  /// Specific days from `DateTime.monday … DateTime.sunday` values.
  factory HabitFrequency.onWeekdays(Iterable<int> weekdays) =>
      SpecificDaysFrequency(maskFor(weekdays));

  /// Rebuilds a frequency from the stored columns.
  factory HabitFrequency.fromStorage({
    required int type,
    int weekdaysMask = 127,
    int timesPerWeek = 3,
    int everyNDays = 2,
  }) => switch (type) {
    1 => SpecificDaysFrequency(weekdaysMask),
    2 => TimesPerWeekFrequency(timesPerWeek),
    3 => EveryNDaysFrequency(everyNDays),
    _ => const EveryDayFrequency(),
  };

  /// 0 every day · 1 specific days · 2 x per week · 3 every N days.
  int get typeCode;

  /// "Every day", "Weekdays", "Mon · Wed · Fri", "3× per week", "Every 2 days".
  String get label;

  /// Bit mask for a set of `DateTime.monday … DateTime.sunday` values.
  static int maskFor(Iterable<int> weekdays) {
    var mask = 0;
    for (final d in weekdays) {
      if (d >= DateTime.monday && d <= DateTime.sunday) mask |= 1 << (d - 1);
    }
    return mask;
  }

  /// Whether [mask] includes [weekday] (`DateTime.monday … sunday`).
  static bool maskHas(int mask, int weekday) =>
      (mask >> (weekday - 1)) & 1 == 1;

  /// Weekday numbers (`DateTime.monday …`) contained in [mask], ascending.
  static List<int> weekdaysOf(int mask) => [
    for (var d = DateTime.monday; d <= DateTime.sunday; d++)
      if (maskHas(mask, d)) d,
  ];

  /// Short name of [weekday] (`DateTime.monday … sunday`): "Mon" … "Sun".
  static String shortName(int weekday) => switch (weekday) {
    DateTime.monday => tr('Mon'),
    DateTime.tuesday => tr('Tue'),
    DateTime.wednesday => tr('Wed'),
    DateTime.thursday => tr('Thu'),
    DateTime.friday => tr('Fri'),
    DateTime.saturday => tr('Sat'),
    _ => tr('Sun'),
  };
}

final class EveryDayFrequency extends HabitFrequency {
  const EveryDayFrequency();

  @override
  int get typeCode => 0;

  @override
  String get label => tr('Every day');

  @override
  bool operator ==(Object other) => other is EveryDayFrequency;

  @override
  int get hashCode => 0;
}

final class SpecificDaysFrequency extends HabitFrequency {
  const SpecificDaysFrequency(this.weekdaysMask);

  /// Bit 0 = Monday … bit 6 = Sunday.
  final int weekdaysMask;

  @override
  int get typeCode => 1;

  /// `DateTime.monday … DateTime.sunday` values, ascending.
  List<int> get weekdays => HabitFrequency.weekdaysOf(weekdaysMask);

  bool includes(int weekday) => HabitFrequency.maskHas(weekdaysMask, weekday);

  @override
  String get label {
    final m = weekdaysMask & 0x7F;
    if (m == 0x7F) return tr('Every day');
    if (m == 0x1F) return tr('Weekdays');
    if (m == 0x60) return tr('Weekends');
    if (m == 0) return tr('No days');
    return weekdays.map(HabitFrequency.shortName).join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      other is SpecificDaysFrequency && other.weekdaysMask == weekdaysMask;

  @override
  int get hashCode => Object.hash(1, weekdaysMask);
}

final class TimesPerWeekFrequency extends HabitFrequency {
  const TimesPerWeekFrequency(this.times);

  /// Check-ins required per week (1–7).
  final int times;

  @override
  int get typeCode => 2;

  @override
  String get label => tr('{times}× per week', {'times': times});

  @override
  bool operator ==(Object other) =>
      other is TimesPerWeekFrequency && other.times == times;

  @override
  int get hashCode => Object.hash(2, times);
}

final class EveryNDaysFrequency extends HabitFrequency {
  const EveryNDaysFrequency(this.days);

  /// Interval in days (counted from the habit's start date).
  final int days;

  @override
  int get typeCode => 3;

  @override
  String get label => days <= 1
      ? tr('Every day')
      : tr('{days, plural, one {Every # day} other {Every # days}}', {
          'days': days,
        });

  @override
  bool operator ==(Object other) =>
      other is EveryNDaysFrequency && other.days == days;

  @override
  int get hashCode => Object.hash(3, days);
}
