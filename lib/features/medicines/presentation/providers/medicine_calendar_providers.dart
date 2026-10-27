/// ============================================================
/// MEDICINE CALENDAR PROVIDERS — Month · Year views of the detail screen
/// ============================================================
///
/// Two layers, so the minute tick never touches the database:
///   • [medicineDoseLogsProvider] — the logs of one medicine over a span
///     (a stream that re-emits only when a dose is written);
///   • [medicineCalendarProvider] — the day-by-day states, derived from
///     those logs + the medicine + the minute clock (pure CPU, ≤ 366 days).
/// Both are autoDispose and watched only while Month / Year is selected, so
/// the default Week view costs nothing extra.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_calendar.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_stats.dart';
import 'package:focusflow/features/medicines/presentation/providers/medicines_providers.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Dose logs of one medicine over [MedicineLogSpan].
final medicineDoseLogsProvider = StreamProvider.autoDispose
    .family<List<DoseLog>, MedicineLogSpan>(
      (ref, span) => ref
          .watch(medicinesRepositoryProvider)
          .watchDoseLogs(span.id, span.from, span.to),
    );

/// The days of [MedicineLogSpan] with their dose states (empty while the
/// logs or the medicine load).
final medicineCalendarProvider = Provider.autoDispose
    .family<List<MedicineWeekDay>, MedicineLogSpan>((ref, span) {
      final logs = ref.watch(medicineDoseLogsProvider(span)).valueOrNull;
      // Medicine has value equality: a minute tick that changes nothing
      // about it does not rebuild this.
      final medicine = ref.watch(
        medicineDetailProvider(span.id).select((d) => d.valueOrNull?.medicine),
      );
      final now = ref.watch(minuteClockProvider);
      if (logs == null || medicine == null) return const [];
      return MedicineCalendar.days(medicine, logs, span.from, span.to, now);
    });
