/// Medicine rows of the shared item actions sheet (screen 09): Refill,
/// Pause / Resume. Owned by the medicines feature; see
/// shared/item_actions/module_item_actions.dart.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_action_sheet.dart';
import 'package:focusflow/features/medicines/presentation/medicine_flows.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/widgets/refill_sheet.dart';
import 'package:focusflow/shared/item_actions/module_item_actions.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Module rows for [item]. Archived / deleted medicines get none.
Future<ModuleItemActions> medicineItemActions(
  BuildContext context,
  WidgetRef ref,
  ItemSummary item,
) async {
  final m = await ref.read(medicinesRepositoryProvider).getMedicine(item.id);
  if (m == null || !m.isActive) return ModuleItemActions.none;
  final paused = m.isPaused;
  return ModuleItemActions(
    leading: [
      FFActionItem(
        icon: FontAwesomeIcons.boxOpen,
        label: tr('Refill'),
        colors: MedicineStyle.stock,
        onTap: () {
          if (context.mounted) showRefillSheet(context, ref, m);
        },
      ),
      FFActionItem(
        icon: paused ? FontAwesomeIcons.play : FontAwesomeIcons.pause,
        label: paused ? tr('Resume reminders') : tr('Pause reminders'),
        colors: ActionTints.lock,
        onTap: () {
          if (context.mounted) setMedicinePaused(context, ref, m, !paused);
        },
      ),
    ],
  );
}
