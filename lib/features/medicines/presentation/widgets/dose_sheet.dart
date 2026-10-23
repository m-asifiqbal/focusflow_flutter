/// ============================================================
/// DOSE SHEET — every action on one dose (long-press a dose / history row)
/// ============================================================
///
/// Taken / Skip / Snooze for a dose that is not logged yet, "Mark as not
/// taken" for a logged one, and Open medicine. A future dose can be taken
/// early (a dose taken before its time still counts) but not snoozed.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';
import 'package:focusflow/features/medicines/presentation/medicine_flows.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:go_router/go_router.dart';

Future<void> showDoseSheet(
  BuildContext context,
  WidgetRef ref,
  DoseSlot slot,
  DateTime now, {
  bool showOpen = true,
}) {
  final state = slot.stateAt(now);
  final m = slot.medicine;
  final colors = MedicineStyle.colors;
  final name = m.name.trim().isEmpty ? tr('Untitled medicine') : m.name;
  final when =
      '${DateUtilsX.relativeDay(slot.day, now)} · '
      '${DateUtilsX.time(slot.at)}';
  return showFFActionSheet(
    context,
    FFActionSheetData(
      header: FFActionSheetHeader(
        title: name,
        icon: MedicineStyle.icon(m.form),
        colors: colors,
        meta: '$when · ${MedicineWords.amount(slot.quantity, m.form)}',
      ),
      actions: [
        if (state != DoseState.taken)
          FFActionItem(
            icon: FontAwesomeIcons.check,
            label: tr('Mark as taken'),
            colors: colors,
            onTap: () => takeDose(context, ref, slot),
          ),
        if (!state.isLogged && state != DoseState.upcoming)
          FFActionItem(
            icon: FontAwesomeIcons.solidClock,
            label: tr('Snooze'),
            colors: ActionTints.share,
            onTap: () => snoozeDose(context, ref, slot),
          ),
        if (state != DoseState.skipped && !slot.isAsNeeded)
          FFActionItem(
            icon: FontAwesomeIcons.forward,
            label: tr('Skip this dose'),
            colors: ActionTints.lock,
            onTap: () => skipDose(context, ref, slot),
          ),
        if (state.isLogged)
          FFActionItem(
            icon: FontAwesomeIcons.rotateLeft,
            label: slot.isAsNeeded
                ? tr('Remove this dose')
                : tr('Mark as not taken'),
            colors: ActionTints.lock,
            onTap: () => clearDose(context, ref, slot),
          ),
        if (showOpen)
          FFActionItem(
            icon: FontAwesomeIcons.arrowUpRightFromSquare,
            label: tr('Open medicine'),
            colors: colors,
            onTap: () => context.push(AppRoutes.medicine(m.id)),
          ),
      ],
    ),
  );
}
