/// ============================================================
/// MEDICINE SCHEDULE SECTION — form, how often, and the dose times
/// ============================================================
///
/// FORM chips · HOW OFTEN chips (every day / specific days / every few
/// days / as needed) with the weekday circles or the "every N days"
/// stepper · TIMES AND DOSE: one row per time (sun / moon tile, the time —
/// tap for the wheel —, the amount stepper, remove) and "Add a time".
/// Rows slide in and out (AnimatedSize) as times are added or removed;
/// the times section folds away for "as needed".
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/notifiers/medicine_editor_controller.dart';
import 'package:focusflow/features/medicines/presentation/widgets/editor/medicine_editor_sheets.dart';
import 'package:focusflow/features/medicines/presentation/widgets/medicine_stepper.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

String _howOften(MedicineScheduleType t) => switch (t) {
  MedicineScheduleType.everyDay => tr('Every day'),
  MedicineScheduleType.specificDays => tr('Specific days'),
  MedicineScheduleType.everyNDays => tr('Every few days'),
  MedicineScheduleType.asNeeded => tr('As needed'),
};

class MedicineScheduleSection extends ConsumerWidget {
  const MedicineScheduleSection({required this.args, super.key});

  final MedicineEditorArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(
      medicineEditorControllerProvider(
        args,
      ).select((s) => s.valueOrNull?.draft),
    );
    if (d == null) return const SizedBox.shrink();
    final c = ref.read(medicineEditorControllerProvider(args).notifier);
    final weekStart = ref.watch(settingsProvider.select((s) => s.weekStartsOn));
    final duration = context.motion(AppMotion.normal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionLabel(tr('Form')),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final f in MedicineForm.values)
              FFChip(
                label: MedicineWords.form(f),
                icon: MedicineStyle.icon(f),
                selected: d.form == f,
                onTap: () {
                  FFHaptics.selection(context);
                  c.setForm(f);
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        FFSectionLabel(tr('How often')),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final t in MedicineScheduleType.values)
              FFChip(
                label: _howOften(t),
                selected: d.schedule == t,
                onTap: () {
                  FFHaptics.selection(context);
                  c.setSchedule(t);
                },
              ),
          ],
        ),
        AnimatedSize(
          duration: duration,
          curve: AppMotion.curve,
          alignment: AlignmentDirectional.topStart,
          child: switch (d.schedule) {
            MedicineScheduleType.specificDays => Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
              child: _WeekdayCircles(
                mask: d.weekdaysMask,
                weekStart: weekStart,
                onToggle: (i) {
                  FFHaptics.selection(context);
                  c.toggleWeekday(i);
                },
              ),
            ),
            MedicineScheduleType.everyNDays => Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
              child: FFCard(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(tr('Repeat'), style: context.text.rowTitle),
                    ),
                    MedicineStepper(
                      value: d.everyNDays.toDouble(),
                      min: 2,
                      max: 30,
                      compact: true,
                      label: (v) => tr(
                        '{count, plural, one {every day} other {every # days}}',
                        {'count': v.toInt()},
                      ),
                      onChanged: (v) => c.setEveryNDays(v.round()),
                    ),
                  ],
                ),
              ),
            ),
            _ => const SizedBox(width: double.infinity),
          },
        ),
        AnimatedSize(
          duration: duration,
          curve: AppMotion.curve,
          alignment: AlignmentDirectional.topStart,
          child: d.isAsNeeded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: AppSpacing.section,
                  ),
                  child: _Times(args: args, medicine: d),
                ),
        ),
      ],
    );
  }
}

class _Times extends ConsumerWidget {
  const _Times({required this.args, required this.medicine});

