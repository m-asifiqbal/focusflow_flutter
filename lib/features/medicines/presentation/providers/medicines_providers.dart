/// ============================================================
/// MEDICINES PROVIDERS — live day plan, detail and the picked day
/// ============================================================
///
/// Every screen reads StreamProviders over MedicinesRepository, so a dose
/// taken from a notification, the Reminders chip or the detail screen
/// updates every other screen at once (rule 5). The detail stats are
/// relative to now ([minuteClockProvider]): a dose becomes "due" or
/// "missed" as the minutes pass.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// The doses of a day and the cabinet.
final medicineDayProvider = StreamProvider.autoDispose
    .family<MedicineDay, DateTime>(
      (ref, day) => ref.watch(medicinesRepositoryProvider).watchDay(day),
    );

/// Day picked in the medicine list's week strip; null = follow today.
class SelectedMedicineDay extends AutoDisposeNotifier<DateTime?> {
  @override
  DateTime? build() => null;

  void select(DateTime? day) => state = day;
}

final selectedMedicineDayProvider =
    NotifierProvider.autoDispose<SelectedMedicineDay, DateTime?>(
      SelectedMedicineDay.new,
    );

/// The day the medicine list shows.
final medicineListDayProvider = Provider.autoDispose<DateTime>(
  (ref) => ref.watch(selectedMedicineDayProvider) ?? ref.watch(todayProvider),
);

/// Medicine + stats, recomputed every minute and on every dose write.
final medicineDetailProvider = StreamProvider.autoDispose
    .family<MedicineDetail?, String>((ref, id) {
      final now = ref.watch(minuteClockProvider);
      return ref.watch(medicinesRepositoryProvider).watchDetail(id, now);
    });

/// One medicine (editor, actions).
final medicineProvider = StreamProvider.autoDispose.family<Medicine?, String>(
  (ref, id) => ref.watch(medicinesRepositoryProvider).watchMedicine(id),
);
