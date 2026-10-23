/// ============================================================
/// MEDICINE EDITOR CONTROLLER — draft state of the add / edit screen
/// ============================================================
///
/// `medicineEditorControllerProvider((id: …, name: …))` loads the medicine
/// being edited (or starts a draft: one 8:00 dose, every day from today,
/// optionally named by Quick Add) and keeps the unsaved [Medicine]. Widgets
/// only call the intent methods below; [save] writes through
/// MedicinesRepository and then flushes the notification engine, so the
/// first dose alert is with the OS before the screen closes. Editing the
/// schedule never touches logged doses: past doses keep their log.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Which medicine the editor opens: [id] null = new (optionally named).
typedef MedicineEditorArgs = ({String? id, String? name});

@immutable
class MedicineEditorState {
  const MedicineEditorState({
    required this.draft,
    required this.initial,
    this.original,
    this.saving = false,
    this.stockEdited = false,
  });

  final Medicine draft;

  /// The draft as first opened (dirty check).
  final Medicine initial;

  /// The stored medicine when editing; null for a new one.
  final Medicine? original;
  final bool saving;

  /// The user changed the stock in the editor (saved even on an update).
  final bool stockEdited;

  bool get isNew => original == null;
  bool get isDirty => draft != initial;

  bool get hasValidSchedule => switch (draft.schedule) {
    MedicineScheduleType.asNeeded => true,
    MedicineScheduleType.specificDays =>
      draft.weekdaysMask & 0x7F != 0 && draft.doses.isNotEmpty,
    _ => draft.doses.isNotEmpty,
  };

  bool get hasValidCourse {
    final end = draft.endDate;
    return end == null || !end.isBefore(draft.startDate);
  }

  bool get canSave =>
      !saving &&
      draft.name.trim().isNotEmpty &&
      hasValidSchedule &&
      hasValidCourse;

  MedicineEditorState copyWith({
    Medicine? draft,
    bool? saving,
    bool? stockEdited,
  }) => MedicineEditorState(
    draft: draft ?? this.draft,
    initial: initial,
    original: original,
    saving: saving ?? this.saving,
    stockEdited: stockEdited ?? this.stockEdited,
  );
}

