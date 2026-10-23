/// ============================================================
/// MEDICINE CABINET — "Your medicines" and "As needed" grouped lists
/// ============================================================
///
/// [MedicineCabinet]: every active medicine as a grouped row (form icon,
/// name, "500 mg · 2× a day · 6 left", Paused / Finished tags); tap opens
/// the detail, long-press the shared item actions sheet (archive, delete,
/// pin …). [AsNeededList]: as-needed medicines with a LOG pill that logs
/// one dose now (Undo in the snackbar).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';
import 'package:focusflow/features/medicines/presentation/medicine_flows.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminder_card_parts.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:go_router/go_router.dart';

/// "500 mg · 2× a day · 6 tablets left" — a medicine's summary line.
String medicineSummary(Medicine m) => [
  if (m.strength.trim().isNotEmpty) m.strength.trim(),
  if (m.isAsNeeded)
    MedicineWords.schedule(m)
  else ...[
    MedicineWords.timesPerDay(m.doses.length),
    if (m.schedule != MedicineScheduleType.everyDay) MedicineWords.schedule(m),
  ],
  if (m.stockLeft case final left?) MedicineWords.left(left, m.form),
].join(' · ');

class MedicineCabinet extends ConsumerWidget {
  const MedicineCabinet({
    required this.medicines,
    required this.day,
    super.key,
  });

  final List<Medicine> medicines;

  /// The day shown (a course that ended before it is "Finished").
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    return FFGroupedList(
      children: [
        for (final m in medicines)
          FFListRow(
            key: ValueKey(m.id),
            leading: FFIconTile.soft(
              icon: MedicineStyle.icon(m.form),
              colors: MedicineStyle.colors,
            ),
            title: m.name.trim().isEmpty ? tr('Untitled medicine') : m.name,
            subtitle: medicineSummary(m),
            value: m.isPaused
                ? tr('Paused')
                : m.hasEndedBy(day)
                ? tr('Finished')
                : null,
            valueColor: ff.inkFaint,
            chevron: true,
            onTap: () => context.push(AppRoutes.medicine(m.id)),
            onLongPress: () => showItemActions(context, ref, m.ref),
          ),
        FFListRow(
          leading: FFIconTile.soft(
            icon: FontAwesomeIcons.plus,
            colors: MedicineStyle.colors,
          ),
          title: tr('Add medicine'),
          onTap: () => context.push(AppRoutes.newMedicinePath),
        ),
      ],
    );
  }
}

class AsNeededList extends ConsumerWidget {
  const AsNeededList({required this.medicines, super.key});

  final List<Medicine> medicines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FFGroupedList(
      children: [
        for (final m in medicines)
          FFListRow(
            key: ValueKey(m.id),
            leading: FFIconTile.soft(
              icon: MedicineStyle.icon(m.form),
              colors: MedicineStyle.colors,
            ),
            title: m.name.trim().isEmpty ? tr('Untitled medicine') : m.name,
            subtitle: medicineSummary(m),
            onTap: () => context.push(AppRoutes.medicine(m.id)),
            trailing: Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
              child: ReminderActionPill(
                label: tr('LOG'),
                primary: true,
                onTap: () => logAsNeededDose(context, ref, m),
              ),
            ),
          ),
      ],
    );
  }
}
