/// ============================================================
/// ITEM SWIPE — list-row swipe actions driven by Settings › Gestures
/// ============================================================
///
/// Master prompt §7.3: swipe left → Archive (slate) + Delete (rose); swipe
/// right → Pin / Complete (module-dependent). Both directions are
/// configurable (`AppSettings.swipeLeft` / `swipeRight`), so every list
/// wraps its rows in [ItemSwipe] instead of configuring FFSwipeActions.
///
/// Module-specific actions are passed in: [onComplete] (tasks, reminders,
/// habits) and [onSnooze] (reminders). When the configured action isn't
/// available for the module, swipe-right falls back to Pin.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/ff_swipe_actions.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class ItemSwipe extends ConsumerWidget {
  const ItemSwipe({
    required this.item,
    required this.child,
    this.isPinned = false,
    this.isFavorite = false,
    this.onComplete,
    this.completeLabel,
    this.onSnooze,
    this.radius = AppRadii.card,
    this.enabled = true,
    this.title,
    super.key,
  });

  final ItemRef item;
  final Widget child;
  final bool isPinned;
  final bool isFavorite;

  /// Complete / Done / Log (null = the module has no completion).
  final VoidCallback? onComplete;
  final String? completeLabel;

  /// Snooze (reminders only).
  final VoidCallback? onSnooze;

  /// Match the row's card radius.
  final double radius;
  final bool enabled;

  /// Item title for the Undo snackbar ("\"Shopping List\" archived").
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (left, right) = ref.watch(
      settingsProvider.select((s) => (s.swipeLeft, s.swipeRight)),
    );
    final refs = [item];

    FFSwipeAction? action(SwipeAction a) => switch (a) {
      SwipeAction.none => null,
      SwipeAction.archive => FFSwipeAction.archive(
        onTap: () => archiveItems(context, ref, refs, title: title),
      ),
      SwipeAction.delete => FFSwipeAction.delete(
        onTap: () => deleteItems(context, ref, refs, title: title),
      ),
      SwipeAction.complete =>
        onComplete == null
            ? null
            : FFSwipeAction.complete(onTap: onComplete!, label: completeLabel),
      SwipeAction.pin =>
        item.type == ItemType.vault
            ? null
            : FFSwipeAction.pin(
                label: isPinned ? tr('Unpin') : tr('Pin'),
                onTap: () => ref
                    .read(itemsRepositoryProvider)
                    .setPinned(refs, !isPinned),
              ),
      SwipeAction.favourite => FFSwipeAction(
        icon: FontAwesomeIcons.solidStar,
        label: isFavorite ? tr('Unstar') : tr('Favourite'),
        color: ModuleStyle.vault.solid,
        onTap: () =>
            ref.read(itemsRepositoryProvider).setFavorite(refs, !isFavorite),
      ),
      SwipeAction.snooze =>
        onSnooze == null
            ? null
            : FFSwipeAction(
                icon: FontAwesomeIcons.clockRotateLeft,
                label: tr('Snooze'),
                color: ModuleStyle.reminders.solid,
                onTap: onSnooze!,
              ),
    };

    // Swipe toward the start edge: the configured action, then Delete
    // outermost (Archive + Delete by default, as in the mockups).
    final primary = action(left);
    final endActions = [
      if (primary != null && left != SwipeAction.delete) primary,
      if (left != SwipeAction.none)
        FFSwipeAction.delete(
          onTap: () => deleteItems(context, ref, refs, title: title),
        ),
    ];
    final startAction =
        action(right) ??
        (right == SwipeAction.none ? null : action(SwipeAction.pin));

    return FFSwipeActions(
      enabled: enabled,
      radius: radius,
      endActions: endActions,
      startAction: startAction,
      child: child,
    );
  }
}
