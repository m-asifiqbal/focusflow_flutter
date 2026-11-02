/// A quick-start habit is saved under its English name and shown in the
/// active language; a name the person typed is shown as typed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/l10n/app_language.dart';
import 'package:focusflow/core/l10n/l10n.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';

void main() {
  tearDown(L10n.reset);

  test('displayName follows the language for catalogue names only', () {
    final now = DateTime(2026);
    final habit = Habit.draft(startDate: now).copyWith(name: 'Meditate');
    expect(habit.displayName, 'Meditate');
    L10n.activate(AppLanguage.bn, const {'Meditate': 'ধ্যান'});
    expect(habit.displayName, 'ধ্যান');
    expect(habit.copyWith(name: 'My own habit').displayName, 'My own habit');
  });
}
