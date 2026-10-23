/// ============================================================
/// MEDICINE OPTIONS SECTION — food, course, stock, reminders, note
/// ============================================================
///
/// TAKE IT chips (before / with / after food, any time) · COURSE (start
/// day, end: ongoing / 7 / 14 / 30 days / a date) · PILLS LEFT (track the
/// stock: units left now + "alert me at") · REMINDERS (remind me, alarm
/// style, remind again if not taken, snooze length) · NOTE. The stock and
/// alert rows fold in and out with the switches.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
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
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';

class MedicineOptionsSection extends ConsumerWidget {
  const MedicineOptionsSection({required this.args, super.key});

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
    final duration = context.motion(AppMotion.normal);
    final today = ref.watch(todayProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionLabel(tr('Take it')),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final f in [
              FoodTiming.beforeFood,
              FoodTiming.withFood,
              FoodTiming.afterFood,
              FoodTiming.anyTime,
            ])
              FFChip(
                label: MedicineWords.food(f),
                selected: d.foodTiming == f,
                onTap: () {
                  FFHaptics.selection(context);
                  c.setFood(f);
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        FFGroupedList(
          label: tr('Course'),
          children: [
            FFListRow(
              leading: FFIconTile.soft(
                icon: FontAwesomeIcons.solidCalendarDays,
                colors: ModuleStyle.habits.colors,
              ),
              title: tr('Starts'),
              value: DateUtilsX.relativeDay(d.startDate, today),
              onTap: () => _pickStart(context, c, d, today),
            ),
            FFListRow(
              leading: FFIconTile.soft(
                icon: FontAwesomeIcons.flagCheckered,
                colors: ModuleStyle.tasks.colors,
              ),
              title: tr('Ends'),
              value: d.endDate == null
                  ? tr('Ongoing')
                  : DateFormats.of('MMM d, y').format(d.endDate!),
              valueColor: d.endDate != null && d.endDate!.isBefore(d.startDate)
                  ? context.ff.danger
                  : null,
              onTap: () => _pickEnd(context, c, d),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        FFGroupedList(
          label: tr('Pills left'),
          children: [
            FFListRow.toggle(
              leading: FFIconTile.soft(
                icon: FontAwesomeIcons.boxOpen,
                colors: MedicineStyle.stock,
              ),
              title: tr('Track what\'s left'),
              subtitle: tr('Counts down as you take doses'),
              value: d.tracksStock,
              onChanged: c.setTrackStock,
            ),
            if (d.tracksStock) ...[
              _StepperRow(
                title: tr('Left now'),
                child: MedicineStepper(
                  value: d.stockLeft ?? 0,
                  min: 0,
                  max: 9999,
                  step: 1,
                  compact: true,
                  label: (v) => MedicineWords.amount(v, d.form),
                  onChanged: c.setStockLeft,
                ),
              ),
              _StepperRow(
                title: tr('Alert me at'),
                child: MedicineStepper(
                  value: d.refillAt ?? 5,
                  min: 1,
                  max: 999,
                  step: 1,
                  compact: true,
                  label: (v) => MedicineWords.amount(v, d.form),
                  onChanged: c.setRefillAt,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        AnimatedSize(
          duration: duration,
          curve: AppMotion.curve,
          alignment: AlignmentDirectional.topStart,
          child: d.isAsNeeded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: AppSpacing.section,
                  ),
                  child: _Reminders(medicine: d, controller: c),
                ),
        ),
        _NoteField(args: args, initial: d.note),
      ],
    );
  }

  Future<void> _pickStart(
    BuildContext context,
    MedicineEditorController c,
    Medicine d,
    DateTime today,
  ) async {
    final early = DateUtilsX.addDays(today, -365 * 2);
    final late = DateUtilsX.addDays(today, 365);
    final picked = await showDatePicker(
      context: context,
      initialDate: d.startDate,
      firstDate: d.startDate.isBefore(early) ? d.startDate : early,
      lastDate: d.startDate.isAfter(late) ? d.startDate : late,
    );
    if (picked != null) c.setStartDate(picked);
  }

  Future<void> _pickEnd(
    BuildContext context,
    MedicineEditorController c,
    Medicine d,
  ) async {
    // -1 = ongoing, 0 = pick a date, n = n days from the start.
    final choice = await showMedicineOptionSheet<int>(
      context,
      title: tr('Course length'),
      selected: d.endDate == null ? -1 : -2,
      options: [
        MedicineOption(-1, tr('Ongoing')),
        for (final n in const [5, 7, 10, 14, 30])
          MedicineOption(
            n,
            tr('{count, plural, one {# day} other {# days}}', {'count': n}),
          ),
        MedicineOption(0, tr('Pick an end date')),
      ],
    );
    if (choice == null || !context.mounted) return;
    if (choice == -1) return c.setEndDate(null);
    if (choice > 0) {
      return c.setEndDate(DateUtilsX.addDays(d.startDate, choice - 1));
    }
    final initial = d.endDate ?? DateUtilsX.addDays(d.startDate, 6);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(d.startDate) ? d.startDate : initial,
      firstDate: d.startDate,
      lastDate: DateUtilsX.addDays(d.startDate, 365 * 3),
    );
    if (picked != null) c.setEndDate(picked);
  }
}

class _Reminders extends StatelessWidget {
  const _Reminders({required this.medicine, required this.controller});

  final Medicine medicine;
  final MedicineEditorController controller;

  String _minutes(int m) => m <= 0
      ? tr('Off')
      : tr('{count, plural, one {# min} other {# min}}', {'count': m});

  @override
  Widget build(BuildContext context) {
    final d = medicine;
    final c = controller;
    return FFGroupedList(
      label: tr('Reminders'),
      children: [
        FFListRow.toggle(
          leading: FFIconTile.soft(
            icon: FontAwesomeIcons.solidBell,
            colors: ModuleStyle.reminders.colors,
          ),
          title: tr('Remind me'),
          subtitle: tr('At every dose time'),
          value: d.reminderEnabled,
          onChanged: c.setReminderEnabled,
        ),
        if (d.reminderEnabled) ...[
          FFListRow.toggle(
            leading: const FFIconTile.soft(
              icon: FontAwesomeIcons.bellConcierge,
              colors: ActionTints.lock,
            ),
            title: tr('Alarm-style (full screen)'),
            subtitle: tr('Rings until you stop it'),
            value: d.alarmStyle,
            onChanged: c.setAlarmStyle,
          ),
          FFListRow(
            leading: FFIconTile.soft(
              icon: FontAwesomeIcons.clockRotateLeft,
              colors: ModuleStyle.reminders.colors,
            ),
            title: tr('Remind again if not taken'),
            value: _minutes(d.followUpMinutes),
            onTap: () async {
              final v = await showMedicineOptionSheet<int>(
                context,
                title: tr('Remind again if not taken'),
                selected: d.followUpMinutes,
                options: [
                  for (final m in const [0, 15, 30, 60])
                    MedicineOption(
                      m,
                      m == 0 ? tr('Off') : tr('After {m} min', {'m': m}),
                    ),
                ],
              );
              if (v != null) c.setFollowUp(v);
            },
          ),
          FFListRow(
            leading: FFIconTile.soft(
              icon: FontAwesomeIcons.solidClock,
              colors: ModuleStyle.tasks.colors,
            ),
            title: tr('Snooze for'),
            value: _minutes(d.snoozeMinutes),
            onTap: () async {
              final v = await showMedicineOptionSheet<int>(
                context,
                title: tr('Snooze for'),
                selected: d.snoozeMinutes,
                options: [
                  for (final m in const [5, 10, 15, 30])
                    MedicineOption(m, _minutes(m)),
                ],
              );
              if (v != null) c.setSnooze(v);
            },
          ),
        ],
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.dividerInset,
      AppSpacing.xs,
      AppSpacing.xs,
      AppSpacing.xs,
    ),
    child: Row(
      children: [
        Expanded(child: Text(title, style: context.text.rowTitle)),
        child,
      ],
    ),
  );
}

class _NoteField extends ConsumerStatefulWidget {
  const _NoteField({required this.args, required this.initial});

  final MedicineEditorArgs args;
  final String initial;

  @override
  ConsumerState<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends ConsumerState<_NoteField> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionLabel(tr('Note')),
        const SizedBox(height: AppSpacing.md),
        FFCard(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: TextField(
            controller: _c,
            minLines: 2,
            maxLines: 5,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: context.text.body,
            decoration: InputDecoration(
              hintText: tr('What it\'s for, who prescribed it…'),
              hintStyle: TextStyle(color: ff.inkFaint),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              isDense: true,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: ref
                .read(medicineEditorControllerProvider(widget.args).notifier)
                .setNote,
          ),
        ),
      ],
    );
  }
}
