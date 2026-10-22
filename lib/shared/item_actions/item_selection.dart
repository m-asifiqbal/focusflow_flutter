/// ============================================================
/// ITEM SELECTION — multi-select mode for any list (master prompt §7.5)
/// ============================================================
///
/// "Select" in a list header turns selection mode on; rows then toggle
/// instead of opening, and [ItemSelectionBar] floats above the tab bar with
/// Archive · Delete · Move · Tag · Pin. State is per list ([scope] key,
/// e.g. 'notes', 'tasks', 'archive') and auto-disposes with the screen.
///
/// ```dart
/// final sel = ref.watch(itemSelectionProvider('notes'));
/// onTap: sel.active ? () => ref.read(itemSelectionProvider('notes').notifier).toggle(note.ref) : open,
/// ...
/// if (sel.active) ItemSelectionBar(scope: 'notes', module: ItemType.note),
/// ```
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:focusflow/shared/item_actions/item_pickers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

@immutable
class SelectionState {
  const SelectionState({this.active = false, this.selected = const {}});

  final bool active;
  final Set<ItemRef> selected;

  int get count => selected.length;
  bool contains(ItemRef ref) => selected.contains(ref);
}

class ItemSelection extends AutoDisposeFamilyNotifier<SelectionState, String> {
  @override
  SelectionState build(String scope) => const SelectionState();

  /// Enters selection mode (optionally with [first] selected — long-press).
  void start([ItemRef? first]) =>
      state = SelectionState(active: true, selected: {?first});

  void toggle(ItemRef ref) {
    final next = {...state.selected};
    if (!next.remove(ref)) next.add(ref);
    state = SelectionState(active: true, selected: next);
  }

  void selectAll(Iterable<ItemRef> refs) =>
      state = SelectionState(active: true, selected: refs.toSet());

  /// Leaves selection mode.
  void clear() => state = const SelectionState();
}

final itemSelectionProvider = NotifierProvider.autoDispose
    .family<ItemSelection, SelectionState, String>(ItemSelection.new);

/// Whether every selected item of [scope] is pinned (the bar then offers
/// "Unpin"). Re-evaluated when the selection changes.
final selectionAllPinnedProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, scope) async {
      final selected = ref.watch(itemSelectionProvider(scope)).selected;
      if (selected.isEmpty) return false;
      final items = ref.watch(itemsRepositoryProvider);
      for (final r in selected) {
        final s = await items.get(r);
        if (s == null || !s.isPinned) return false;
      }
      return true;
    });

/// The floating multi-select action bar. [module] enables "Move" (folders /
/// lists are per module); pass null for mixed lists (Pinned, Archive…).
class ItemSelectionBar extends ConsumerWidget {
  const ItemSelectionBar({
    required this.scope,
    this.module,
    this.showPin = true,
    super.key,
  });

  final String scope;
  final ItemType? module;
  final bool showPin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final sel = ref.watch(itemSelectionProvider(scope));
    final notifier = ref.read(itemSelectionProvider(scope).notifier);
    final refs = sel.selected.toList();
    final enabled = refs.isNotEmpty;

    // Selection ends only when the action went through; a cancelled
    // confirm / dismissed picker keeps it so the user can try again.
    Future<void> run(Future<bool> Function() action) async {
      if (await action()) notifier.clear();
    }

    final allPinned =
        ref.watch(selectionAllPinnedProvider(scope)).valueOrNull ?? false;

    final canMove =
        module == ItemType.note ||
        module == ItemType.task ||
        module == ItemType.vault;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.md,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ff.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: ff.surfaceBorder),
            boxShadow: ff.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _BarButton(
                  icon: FontAwesomeIcons.boxArchive,
                  label: tr('Archive'),
                  enabled: enabled,
                  onTap: () => run(() => archiveItems(context, ref, refs)),
                ),
                _BarButton(
                  icon: FontAwesomeIcons.trashCan,
                  label: tr('Delete'),
                  color: ff.danger,
                  enabled: enabled,
                  onTap: () => run(() => deleteItems(context, ref, refs)),
                ),
                if (canMove)
                  _BarButton(
                    icon: FontAwesomeIcons.solidFolder,
                    label: tr('Move'),
                    enabled: enabled,
                    onTap: () => run(
                      () => moveItemsToFolder(context, ref, module!, refs),
                    ),
                  ),
                _BarButton(
                  icon: FontAwesomeIcons.tag,
                  label: tr('Tag'),
                  enabled: enabled,
                  onTap: () => run(() => addTagsToItems(context, ref, refs)),
                ),
                if (showPin && module != ItemType.vault)
                  _BarButton(
                    icon: FontAwesomeIcons.thumbtack,
                    label: allPinned ? tr('Unpin') : tr('Pin'),
                    enabled: enabled,
                    onTap: () => run(() => togglePinItems(context, ref, refs)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.enabled,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final tint = (color ?? ff.ink).withValues(alpha: enabled ? 1 : 0.35);
    return Expanded(
      child: FFPressable(
        onTap: enabled ? onTap : null,
        semanticLabel: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTap),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: tint),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.meta.copyWith(color: tint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