  final MedicineEditorArgs args;
  final Medicine medicine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(medicineEditorControllerProvider(args).notifier);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final doses = medicine.doses;
    return FFGroupedList(
      label: tr('Times and dose'),
      children: [
        for (final (i, dose) in doses.indexed)
          _DoseRow(
            key: ValueKey(dose.minutes),
            dose: dose,
            form: medicine.form,
            use24h: use24h,
            canRemove: doses.length > 1,
            onTime: () async {
              final picked = await showDoseTimeSheet(
                context,
                minutes: dose.minutes,
                use24h: use24h,
              );
              if (picked != null) c.setDoseTime(i, picked);
            },
            onQuantity: (q) => c.setDoseQuantity(i, q),
            onRemove: () {
              FFHaptics.light(context);
              c.removeDose(i);
            },
          ),
        if (doses.length < MedicineEditorController.maxDoses)
          FFListRow(
            leading: FFIconTile.soft(
              icon: FontAwesomeIcons.plus,
              colors: ModuleStyle.notes.colors,
            ),
            title: tr('Add a time'),
            chevron: false,
            onTap: () {
              FFHaptics.selection(context);
              c.addDose();
            },
          ),
      ],
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.dose,
    required this.form,
    required this.use24h,
    required this.canRemove,
    required this.onTime,
    required this.onQuantity,
    required this.onRemove,
    super.key,
  });

  final DoseTime dose;
  final MedicineForm form;
  final bool use24h;
  final bool canRemove;
  final VoidCallback onTime;
  final ValueChanged<double> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final night = dose.minutes < 5 * 60 || dose.minutes >= 18 * 60;
    final time = DateUtilsX.minutesToTime(dose.minutes, use24h: use24h);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          FFIconTile.soft(
            icon: night ? FontAwesomeIcons.moon : FontAwesomeIcons.sun,
            colors: night
                ? ModuleStyle.habits.colors
                : ModuleStyle.reminders.colors,
            size: AppSizes.iconTileSm,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Semantics(
              button: true,
              label: tr('Dose time {time}, change', {'time': time}),
              excludeSemantics: true,
              child: FFPressable(
                onTap: onTime,
                child: SizedBox(
                  height: AppSizes.minTap,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(time, style: context.text.rowTitle),
                    ),
                  ),
                ),
              ),
            ),
          ),
          MedicineStepper(
            value: dose.quantity,
            compact: true,
            label: (v) => MedicineWords.amount(v, form),
            onChanged: onQuantity,
          ),
          if (canRemove)
            Semantics(
              button: true,
              label: tr('Remove {time}', {'time': time}),
              excludeSemantics: true,
              child: FFPressable(
                onTap: onRemove,
                child: SizedBox.square(
                  dimension: AppSizes.minTap,
                  child: Icon(
                    FontAwesomeIcons.xmark,
                    size: AppSizes.tileGlyph,
                    color: ff.inkFaint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// M T W T F S S circles (in the user's week order); bit 0 = Monday.
class _WeekdayCircles extends StatelessWidget {
  const _WeekdayCircles({
    required this.mask,
    required this.weekStart,
    required this.onToggle,
  });

  final int mask;
  final int weekStart;

  /// Weekday 0 = Monday … 6 = Sunday.
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    // ISO weekdays in display order, → bit index (Monday = 0).
    final days = [for (var i = 0; i < 7; i++) (weekStart - 1 + i) % 7];
    // 2024-01-01 was a Monday.
    String name(int i, String p) =>
        DateFormats.of(p).format(DateTime(2024, 1, 1 + i));
    final duration = context.motion(AppMotion.fast);
    return Row(
      children: [
        for (final i in days)
          Expanded(
            child: Semantics(
              button: true,
              selected: mask & (1 << i) != 0,
              label: name(i, 'EEEE'),
              excludeSemantics: true,
              child: FFPressable(
                onTap: () => onToggle(i),
                child: SizedBox(
                  height: AppSizes.minTap,
                  child: Center(
                    child: AnimatedContainer(
                      duration: duration,
                      width: AppSizes.minTap - AppSpacing.xs,
                      height: AppSizes.minTap - AppSpacing.xs,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: mask & (1 << i) != 0 ? ff.primary : ff.surface,
                        border: Border.all(
                          color: mask & (1 << i) != 0
                              ? ff.primary
                              : ff.chipBorder,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          name(i, 'EEEEE'),
                          style: context.text.button.copyWith(
                            color: mask & (1 << i) != 0 ? ff.onPrimary : ff.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
