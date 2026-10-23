/// ============================================================
/// MEDICINE FLOWS — take / skip / snooze a dose, log, refill, pause
/// ============================================================
///
/// Every user action on a dose goes through here, from any screen (list,
/// Reminders chip, detail, dose sheet): write through MedicinesRepository,
/// a light haptic, and the Undo snackbar (rule 3) that puts the dose back
/// exactly as it was (stock included). Notifications follow by themselves:
/// the engine re-plans when the dose tables change.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

String _name(Medicine m) =>
    m.name.trim().isEmpty ? tr('Untitled medicine') : m.name.trim();

/// Writes [write], then offers Undo back to [slot]'s previous log.
Future<void> _changeDose(
  BuildContext context,
  WidgetRef ref,
  DoseSlot slot, {
  required Future<void> Function() write,
  required String message,
  required IconData icon,
}) async {
  final repo = ref.read(medicinesRepositoryProvider);
  final previous = slot.log;
  try {
    await write();
  } catch (e) {
    AppLogger.w('Dose write failed: $e');
    if (context.mounted) showFFToast(context, tr('Couldn\'t save the dose.'));
    return;
  }
  ref.read(minuteClockProvider.notifier).tick();
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: message,
    icon: icon,
    onUndo: () =>
        repo.restoreDose(slot.medicine.id, slot.day, slot.minutes, previous),
  );
}

/// Marks [slot] taken (its scheduled amount).
Future<void> takeDose(BuildContext context, WidgetRef ref, DoseSlot slot) {
  FFHaptics.light(context);
  return _changeDose(
    context,
    ref,
    slot,
    write: () => ref
        .read(medicinesRepositoryProvider)
        .markTaken(slot.medicine.id, slot.day, slot.minutes),
    message: tr('{name} taken', {'name': _name(slot.medicine)}),
    icon: FontAwesomeIcons.check,
  );
}

/// Marks [slot] skipped.
Future<void> skipDose(BuildContext context, WidgetRef ref, DoseSlot slot) {
  FFHaptics.selection(context);
  return _changeDose(
    context,
    ref,
    slot,
    write: () => ref
        .read(medicinesRepositoryProvider)
        .markSkipped(slot.medicine.id, slot.day, slot.minutes),
    message: tr('{name} skipped', {'name': _name(slot.medicine)}),
    icon: FontAwesomeIcons.forward,
  );
}

/// Snoozes [slot] by its medicine's snooze length (else the setting).
Future<void> snoozeDose(BuildContext context, WidgetRef ref, DoseSlot slot) {
  FFHaptics.selection(context);
  final own = slot.medicine.snoozeMinutes;
  final minutes = own > 0
      ? own
      : ref.read(settingsProvider).defaultSnoozeMinutes;
  final until = ref.read(clockProvider).now().add(Duration(minutes: minutes));
  return _changeDose(
    context,
    ref,
    slot,
    write: () => ref
        .read(medicinesRepositoryProvider)
        .snooze(slot.medicine.id, slot.day, slot.minutes, until),
    message: tr('Snoozed for {m} min', {'m': minutes}),
    icon: FontAwesomeIcons.solidClock,
  );
}

/// Clears what was logged for [slot] (back to not taken).
Future<void> clearDose(BuildContext context, WidgetRef ref, DoseSlot slot) {
  if (slot.isAsNeeded) return deleteAsNeededDose(context, ref, slot);
  return _changeDose(
    context,
    ref,
    slot,
    write: () => ref
        .read(medicinesRepositoryProvider)
        .restoreDose(slot.medicine.id, slot.day, slot.minutes, null),
    message: tr('Dose cleared'),
    icon: FontAwesomeIcons.rotateLeft,
  );
}

/// Logs one dose of an as-needed medicine now.
Future<void> logAsNeededDose(
  BuildContext context,
  WidgetRef ref,
  Medicine m, {
  double quantity = 1,
}) async {
  FFHaptics.light(context);
  final repo = ref.read(medicinesRepositoryProvider);
  final String id;
  try {
    id = await repo.logAsNeeded(m.id, ref.read(clockProvider).now(), quantity);
  } catch (e) {
    AppLogger.w('As-needed dose failed: $e');
    if (context.mounted) showFFToast(context, tr('Couldn\'t save the dose.'));
    return;
  }
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: tr('{name} logged', {'name': _name(m)}),
    icon: FontAwesomeIcons.check,
    onUndo: () => repo.deleteAsNeeded(id),
  );
}

/// Deletes a logged as-needed dose (Undo logs it again).
Future<void> deleteAsNeededDose(
  BuildContext context,
  WidgetRef ref,
  DoseSlot slot,
) async {
  final repo = ref.read(medicinesRepositoryProvider);
  final log = slot.log;
  if (log == null) return;
  await repo.deleteAsNeeded(log.id);
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: tr('Dose removed'),
    icon: FontAwesomeIcons.rotateLeft,
    onUndo: () => repo.logAsNeeded(
      slot.medicine.id,
      log.takenAt ?? slot.at,
      log.quantity,
    ),
  );
}

/// Adds [amount] units to [m]'s stock (Undo takes them off again).
Future<void> refillMedicine(
  BuildContext context,
  WidgetRef ref,
  Medicine m,
  double amount,
) async {
  if (amount <= 0) return;
  final repo = ref.read(medicinesRepositoryProvider);
  final before = m.stockLeft;
  final pack = m.packSize;
  await repo.refill(m.id, amount);
  if (!context.mounted) return;
  FFHaptics.light(context);
  showUndoSnackbar(
    context,
    message: tr('Stock updated · {left}', {
      'left': MedicineWords.left((before ?? 0) + amount, m.form),
    }),
    icon: FontAwesomeIcons.boxOpen,
    onUndo: () async {
      final now = await repo.getMedicine(m.id);
      if (now == null) return;
      await repo.save(
        now.copyWith(
          stockLeft: before,
          clearStock: before == null,
          packSize: pack,
        ),
        writeStock: true,
      );
    },
  );
}

/// Pauses / resumes [m] (no alerts while paused).
Future<void> setMedicinePaused(
  BuildContext context,
  WidgetRef ref,
  Medicine m,
  bool paused,
) async {
  final repo = ref.read(medicinesRepositoryProvider);
  await repo.setPaused(m.id, paused);
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: paused
        ? tr('"{name}" paused', {'name': _name(m)})
        : tr('"{name}" resumed', {'name': _name(m)}),
    icon: paused ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
    onUndo: () => repo.setPaused(m.id, !paused),
  );
}