class MedicineEditorController
    extends
        AutoDisposeFamilyAsyncNotifier<
          MedicineEditorState?,
          MedicineEditorArgs
        > {
  /// Most dose times a medicine can have.
  static const int maxDoses = 8;

  @override
  Future<MedicineEditorState?> build(MedicineEditorArgs arg) async {
    final id = arg.id;
    if (id == null) {
      final today = ref.read(todayProvider);
      final draft = Medicine.draft(startDate: today, name: arg.name ?? '');
      return MedicineEditorState(draft: draft, initial: draft);
    }
    final m = await ref.read(medicinesRepositoryProvider).getMedicine(id);
    if (m == null) return null;
    return MedicineEditorState(draft: m, initial: m, original: m);
  }

  MedicineEditorState? get _s => state.valueOrNull;

  void _edit(Medicine Function(Medicine d) change, {bool stock = false}) {
    final s = _s;
    if (s == null) return;
    state = AsyncData(
      s.copyWith(draft: change(s.draft), stockEdited: stock ? true : null),
    );
  }

  void setName(String v) => _edit((d) => d.copyWith(name: v));
  void setStrength(String v) => _edit((d) => d.copyWith(strength: v));
  void setNote(String v) => _edit((d) => d.copyWith(note: v));
  void setForm(MedicineForm f) => _edit((d) => d.copyWith(form: f));
  void setFood(FoodTiming f) => _edit((d) => d.copyWith(foodTiming: f));

  /// Switching to a schedule with times gives an as-needed medicine back
  /// a first dose time (8:00).
  void setSchedule(MedicineScheduleType t) => _edit((d) {
    var next = d.copyWith(schedule: t);
    if (t != MedicineScheduleType.asNeeded && d.doses.isEmpty) {
      next = next.copyWith(doses: const [DoseTime(8 * 60)]);
    }
    if (t == MedicineScheduleType.specificDays && d.weekdaysMask & 0x7F == 0) {
      next = next.copyWith(weekdaysMask: 0x7F);
    }
    return next;
  });

  /// Weekday 0 = Monday … 6 = Sunday.
  void toggleWeekday(int weekday) =>
      _edit((d) => d.copyWith(weekdaysMask: d.weekdaysMask ^ (1 << weekday)));

  void setEveryNDays(int n) =>
      _edit((d) => d.copyWith(everyNDays: n.clamp(2, 30)));

  /// Adds a dose time: 4 h after the last one (20:00 when that is past
  /// midnight), skipping times already used.
  void addDose() => _edit((d) {
    if (d.doses.length >= maxDoses) return d;
    final used = {for (final x in d.doses) x.minutes};
    var t = d.doses.isEmpty ? 8 * 60 : d.doses.last.minutes + 4 * 60;
    if (t >= 24 * 60) t = 20 * 60;
    while (used.contains(t)) {
      t = (t + 30) % (24 * 60);
    }
    final q = d.doses.isEmpty ? 1.0 : d.doses.last.quantity;
    return d.copyWith(doses: [...d.doses, DoseTime(t, q)]..sort());
  });

  void removeDose(int index) => _edit((d) {
    if (d.doses.length <= 1) return d;
    return d.copyWith(doses: [...d.doses]..removeAt(index));
  });

  /// Moves dose [index] to [minutes] (a time already used is ignored).
  void setDoseTime(int index, int minutes) => _edit((d) {
    if (d.doses.any((x) => x.minutes == minutes)) return d;
    final list = [...d.doses];
    list[index] = list[index].copyWith(minutes: minutes);
    return d.copyWith(doses: list..sort());
  });

  void setDoseQuantity(int index, double q) => _edit((d) {
    final list = [...d.doses];
    list[index] = list[index].copyWith(quantity: q);
    return d.copyWith(doses: list);
  });

  void setStartDate(DateTime day) =>
      _edit((d) => d.copyWith(startDate: DateUtilsX.dateOnly(day)));

  /// Course end: null = ongoing.
  void setEndDate(DateTime? day) => _edit(
    (d) => day == null
        ? d.copyWith(clearEndDate: true)
        : d.copyWith(endDate: DateUtilsX.dateOnly(day)),
  );

  /// Turns stock tracking on (30 units, alert at 5) or off.
  void setTrackStock(bool on) => _edit(
    (d) => on
        ? d.copyWith(stockLeft: d.stockLeft ?? 30, refillAt: d.refillAt ?? 5)
        : d.copyWith(clearStock: true),
    stock: true,
  );

  void setStockLeft(double v) =>
      _edit((d) => d.copyWith(stockLeft: v < 0 ? 0 : v), stock: true);

  void setRefillAt(double v) => _edit((d) => d.copyWith(refillAt: v));

  void setReminderEnabled(bool on) {
    _edit((d) => d.copyWith(reminderEnabled: on));
    if (on) unawaited(_askPermission());
  }

  void setAlarmStyle(bool on) => _edit((d) => d.copyWith(alarmStyle: on));
  void setFollowUp(int minutes) =>
      _edit((d) => d.copyWith(followUpMinutes: minutes));
  void setSnooze(int minutes) =>
      _edit((d) => d.copyWith(snoozeMinutes: minutes));

  Future<void> _askPermission() async {
    try {
      await requestNotificationPermission(ref);
    } catch (_) {
      // Best effort: the list's banner reports a missing permission.
    }
  }

  /// Saves the draft. Returns the id, or null when it can't be saved.
  Future<String?> save() async {
    final s = _s;
    if (s == null || !s.canSave) return null;
    state = AsyncData(s.copyWith(saving: true));
    try {
      final id = await ref
          .read(medicinesRepositoryProvider)
          .save(
            s.draft.copyWith(name: s.draft.name.trim()),
            writeStock: s.stockEdited,
          );
      if (s.draft.reminderEnabled && s.isNew) unawaited(_askPermission());
      await flushNotifications(ref);
      return id;
    } finally {
      final now = _s;
      if (now != null) state = AsyncData(now.copyWith(saving: false));
    }
  }
}

final medicineEditorControllerProvider = AsyncNotifierProvider.autoDispose
    .family<MedicineEditorController, MedicineEditorState?, MedicineEditorArgs>(
      MedicineEditorController.new,
    );
