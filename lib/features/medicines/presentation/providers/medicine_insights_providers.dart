/// ============================================================
/// MEDICINE INSIGHTS PROVIDERS — Insights › Medicine
/// ============================================================
///
/// The picked period (Daily · Monthly · Yearly, kept while the app runs)
/// and the live [MedicineInsights] of it. "Now" moves in 15-minute steps:
/// often enough for doses to turn "missed" as their time passes, rarely
/// enough that the yearly pass (a background isolate) isn't re-run every
/// minute while the tab is open.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_insights.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

class MedicinePeriodController extends Notifier<MedicinePeriod> {
  @override
  MedicinePeriod build() => MedicinePeriod.daily;

  void select(MedicinePeriod p) => state = p;
}

final medicinePeriodProvider =
    NotifierProvider<MedicinePeriodController, MedicinePeriod>(
      MedicinePeriodController.new,
    );

/// [minuteClockProvider] rounded down to a quarter hour.
final _quarterHourProvider = Provider.autoDispose<DateTime>((ref) {
  final t = ref.watch(minuteClockProvider);
  return DateTime(t.year, t.month, t.day, t.hour, t.minute - t.minute % 15);
});

final medicineInsightsProvider = StreamProvider.autoDispose
    .family<MedicineInsights, MedicinePeriod>((ref, period) {
      final now = ref.watch(_quarterHourProvider);
      return ref.watch(medicinesRepositoryProvider).watchInsights(period, now);
    });
