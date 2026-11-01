/// ============================================================
/// PRAYER ITEM ACTIONS — the prayer rows of the shared item actions sheet
/// ============================================================
///
/// What: Pause / Resume reminders, above the shared rows (pin, colour,
/// archive, delete …) when a prayer is long-pressed in Search, Archive or
/// a collection.
/// Why: the sheet is shared; each module adds only its own rows.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/shared/item_actions/module_item_actions.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

Future<ModuleItemActions> prayerItemActions(
  BuildContext context,
  WidgetRef ref,
  ItemSummary item,
) async {
  final repo = ref.read(prayersRepositoryProvider);
  final p = await repo.getPrayer(item.id);
  if (p == null || !p.isActive) return ModuleItemActions.none;
  final paused = p.isPaused;
  return ModuleItemActions(
    leading: [
      FFActionItem(
        icon: paused ? FontAwesomeIcons.play : FontAwesomeIcons.pause,
        label: paused ? tr('Resume reminders') : tr('Pause reminders'),
        colors: ActionTints.lock,
        onTap: () => unawaited(repo.setPaused(p.id, !paused)),
      ),
    ],
  );
}
